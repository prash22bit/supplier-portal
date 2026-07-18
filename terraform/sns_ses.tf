# ─────────────────────────────────────────────
# SNS Topics
# ─────────────────────────────────────────────
resource "aws_sns_topic" "cert_expiry_alerts" {
  name = "${local.name_prefix}-cert-expiry-alerts"

  tags = {
    Name = "Certificate Expiry Alerts"
  }
}

resource "aws_sns_topic" "score_drop_alerts" {
  name = "${local.name_prefix}-score-drop-alerts"

  tags = {
    Name = "Supplier Score Drop Alerts"
  }
}

resource "aws_sns_topic" "audit_notifications" {
  name = "${local.name_prefix}-audit-notifications"

  tags = {
    Name = "Audit Notifications"
  }
}

# ─────────────────────────────────────────────
# SNS Email Subscriptions
# ─────────────────────────────────────────────
resource "aws_sns_topic_subscription" "cert_expiry_email" {
  topic_arn = aws_sns_topic.cert_expiry_alerts.arn
  protocol  = "email"
  endpoint  = var.admin_email
}

resource "aws_sns_topic_subscription" "score_drop_email" {
  topic_arn = aws_sns_topic.score_drop_alerts.arn
  protocol  = "email"
  endpoint  = var.admin_email
}

resource "aws_sns_topic_subscription" "audit_notification_email" {
  topic_arn = aws_sns_topic.audit_notifications.arn
  protocol  = "email"
  endpoint  = var.admin_email
}

# ─────────────────────────────────────────────
# SES Email Identity (requires manual verification)
# ─────────────────────────────────────────────
resource "aws_ses_email_identity" "admin" {
  email = var.admin_email
}

# ─────────────────────────────────────────────
# EventBridge Rule for Certificate Expiry Check (daily)
# ─────────────────────────────────────────────
resource "aws_cloudwatch_event_rule" "cert_expiry_check" {
  name                = "${local.name_prefix}-cert-expiry-check"
  description         = "Daily check for expiring compliance certificates"
  schedule_expression = "cron(0 6 * * ? *)"  # 6 AM UTC daily

  tags = {
    Name = "Certificate Expiry Check"
  }
}

resource "aws_cloudwatch_event_target" "cert_expiry_lambda" {
  rule      = aws_cloudwatch_event_rule.cert_expiry_check.name
  target_id = "ProcessDocumentLambda"
  arn       = aws_lambda_function.get_dashboard.arn
}

resource "aws_lambda_permission" "eventbridge_cert_check" {
  statement_id  = "AllowEventBridgeCertCheck"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_dashboard.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.cert_expiry_check.arn
}
