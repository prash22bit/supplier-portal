# ─────────────────────────────────────────────
# Lambda CloudWatch Log Groups
# ─────────────────────────────────────────────
resource "aws_cloudwatch_log_group" "lambda_upload_document" {
  name              = "/aws/lambda/${local.name_prefix}-upload-document"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "lambda_process_document" {
  name              = "/aws/lambda/${local.name_prefix}-process-document"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "lambda_get_suppliers" {
  name              = "/aws/lambda/${local.name_prefix}-get-suppliers"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "lambda_submit_audit" {
  name              = "/aws/lambda/${local.name_prefix}-submit-audit"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "lambda_get_dashboard" {
  name              = "/aws/lambda/${local.name_prefix}-get-dashboard"
  retention_in_days = 30
}

# ─────────────────────────────────────────────
# CloudWatch Alarms
# ─────────────────────────────────────────────

# Lambda Error Rate Alarm
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  for_each = {
    "upload-document"  = aws_lambda_function.upload_document.function_name
    "process-document" = aws_lambda_function.process_document.function_name
    "get-suppliers"    = aws_lambda_function.get_suppliers.function_name
    "submit-audit"     = aws_lambda_function.submit_audit.function_name
    "get-dashboard"    = aws_lambda_function.get_dashboard.function_name
  }

  alarm_name          = "${local.name_prefix}-${each.key}-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Lambda function ${each.key} error rate is too high"
  alarm_actions       = [aws_sns_topic.score_drop_alerts.arn]

  dimensions = {
    FunctionName = each.value
  }

  tags = {
    Name = "${local.name_prefix}-${each.key}-error-alarm"
  }
}

# API Gateway 5XX Alarm
resource "aws_cloudwatch_metric_alarm" "api_5xx" {
  alarm_name          = "${local.name_prefix}-api-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "5XXError"
  namespace           = "AWS/ApiGateway"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "API Gateway 5XX error rate is too high"
  alarm_actions       = [aws_sns_topic.score_drop_alerts.arn]

  dimensions = {
    ApiName = aws_api_gateway_rest_api.main.name
  }
}

# ─────────────────────────────────────────────
# CloudWatch Dashboard
# ─────────────────────────────────────────────
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${local.name_prefix}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          title  = "API Gateway - Request Count"
          period = 300
          stat   = "Sum"
          metrics = [
            ["AWS/ApiGateway", "Count", "ApiName", aws_api_gateway_rest_api.main.name]
          ]
          view   = "timeSeries"
          region = var.aws_region
        }
        x      = 0
        y      = 0
        width  = 12
        height = 6
      },
      {
        type = "metric"
        properties = {
          title  = "API Gateway - Latency"
          period = 300
          stat   = "Average"
          metrics = [
            ["AWS/ApiGateway", "Latency", "ApiName", aws_api_gateway_rest_api.main.name],
            ["AWS/ApiGateway", "IntegrationLatency", "ApiName", aws_api_gateway_rest_api.main.name]
          ]
          view   = "timeSeries"
          region = var.aws_region
        }
        x      = 12
        y      = 0
        width  = 12
        height = 6
      },
      {
        type = "metric"
        properties = {
          title  = "Lambda - Invocations"
          period = 300
          stat   = "Sum"
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.get_dashboard.function_name],
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.get_suppliers.function_name],
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.submit_audit.function_name],
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.upload_document.function_name],
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.process_document.function_name]
          ]
          view   = "timeSeries"
          region = var.aws_region
        }
        x      = 0
        y      = 6
        width  = 12
        height = 6
      },
      {
        type = "metric"
        properties = {
          title  = "Lambda - Errors"
          period = 300
          stat   = "Sum"
          metrics = [
            ["AWS/Lambda", "Errors", "FunctionName", aws_lambda_function.get_dashboard.function_name],
            ["AWS/Lambda", "Errors", "FunctionName", aws_lambda_function.get_suppliers.function_name],
            ["AWS/Lambda", "Errors", "FunctionName", aws_lambda_function.submit_audit.function_name],
            ["AWS/Lambda", "Errors", "FunctionName", aws_lambda_function.upload_document.function_name],
            ["AWS/Lambda", "Errors", "FunctionName", aws_lambda_function.process_document.function_name]
          ]
          view   = "timeSeries"
          region = var.aws_region
        }
        x      = 12
        y      = 6
        width  = 12
        height = 6
      },
      {
        type = "metric"
        properties = {
          title  = "DynamoDB - Read/Write Capacity"
          period = 300
          stat   = "Sum"
          metrics = [
            ["AWS/DynamoDB", "ConsumedReadCapacityUnits", "TableName", aws_dynamodb_table.suppliers.name],
            ["AWS/DynamoDB", "ConsumedWriteCapacityUnits", "TableName", aws_dynamodb_table.suppliers.name],
            ["AWS/DynamoDB", "ConsumedReadCapacityUnits", "TableName", aws_dynamodb_table.audit_reports.name],
            ["AWS/DynamoDB", "ConsumedWriteCapacityUnits", "TableName", aws_dynamodb_table.audit_reports.name]
          ]
          view   = "timeSeries"
          region = var.aws_region
        }
        x      = 0
        y      = 12
        width  = 24
        height = 6
      }
    ]
  })
}
