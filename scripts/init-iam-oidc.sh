#!/bin/bash
set -e

BUCKET_NAME="control-plane-terraform-states-970547363172"
REGION="us-east-1"
PROJECT_NAME="parking-app"

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "📝 Configuración detectada:"
echo "   • Bucket: $BUCKET_NAME"
echo "   • Region: $REGION"
echo "   • Project: $PROJECT_NAME"
echo "   • Account ID: $AWS_ACCOUNT_ID"
echo ""

echo "🚀 Inicializando Terraform..."
cd infrastructure/iam-oidc
terraform init -reconfigure

# Sincronizar OIDC provider si ya existe en la cuenta
OIDC_ARN=$(aws iam list-open-id-connect-providers \
  --query 'OpenIDConnectProviderList[?contains(Arn, `token.actions.githubusercontent.com`)].Arn' \
  --output text 2>/dev/null)

if [ -n "$OIDC_ARN" ]; then
  echo "⚠️  OIDC Provider ya existe. Importando al estado de Terraform..."
  terraform import aws_iam_openid_connect_provider.github "$OIDC_ARN" 2>/dev/null || true
fi

# Sincronizar rol si ya existe
ROLE_ARN=$(aws iam get-role --role-name "github-actions-$PROJECT_NAME" \
  --query 'Role.Arn' --output text 2>/dev/null || echo "")

if [ -n "$ROLE_ARN" ] && [ "$ROLE_ARN" != "None" ]; then
  echo "⚠️  IAM Role ya existe. Importando al estado de Terraform..."
  terraform import aws_iam_role.github_actions "github-actions-$PROJECT_NAME" 2>/dev/null || true
fi

echo ""
echo "🚀 Aplicando configuración..."
terraform apply -auto-approve

echo ""
echo "📋 Configura este ARN como secret AWS_ROLE_ARN en GitHub:"
echo ""
terraform output github_actions_role_arn
