# ─────────────────────────────────────────────
# REST API
# ─────────────────────────────────────────────
resource "aws_api_gateway_rest_api" "main" {
  name        = "${local.name_prefix}-api"
  description = "Supplier Quality Audit & Compliance Portal API"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = {
    Name = "${local.name_prefix}-api"
  }
}

# ─────────────────────────────────────────────
# Cognito Authorizer
# ─────────────────────────────────────────────
resource "aws_api_gateway_authorizer" "cognito" {
  name            = "CognitoAuthorizer"
  rest_api_id     = aws_api_gateway_rest_api.main.id
  type            = "COGNITO_USER_POOLS"
  provider_arns   = [aws_cognito_user_pool.main.arn]
  identity_source = "method.request.header.Authorization"
}

# ─────────────────────────────────────────────
# Helper: CORS Mock Integration
# ─────────────────────────────────────────────
locals {
  cors_method_response = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
  cors_integration_response = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS,POST,PUT,DELETE'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

# ─────────────────────────────────────────────
# /dashboard Resource
# ─────────────────────────────────────────────
resource "aws_api_gateway_resource" "dashboard" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "dashboard"
}

resource "aws_api_gateway_method" "dashboard_get" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.dashboard.id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

resource "aws_api_gateway_integration" "dashboard_get" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.dashboard.id
  http_method             = aws_api_gateway_method.dashboard_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.get_dashboard.invoke_arn
}

resource "aws_lambda_permission" "dashboard_apigw" {
  statement_id  = "AllowAPIGatewayDashboard"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_dashboard.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

# ─────────────────────────────────────────────
# /suppliers Resource
# ─────────────────────────────────────────────
resource "aws_api_gateway_resource" "suppliers" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "suppliers"
}

resource "aws_api_gateway_method" "suppliers_get" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.suppliers.id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

resource "aws_api_gateway_integration" "suppliers_get" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.suppliers.id
  http_method             = aws_api_gateway_method.suppliers_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.get_suppliers.invoke_arn
}

resource "aws_lambda_permission" "suppliers_apigw" {
  statement_id  = "AllowAPIGatewaySuppliers"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_suppliers.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

# ─────────────────────────────────────────────
# /audits Resource
# ─────────────────────────────────────────────
resource "aws_api_gateway_resource" "audits" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "audits"
}

resource "aws_api_gateway_method" "audits_post" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.audits.id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

resource "aws_api_gateway_integration" "audits_post" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.audits.id
  http_method             = aws_api_gateway_method.audits_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.submit_audit.invoke_arn
}

resource "aws_api_gateway_method" "audits_get" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.audits.id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

resource "aws_api_gateway_integration" "audits_get" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.audits.id
  http_method             = aws_api_gateway_method.audits_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.submit_audit.invoke_arn
}

resource "aws_lambda_permission" "audits_apigw" {
  statement_id  = "AllowAPIGatewayAudits"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.submit_audit.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

# ─────────────────────────────────────────────
# /documents Resource
# ─────────────────────────────────────────────
resource "aws_api_gateway_resource" "documents" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "documents"
}

resource "aws_api_gateway_method" "documents_post" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.documents.id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

resource "aws_api_gateway_integration" "documents_post" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.documents.id
  http_method             = aws_api_gateway_method.documents_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.upload_document.invoke_arn
}

resource "aws_lambda_permission" "documents_apigw" {
  statement_id  = "AllowAPIGatewayDocuments"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.upload_document.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

# ─────────────────────────────────────────────
# Deployment & Stage
# ─────────────────────────────────────────────
resource "aws_api_gateway_deployment" "main" {
  rest_api_id = aws_api_gateway_rest_api.main.id

  depends_on = [
    aws_api_gateway_integration.dashboard_get,
    aws_api_gateway_integration.suppliers_get,
    aws_api_gateway_integration.audits_post,
    aws_api_gateway_integration.audits_get,
    aws_api_gateway_integration.documents_post
  ]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.main.id
  rest_api_id   = aws_api_gateway_rest_api.main.id
  stage_name    = "prod"

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      caller         = "$context.identity.caller"
      user           = "$context.identity.user"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      resourcePath   = "$context.resourcePath"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
    })
  }

  xray_tracing_enabled = true

  tags = {
    Name = "${local.name_prefix}-api-stage-prod"
  }
}

resource "aws_api_gateway_method_settings" "all" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  stage_name  = aws_api_gateway_stage.prod.stage_name
  method_path = "*/*"

  settings {
    metrics_enabled    = true
    logging_level      = "INFO"
    data_trace_enabled = false
    throttling_burst_limit = 500
    throttling_rate_limit  = 250
  }
}

# ─────────────────────────────────────────────
# API Gateway CloudWatch Log Group
# ─────────────────────────────────────────────
resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/api-gateway/${local.name_prefix}"
  retention_in_days = 30
}

# ─────────────────────────────────────────────
# API Gateway Account (for CloudWatch logging)
# ─────────────────────────────────────────────
resource "aws_api_gateway_account" "main" {
  cloudwatch_role_arn = aws_iam_role.api_gateway_cloudwatch.arn
}

resource "aws_iam_role" "api_gateway_cloudwatch" {
  name = "${local.name_prefix}-apigw-cloudwatch-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "apigateway.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "api_gateway_cloudwatch" {
  role       = aws_iam_role.api_gateway_cloudwatch.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}
