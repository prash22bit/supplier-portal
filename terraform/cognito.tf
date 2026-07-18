# ─────────────────────────────────────────────
# Cognito User Pool
# ─────────────────────────────────────────────
resource "aws_cognito_user_pool" "main" {
  name = "${local.name_prefix}-user-pool"

  # Username configuration
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  # Password policy
  password_policy {
    minimum_length                   = var.cognito_password_minimum_length
    require_lowercase                = true
    require_numbers                  = true
    require_symbols                  = true
    require_uppercase                = true
    temporary_password_validity_days = 7
  }

  # MFA configuration (optional - OPTIONAL means users can choose)
  mfa_configuration = "OPTIONAL"

  software_token_mfa_configuration {
    enabled = true
  }

  # Account recovery
  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  # Email configuration
  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }

  # Schema attributes
  schema {
    attribute_data_type      = "String"
    developer_only_attribute = false
    mutable                  = true
    name                     = "role"
    required                 = false

    string_attribute_constraints {
      min_length = 1
      max_length = 50
    }
  }

  schema {
    attribute_data_type      = "String"
    developer_only_attribute = false
    mutable                  = true
    name                     = "supplierId"
    required                 = false

    string_attribute_constraints {
      min_length = 0
      max_length = 100
    }
  }

  schema {
    attribute_data_type      = "String"
    developer_only_attribute = false
    mutable                  = true
    name                     = "companyName"
    required                 = false

    string_attribute_constraints {
      min_length = 0
      max_length = 200
    }
  }

  # User pool add-ons
  user_pool_add_ons {
    advanced_security_mode = "ENFORCED"
  }

  # Verification message templates
  verification_message_template {
    default_email_option = "CONFIRM_WITH_LINK"
    email_subject_by_link = "Supplier Quality Portal - Verify Your Email"
    email_message_by_link = "Please click the link below to verify your email for the Supplier Quality Audit & Compliance Portal: {##Click Here##}"
  }

  # Admin create user config
  admin_create_user_config {
    allow_admin_create_user_only = false

    invite_message_template {
      email_subject = "Welcome to Supplier Quality Audit & Compliance Portal"
      email_message = "Your username is {username} and temporary password is {####}. Please log in at https://supplierportal.com and change your password."
      sms_message   = "Your username is {username} and temporary password is {####}"
    }
  }

  tags = {
    Name = "${local.name_prefix}-user-pool"
  }
}

# ─────────────────────────────────────────────
# User Pool Domain
# ─────────────────────────────────────────────
resource "aws_cognito_user_pool_domain" "main" {
  domain       = "${local.name_prefix}-${local.random_suffix}"
  user_pool_id = aws_cognito_user_pool.main.id
}

# ─────────────────────────────────────────────
# App Client (SPA - no secret)
# ─────────────────────────────────────────────
resource "aws_cognito_user_pool_client" "main" {
  name         = "${local.name_prefix}-spa-client"
  user_pool_id = aws_cognito_user_pool.main.id

  # No client secret for SPA
  generate_secret = false

  # Token validity
  access_token_validity  = 1   # hours
  id_token_validity      = 1   # hours
  refresh_token_validity = 30  # days

  token_validity_units {
    access_token  = "hours"
    id_token      = "hours"
    refresh_token = "days"
  }

  # OAuth flows
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["implicit", "code"]
  allowed_oauth_scopes                 = ["email", "openid", "profile"]

  callback_urls = [
    "http://localhost:3000/callback",
    "http://localhost:8080/callback",
    "https://${aws_s3_bucket.frontend.bucket}.s3-website.${var.aws_region}.amazonaws.com/callback"
  ]

  logout_urls = [
    "http://localhost:3000",
    "http://localhost:8080",
    "https://${aws_s3_bucket.frontend.bucket}.s3-website.${var.aws_region}.amazonaws.com"
  ]

  supported_identity_providers = ["COGNITO"]

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]

  prevent_user_existence_errors = "ENABLED"

  read_attributes = [
    "email",
    "email_verified",
    "name",
    "custom:role",
    "custom:supplierId",
    "custom:companyName"
  ]

  write_attributes = [
    "email",
    "name",
    "custom:role",
    "custom:supplierId",
    "custom:companyName"
  ]
}

# ─────────────────────────────────────────────
# User Groups
# (role_arn omitted: no Cognito Identity Pool in this stack;
#  authorization is handled by Lambda using Cognito JWT claims)
# ─────────────────────────────────────────────
resource "aws_cognito_user_group" "admins" {
  name         = "Admins"
  user_pool_id = aws_cognito_user_pool.main.id
  description  = "System administrators with full access"
  precedence   = 1
}

resource "aws_cognito_user_group" "quality_managers" {
  name         = "QualityManagers"
  user_pool_id = aws_cognito_user_pool.main.id
  description  = "Quality managers who review audits"
  precedence   = 2
}

resource "aws_cognito_user_group" "suppliers" {
  name         = "Suppliers"
  user_pool_id = aws_cognito_user_pool.main.id
  description  = "Supplier users who submit documents"
  precedence   = 3
}
