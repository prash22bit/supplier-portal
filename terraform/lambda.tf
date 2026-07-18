# ─────────────────────────────────────────────
# Lambda IAM Execution Role
# ─────────────────────────────────────────────
resource "aws_iam_role" "lambda_exec" {
  name = "${local.name_prefix}-lambda-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "lambda_permissions" {
  name = "${local.name_prefix}-lambda-policy"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem",
          "dynamodb:DeleteItem", "dynamodb:Query", "dynamodb:Scan",
          "dynamodb:BatchWriteItem", "dynamodb:BatchGetItem"
        ]
        Resource = [
          aws_dynamodb_table.suppliers.arn,
          "${aws_dynamodb_table.suppliers.arn}/index/*",
          aws_dynamodb_table.audit_reports.arn,
          "${aws_dynamodb_table.audit_reports.arn}/index/*",
          aws_dynamodb_table.compliance_certs.arn,
          "${aws_dynamodb_table.compliance_certs.arn}/index/*",
          aws_dynamodb_table.supplier_scores.arn,
          "${aws_dynamodb_table.supplier_scores.arn}/index/*",
          aws_dynamodb_table.notifications.arn,
          "${aws_dynamodb_table.notifications.arn}/index/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject", "s3:PutObject", "s3:DeleteObject",
          "s3:GetObjectVersion", "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.documents.arn,
          "${aws_s3_bucket.documents.arn}/*",
          aws_s3_bucket.analytics.arn,
          "${aws_s3_bucket.analytics.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "textract:DetectDocumentText",
          "textract:AnalyzeDocument",
          "textract:StartDocumentAnalysis",
          "textract:GetDocumentAnalysis"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "comprehend:DetectEntities",
          "comprehend:DetectKeyPhrases",
          "comprehend:DetectSentiment",
          "comprehend:DetectDominantLanguage"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = [
          aws_sns_topic.cert_expiry_alerts.arn,
          aws_sns_topic.score_drop_alerts.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ses:SendEmail",
          "ses:SendRawEmail"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# ─────────────────────────────────────────────
# Lambda Zip Archives
# ─────────────────────────────────────────────
data "archive_file" "upload_document" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_functions/upload_document"
  output_path = "${path.module}/lambda_functions/upload_document.zip"
}

data "archive_file" "process_document" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_functions/process_document"
  output_path = "${path.module}/lambda_functions/process_document.zip"
}

data "archive_file" "get_suppliers" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_functions/get_suppliers"
  output_path = "${path.module}/lambda_functions/get_suppliers.zip"
}

data "archive_file" "submit_audit" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_functions/submit_audit"
  output_path = "${path.module}/lambda_functions/submit_audit.zip"
}

data "archive_file" "get_dashboard" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_functions/get_dashboard"
  output_path = "${path.module}/lambda_functions/get_dashboard.zip"
}

# ─────────────────────────────────────────────
# Common Lambda VPC Config
# ─────────────────────────────────────────────
locals {
  lambda_vpc_config = {
    subnet_ids         = aws_subnet.private_app[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  lambda_environment_vars = {
    SUPPLIERS_TABLE      = aws_dynamodb_table.suppliers.name
    AUDIT_REPORTS_TABLE  = aws_dynamodb_table.audit_reports.name
    CERTS_TABLE          = aws_dynamodb_table.compliance_certs.name
    SCORES_TABLE         = aws_dynamodb_table.supplier_scores.name
    NOTIFICATIONS_TABLE  = aws_dynamodb_table.notifications.name
    DOCUMENTS_BUCKET     = aws_s3_bucket.documents.id
    ANALYTICS_BUCKET     = aws_s3_bucket.analytics.id
    CERT_EXPIRY_TOPIC    = aws_sns_topic.cert_expiry_alerts.arn
    SCORE_DROP_TOPIC     = aws_sns_topic.score_drop_alerts.arn
    AWS_REGION_NAME      = var.aws_region
    ENVIRONMENT          = var.environment
  }
}

# ─────────────────────────────────────────────
# Lambda Functions
# ─────────────────────────────────────────────

resource "aws_lambda_function" "upload_document" {
  function_name    = "${local.name_prefix}-upload-document"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "handler.lambda_handler"
  runtime          = var.lambda_runtime
  timeout          = var.lambda_timeout
  memory_size      = var.lambda_memory
  filename         = data.archive_file.upload_document.output_path
  source_code_hash = data.archive_file.upload_document.output_base64sha256

  vpc_config {
    subnet_ids         = local.lambda_vpc_config.subnet_ids
    security_group_ids = local.lambda_vpc_config.security_group_ids
  }

  environment {
    variables = local.lambda_environment_vars
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_vpc,
    aws_cloudwatch_log_group.lambda_upload_document
  ]

  tags = { Name = "UploadDocument" }
}

resource "aws_lambda_function" "process_document" {
  function_name    = "${local.name_prefix}-process-document"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "handler.lambda_handler"
  runtime          = var.lambda_runtime
  timeout          = 120
  memory_size      = 512
  filename         = data.archive_file.process_document.output_path
  source_code_hash = data.archive_file.process_document.output_base64sha256

  vpc_config {
    subnet_ids         = local.lambda_vpc_config.subnet_ids
    security_group_ids = local.lambda_vpc_config.security_group_ids
  }

  environment {
    variables = local.lambda_environment_vars
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_vpc,
    aws_cloudwatch_log_group.lambda_process_document
  ]

  tags = { Name = "ProcessDocument" }
}

resource "aws_lambda_function" "get_suppliers" {
  function_name    = "${local.name_prefix}-get-suppliers"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "handler.lambda_handler"
  runtime          = var.lambda_runtime
  timeout          = var.lambda_timeout
  memory_size      = var.lambda_memory
  filename         = data.archive_file.get_suppliers.output_path
  source_code_hash = data.archive_file.get_suppliers.output_base64sha256

  vpc_config {
    subnet_ids         = local.lambda_vpc_config.subnet_ids
    security_group_ids = local.lambda_vpc_config.security_group_ids
  }

  environment {
    variables = local.lambda_environment_vars
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_vpc,
    aws_cloudwatch_log_group.lambda_get_suppliers
  ]

  tags = { Name = "GetSuppliers" }
}

resource "aws_lambda_function" "submit_audit" {
  function_name    = "${local.name_prefix}-submit-audit"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "handler.lambda_handler"
  runtime          = var.lambda_runtime
  timeout          = var.lambda_timeout
  memory_size      = var.lambda_memory
  filename         = data.archive_file.submit_audit.output_path
  source_code_hash = data.archive_file.submit_audit.output_base64sha256

  vpc_config {
    subnet_ids         = local.lambda_vpc_config.subnet_ids
    security_group_ids = local.lambda_vpc_config.security_group_ids
  }

  environment {
    variables = local.lambda_environment_vars
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_vpc,
    aws_cloudwatch_log_group.lambda_submit_audit
  ]

  tags = { Name = "SubmitAudit" }
}

resource "aws_lambda_function" "get_dashboard" {
  function_name    = "${local.name_prefix}-get-dashboard"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "handler.lambda_handler"
  runtime          = var.lambda_runtime
  timeout          = var.lambda_timeout
  memory_size      = var.lambda_memory
  filename         = data.archive_file.get_dashboard.output_path
  source_code_hash = data.archive_file.get_dashboard.output_base64sha256

  vpc_config {
    subnet_ids         = local.lambda_vpc_config.subnet_ids
    security_group_ids = local.lambda_vpc_config.security_group_ids
  }

  environment {
    variables = local.lambda_environment_vars
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_vpc,
    aws_cloudwatch_log_group.lambda_get_dashboard
  ]

  tags = { Name = "GetDashboard" }
}

# ─────────────────────────────────────────────
# S3 Trigger for process_document
# ─────────────────────────────────────────────
resource "aws_lambda_permission" "s3_trigger" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.process_document.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.documents.arn
}

resource "aws_s3_bucket_notification" "document_upload" {
  bucket = aws_s3_bucket.documents.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.process_document.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "uploads/"
    filter_suffix       = ".pdf"
  }

  lambda_function {
    lambda_function_arn = aws_lambda_function.process_document.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "uploads/"
    filter_suffix       = ".jpg"
  }

  lambda_function {
    lambda_function_arn = aws_lambda_function.process_document.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "uploads/"
    filter_suffix       = ".png"
  }

  depends_on = [aws_lambda_permission.s3_trigger]
}
