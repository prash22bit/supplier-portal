# ─────────────────────────────────────────────
# AWS Glue Database
# ─────────────────────────────────────────────
resource "aws_glue_catalog_database" "main" {
  name        = "${replace(local.name_prefix, "-", "_")}_analytics"
  description = "Supplier Quality Portal analytics database"
}

# ─────────────────────────────────────────────
# Glue IAM Role
# ─────────────────────────────────────────────
resource "aws_iam_role" "glue" {
  name = "${local.name_prefix}-glue-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "glue.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "glue_service" {
  role       = aws_iam_role.glue.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy" "glue_s3" {
  name = "${local.name_prefix}-glue-s3-policy"
  role = aws_iam_role.glue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ]
      Resource = [
        aws_s3_bucket.analytics.arn,
        "${aws_s3_bucket.analytics.arn}/*"
      ]
    }]
  })
}

# ─────────────────────────────────────────────
# Glue Crawlers
# ─────────────────────────────────────────────
resource "aws_glue_crawler" "audit_data" {
  database_name = aws_glue_catalog_database.main.name
  name          = "${local.name_prefix}-audit-crawler"
  role          = aws_iam_role.glue.arn
  description   = "Crawls audit export data in S3"
  schedule      = "cron(0 2 * * ? *)"  # 2 AM UTC daily

  s3_target {
    path = "s3://${aws_s3_bucket.analytics.id}/audits/"
  }

  s3_target {
    path = "s3://${aws_s3_bucket.analytics.id}/suppliers/"
  }

  schema_change_policy {
    delete_behavior = "LOG"
    update_behavior = "LOG"
  }

  recrawl_policy {
    recrawl_behavior = "CRAWL_NEW_FOLDERS_ONLY"
  }

  tags = {
    Name = "Audit Data Crawler"
  }
}

# ─────────────────────────────────────────────
# Athena Workgroup
# ─────────────────────────────────────────────
resource "aws_athena_workgroup" "main" {
  name        = "${local.name_prefix}-workgroup"
  description = "Supplier Quality Portal analytics workgroup"

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true

    result_configuration {
      output_location = "s3://${aws_s3_bucket.analytics.id}/athena-results/"

      encryption_configuration {
        encryption_option = "SSE_S3"
      }
    }

    engine_version {
      selected_engine_version = "Athena engine version 3"
    }
  }

  tags = {
    Name = "${local.name_prefix}-athena-workgroup"
  }
}

# ─────────────────────────────────────────────
# Named Athena Queries
# ─────────────────────────────────────────────
resource "aws_athena_named_query" "supplier_compliance_summary" {
  name        = "SupplierComplianceSummary"
  workgroup   = aws_athena_workgroup.main.id
  database    = aws_glue_catalog_database.main.name
  description = "Summary of supplier compliance scores by state"

  query = <<-EOT
    SELECT
      state,
      COUNT(*) as total_suppliers,
      AVG(compliance_score) as avg_score,
      COUNT(CASE WHEN compliance_score >= 80 THEN 1 END) as compliant_count,
      COUNT(CASE WHEN compliance_score < 80 THEN 1 END) as non_compliant_count
    FROM suppliers
    GROUP BY state
    ORDER BY avg_score DESC;
  EOT
}

resource "aws_athena_named_query" "expiring_certs" {
  name        = "ExpiringCertificates"
  workgroup   = aws_athena_workgroup.main.id
  database    = aws_glue_catalog_database.main.name
  description = "List of certificates expiring in the next 90 days"

  query = <<-EOT
    SELECT
      supplier_id,
      supplier_name,
      cert_type,
      expiry_date,
      DATE_DIFF('day', CURRENT_DATE, CAST(expiry_date AS DATE)) as days_until_expiry
    FROM compliance_certs
    WHERE CAST(expiry_date AS DATE) BETWEEN CURRENT_DATE AND DATE_ADD('day', 90, CURRENT_DATE)
    ORDER BY days_until_expiry ASC;
  EOT
}

resource "aws_athena_named_query" "audit_trend" {
  name        = "AuditTrendAnalysis"
  workgroup   = aws_athena_workgroup.main.id
  database    = aws_glue_catalog_database.main.name
  description = "Monthly audit trend showing status distribution"

  query = <<-EOT
    SELECT
      DATE_FORMAT(CAST(created_at AS TIMESTAMP), '%Y-%m') as month,
      status,
      COUNT(*) as count
    FROM audit_reports
    GROUP BY DATE_FORMAT(CAST(created_at AS TIMESTAMP), '%Y-%m'), status
    ORDER BY month DESC, status;
  EOT
}
