terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket       = "control-plane-terraform-states-970547363172"
    key          = "parking-app/iam-oidc/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = "us-east-1"
}

data "aws_caller_identity" "current" {}

# OIDC Provider para GitHub Actions
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  # AWS valida automáticamente los certificados de GitHub via su librería de CAs raíz.
  # El thumbprint es requerido por la API pero no se usa para validación activa.
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd"
  ]

  tags = {
    Name = "GitHub Actions OIDC Provider"
  }
}

# Rol IAM para GitHub Actions de este proyecto
resource "aws_iam_role" "github_actions" {
  name = "github-actions-parking-app"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:andressep95/parking-app-infra:*"
        }
      }
    }]
  })

  tags = {
    Name    = "GitHub Actions Role"
    Project = "parking-app"
  }
}

# Permisos para servicios de infraestructura (sin IAM, Billing, Organizations)
resource "aws_iam_role_policy" "infrastructure_services" {
  name = "infrastructure-services"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["ec2:*"], Resource = "*" },
      { Effect = "Allow", Action = ["rds:*"], Resource = "*" },
      { Effect = "Allow", Action = ["lambda:*"], Resource = "*" },
      { Effect = "Allow", Action = ["s3:*"], Resource = "*" },
      { Effect = "Allow", Action = ["cloudwatch:*", "logs:*"], Resource = "*" },
      { Effect = "Allow", Action = ["ecs:*", "eks:*", "ecr:*"], Resource = "*" },
      { Effect = "Allow", Action = ["elasticache:*"], Resource = "*" },
      { Effect = "Allow", Action = ["sns:*", "sqs:*"], Resource = "*" },
      { Effect = "Allow", Action = ["secretsmanager:*"], Resource = "*" },
      { Effect = "Allow", Action = ["ssm:*"], Resource = "*" },
      { Effect = "Allow", Action = ["route53:*"], Resource = "*" },
      { Effect = "Allow", Action = ["acm:*"], Resource = "*" },
      { Effect = "Allow", Action = ["cloudfront:*"], Resource = "*" },
      { Effect = "Allow", Action = ["dynamodb:*"], Resource = "*" },
      { Effect = "Allow", Action = ["apigateway:*"], Resource = "*" },
      { Effect = "Allow", Action = ["elasticloadbalancing:*"], Resource = "*" },
      { Effect = "Allow", Action = ["autoscaling:*"], Resource = "*" },
      { Effect = "Allow", Action = ["events:*"], Resource = "*" },
      { Effect = "Allow", Action = ["states:*"], Resource = "*" },
      { Effect = "Allow", Action = ["kinesis:*", "firehose:*"], Resource = "*" },
      { Effect = "Allow", Action = ["cognito-idp:*", "cognito-identity:*"], Resource = "*" },
      { Effect = "Allow", Action = ["es:*"], Resource = "*" },
      { Effect = "Allow", Action = ["backup:*"], Resource = "*" },
      { Effect = "Allow", Action = ["kms:*"], Resource = "*" },
      {
        Effect   = "Allow"
        Action   = ["iam:Get*", "iam:List*", "iam:PassRole"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:CreateInstanceProfile",
          "iam:DeleteInstanceProfile",
          "iam:AddRoleToInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile",
          "iam:TagRole",
          "iam:UntagRole",
          "iam:TagInstanceProfile",
          "iam:UntagInstanceProfile"
        ]
        Resource = [
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/parking-app-*",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:instance-profile/parking-app-*"
        ]
      }
    ]
  })
}

# NOTA: Este rol NO tiene acceso a:
# - Billing y Cost Management
# - AWS Organizations
# - IAM Users/Groups (solo roles con prefijo parking-app-*)
# - Account settings

# ─── Rol IAM para parking-app-backend (solo deploy de Lambdas) ───────────────

resource "aws_iam_role" "github_actions_backend" {
  name = "github-actions-parking-app-backend"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:andressep95/parking-app-backend:*"
        }
      }
    }]
  })

  tags = {
    Name    = "GitHub Actions Backend Role"
    Project = "parking-app"
  }
}

resource "aws_iam_role_policy" "backend_lambda_deploy" {
  name = "lambda-deploy"
  role = aws_iam_role.github_actions_backend.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:UpdateFunctionCode",
          "lambda:GetFunction",
          "lambda:GetFunctionConfiguration"
        ]
        Resource = "arn:aws:lambda:*:${data.aws_caller_identity.current.account_id}:function:*-parking-app-*"
      }
    ]
  })
}

output "github_actions_role_arn" {
  value       = aws_iam_role.github_actions.arn
  description = "ARN del rol para usar en GitHub Actions"
}

output "oidc_provider_arn" {
  value       = aws_iam_openid_connect_provider.github.arn
  description = "ARN del OIDC provider"
}

output "github_actions_backend_role_arn" {
  value       = aws_iam_role.github_actions_backend.arn
  description = "ARN del rol para deploy de Lambdas desde parking-app-backend"
}
