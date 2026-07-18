# Supplier Quality Audit & Compliance Portal

## 🏭 Project Overview
Full-stack AWS-powered portal for managing 340+ suppliers across 18 Indian states and 6 countries.
Built with Terraform IaC + Vanilla HTML/CSS/JS frontend.

---

## 📋 Prerequisites

```powershell
# 1. Install AWS CLI
winget install Amazon.AWSCLI
# OR download from https://aws.amazon.com/cli/

# 2. Install Terraform
winget install Hashicorp.Terraform
# Verify
terraform version   # Should show >= 1.5.0
aws --version

# 3. (Optional) Install VS Code for editing
winget install Microsoft.VisualStudioCode
```

---

## 🔐 AWS Credentials Setup

> ⚠️ IMPORTANT: Create an IAM user instead of using root keys:
> 1. Go to AWS Console → IAM → Users → Create User
> 2. Attach policy: **AdministratorAccess**
> 3. Create Access Key → Download CSV

```powershell
aws configure
# AWS Access Key ID:     <paste your key>
# AWS Secret Access Key: <paste your secret>
# Default region name:   ap-south-1
# Default output format: json

# Verify
aws sts get-caller-identity
```

---

## 🚀 Deploy Infrastructure (Terraform)

```powershell
# Navigate to terraform directory
cd C:\Users\<your-username>\OneDrive\Desktop\aws\supplier-portal\terraform

# Initialize Terraform (downloads providers)
terraform init

# Preview what will be created
terraform plan

# Deploy all infrastructure (~8-12 minutes)
terraform apply -auto-approve

# Save outputs
terraform output
```

### Key Outputs After Apply:
```
frontend_website_url    = "http://sqp-prod-frontend-xxxx.s3-website.ap-south-1.amazonaws.com"
api_gateway_url         = "https://xxxx.execute-api.ap-south-1.amazonaws.com/prod"
cognito_user_pool_id    = "ap-south-1_xxxxxxx"
cognito_client_id       = "xxxxxxxxxxxxxxxxx"
cognito_domain          = "https://sqp-prod-xxxx.auth.ap-south-1.amazoncognito.com"
cloudwatch_dashboard_url = "https://ap-south-1.console.aws.amazon.com/cloudwatch/..."
```

---

## 🌐 Deploy Frontend to S3

```powershell
# From terraform directory — get bucket name
$BUCKET = terraform output -raw frontend_bucket_name
$API_URL = terraform output -raw api_gateway_url
$COGNITO_ID = terraform output -raw cognito_client_id

# Update api.js with real API URL (optional — works with demo data too)
# Edit frontend/js/api.js line 2: const API_BASE = '<your api_gateway_url>';

# Upload all frontend files
aws s3 sync ..\frontend\ s3://$BUCKET --delete

# Get website URL
Write-Host "Open: $(terraform output -raw frontend_website_url)"
```

---

## 👥 Create Test Users in Cognito

```powershell
$USER_POOL_ID = terraform output -raw cognito_user_pool_id

# Create admin user
aws cognito-idp admin-create-user `
  --user-pool-id $USER_POOL_ID `
  --username "admin@supplierportal.com" `
  --temporary-password "Admin@1234" `
  --user-attributes Name=email,Value=admin@supplierportal.com Name=email_verified,Value=true

# Add to Admins group
aws cognito-idp admin-add-user-to-group `
  --user-pool-id $USER_POOL_ID `
  --username "admin@supplierportal.com" `
  --group-name Admins

# Create supplier user
aws cognito-idp admin-create-user `
  --user-pool-id $USER_POOL_ID `
  --username "supplier@example.com" `
  --temporary-password "Supplier@1234" `
  --user-attributes Name=email,Value=supplier@example.com Name=email_verified,Value=true

aws cognito-idp admin-add-user-to-group `
  --user-pool-id $USER_POOL_ID `
  --username "supplier@example.com" `
  --group-name Suppliers
```

---

## 🧪 Test Locally (No AWS Needed)

The frontend works fully with demo data without any AWS deployment:

```powershell
# Option 1: Open directly in browser
cd C:\Users\<your-username>\OneDrive\Desktop\aws\supplier-portal\frontend
start index.html

# Option 2: Local HTTP server (Python)
python -m http.server 8080
# Then open: http://localhost:8080

# Option 3: VS Code Live Server extension
# Right-click index.html → "Open with Live Server"
```

**Demo Login:** `admin@supplierportal.com` / `Admin@1234`

---

## 🏗️ Architecture

```
Internet → ALB → API Gateway → Lambda → DynamoDB
                                    ↘ S3 (documents)
                                    ↘ Textract/Comprehend (AI)
                                    ↘ SNS/SES (alerts)

S3 (frontend) → Cognito (auth) → API Gateway
CloudTrail → S3 → Athena/Glue (analytics)
All Lambdas → CloudWatch (monitoring)
```

---

## 💰 Estimated Monthly Costs (ap-south-1)

| Service | Cost |
|---------|------|
| NAT Gateway x2 | ~$32 |
| API Gateway | ~$5 |
| Lambda (low traffic) | ~$0-2 |
| DynamoDB (on-demand) | ~$1-5 |
| S3 (storage + website) | ~$1-3 |
| Cognito (< 50k MAU) | Free |
| CloudWatch | ~$3-5 |
| Textract/Comprehend | Pay per use |
| **Total** | **~$42-52/month** |

### Destroy when not needed:
```powershell
cd terraform
terraform destroy -auto-approve
```

---

## 📁 Project Structure

```
supplier-portal/
├── terraform/              # All AWS infrastructure (IaC)
│   ├── main.tf             # Provider & root config
│   ├── variables.tf        # Input variables
│   ├── outputs.tf          # Output values
│   ├── vpc.tf              # VPC, subnets, IGW, NAT, Flow Logs
│   ├── security_groups.tf  # SGs + VPC endpoints
│   ├── s3.tf               # 4 S3 buckets
│   ├── dynamodb.tf         # 5 DynamoDB tables
│   ├── cognito.tf          # User pool + groups
│   ├── lambda.tf           # 5 Lambda functions + IAM
│   ├── api_gateway.tf      # REST API + Cognito auth
│   ├── cloudwatch.tf       # Logs + alarms + dashboard
│   ├── cloudtrail.tf       # Audit trail
│   ├── glue_athena.tf      # Analytics pipeline
│   ├── sns_ses.tf          # Notifications
│   └── lambda_functions/   # Python handlers
│       ├── upload_document/handler.py
│       ├── process_document/handler.py
│       ├── get_suppliers/handler.py
│       ├── submit_audit/handler.py
│       └── get_dashboard/handler.py
└── frontend/               # Static HTML/CSS/JS app
    ├── index.html          # Login page
    ├── dashboard.html      # Admin dashboard + charts
    ├── supplier-portal.html # 4-step supplier submission
    ├── audit-list.html     # Audit management
    ├── compliance.html     # Certificate tracker
    ├── reports.html        # Analytics + Athena
    ├── css/styles.css      # Complete design system
    └── js/api.js           # Shared utilities + auth
```
