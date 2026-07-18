# ─────────────────────────────────────────────
# Suppliers Table
# ─────────────────────────────────────────────
resource "aws_dynamodb_table" "suppliers" {
  name         = "${local.name_prefix}-suppliers"
  billing_mode = var.dynamodb_billing_mode
  hash_key     = "supplierId"

  attribute {
    name = "supplierId"
    type = "S"
  }

  attribute {
    name = "state"
    type = "S"
  }

  attribute {
    name = "category"
    type = "S"
  }

  attribute {
    name = "complianceScore"
    type = "N"
  }

  global_secondary_index {
    name            = "StateIndex"
    hash_key        = "state"
    range_key       = "complianceScore"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "CategoryIndex"
    hash_key        = "category"
    range_key       = "complianceScore"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Name = "Suppliers"
  }
}

# ─────────────────────────────────────────────
# Audit Reports Table
# ─────────────────────────────────────────────
resource "aws_dynamodb_table" "audit_reports" {
  name         = "${local.name_prefix}-audit-reports"
  billing_mode = var.dynamodb_billing_mode
  hash_key     = "auditId"
  range_key    = "createdAt"

  attribute {
    name = "auditId"
    type = "S"
  }

  attribute {
    name = "createdAt"
    type = "S"
  }

  attribute {
    name = "supplierId"
    type = "S"
  }

  attribute {
    name = "status"
    type = "S"
  }

  global_secondary_index {
    name            = "SupplierAuditIndex"
    hash_key        = "supplierId"
    range_key       = "createdAt"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "StatusIndex"
    hash_key        = "status"
    range_key       = "createdAt"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Name = "AuditReports"
  }
}

# ─────────────────────────────────────────────
# Compliance Certificates Table
# ─────────────────────────────────────────────
resource "aws_dynamodb_table" "compliance_certs" {
  name         = "${local.name_prefix}-compliance-certs"
  billing_mode = var.dynamodb_billing_mode
  hash_key     = "certId"

  attribute {
    name = "certId"
    type = "S"
  }

  attribute {
    name = "supplierId"
    type = "S"
  }

  attribute {
    name = "expiryDate"
    type = "S"
  }

  attribute {
    name = "certType"
    type = "S"
  }

  global_secondary_index {
    name            = "SupplierCertIndex"
    hash_key        = "supplierId"
    range_key       = "expiryDate"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "CertTypeExpiryIndex"
    hash_key        = "certType"
    range_key       = "expiryDate"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  tags = {
    Name = "ComplianceCertificates"
  }
}

# ─────────────────────────────────────────────
# Supplier Scores Table (time-series)
# ─────────────────────────────────────────────
resource "aws_dynamodb_table" "supplier_scores" {
  name         = "${local.name_prefix}-supplier-scores"
  billing_mode = var.dynamodb_billing_mode
  hash_key     = "supplierId"
  range_key    = "scoreDate"

  attribute {
    name = "supplierId"
    type = "S"
  }

  attribute {
    name = "scoreDate"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Name = "SupplierScores"
  }
}

# ─────────────────────────────────────────────
# Notifications / Alerts Table
# ─────────────────────────────────────────────
resource "aws_dynamodb_table" "notifications" {
  name         = "${local.name_prefix}-notifications"
  billing_mode = var.dynamodb_billing_mode
  hash_key     = "notificationId"
  range_key    = "createdAt"

  attribute {
    name = "notificationId"
    type = "S"
  }

  attribute {
    name = "createdAt"
    type = "S"
  }

  attribute {
    name = "userId"
    type = "S"
  }

  global_secondary_index {
    name            = "UserNotificationIndex"
    hash_key        = "userId"
    range_key       = "createdAt"
    projection_type = "ALL"
  }

  server_side_encryption {
    enabled = true
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  tags = {
    Name = "Notifications"
  }
}
