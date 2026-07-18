output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_app_subnet_ids" {
  description = "Private app subnet IDs"
  value       = aws_subnet.private_app[*].id
}

output "private_data_subnet_ids" {
  description = "Private data subnet IDs"
  value       = aws_subnet.private_data[*].id
}

output "frontend_bucket_name" {
  description = "S3 bucket name for frontend static website"
  value       = aws_s3_bucket.frontend.id
}

output "frontend_website_url" {
  description = "Frontend static website URL"
  value       = "http://${aws_s3_bucket_website_configuration.frontend.website_endpoint}"
}

output "documents_bucket_name" {
  description = "S3 bucket name for supplier documents"
  value       = aws_s3_bucket.documents.id
}

output "api_gateway_url" {
  description = "API Gateway invoke URL"
  value       = aws_api_gateway_stage.prod.invoke_url
}

output "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  value       = aws_cognito_user_pool.main.id
}

output "cognito_client_id" {
  description = "Cognito App Client ID"
  value       = aws_cognito_user_pool_client.main.id
}

output "cognito_domain" {
  description = "Cognito hosted UI domain"
  value       = "https://${aws_cognito_user_pool_domain.main.domain}.auth.${var.aws_region}.amazoncognito.com"
}

output "suppliers_table_name" {
  description = "DynamoDB Suppliers table name"
  value       = aws_dynamodb_table.suppliers.name
}

output "audit_reports_table_name" {
  description = "DynamoDB AuditReports table name"
  value       = aws_dynamodb_table.audit_reports.name
}

output "compliance_certs_table_name" {
  description = "DynamoDB ComplianceCertificates table name"
  value       = aws_dynamodb_table.compliance_certs.name
}

output "sns_alert_topic_arn" {
  description = "SNS topic ARN for alerts"
  value       = aws_sns_topic.cert_expiry_alerts.arn
}

output "cloudwatch_dashboard_url" {
  description = "CloudWatch dashboard URL"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
}
