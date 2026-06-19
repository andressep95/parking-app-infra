#!/bin/bash
set -e

# Setup completo de GitHub para parking-app-infra (GitOps + CloudFormation + AWS)
# Configura: variables de repositorio, secrets, environments y protección de ramas
# Requiere: gh CLI instalado y autenticado
#
# ── Editar antes de ejecutar ───────────────────────────────────────────────────
PROJECT_NAME="parking-app"
# ──────────────────────────────────────────────────────────────────────────────

echo "🚀 GitHub Project Setup — parking-app-infra (GitOps + CloudFormation)"
echo "======================================================================="
echo ""

# ─── Verificaciones previas ───────────────────────────────────────────────────

if ! command -v gh &> /dev/null; then
    echo "❌ gh CLI no está instalado. Ejecutar: brew install gh"
    exit 1
fi

if ! gh auth status &> /dev/null; then
    echo "❌ No estás autenticado en GitHub. Ejecutar: gh auth login"
    exit 1
fi

REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)
if [ -z "$REPO" ]; then
    echo "❌ No se detectó repositorio. Ejecutar desde la raíz del proyecto."
    exit 1
fi

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")

echo "✅ gh CLI autenticado"
echo "📦 Repositorio:  $REPO"
echo "📝 Project name: $PROJECT_NAME"
[ -n "$AWS_ACCOUNT_ID" ] && echo "🔑 Cuenta AWS:   $AWS_ACCOUNT_ID"
echo ""

# ─── Variables de repositorio ─────────────────────────────────────────────────

echo "── Variables de repositorio ──────────────────────────────────────────────"
echo ""

read -p "AWS_REGION [us-east-1]: " AWS_REGION
AWS_REGION=${AWS_REGION:-us-east-1}

# ─── Secrets ──────────────────────────────────────────────────────────────────

echo ""
echo "── Secrets ───────────────────────────────────────────────────────────────"
echo ""

DEFAULT_ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/github-actions-${PROJECT_NAME}"
read -p "AWS_ROLE_ARN [${DEFAULT_ROLE_ARN}]: " AWS_ROLE_ARN
AWS_ROLE_ARN=${AWS_ROLE_ARN:-$DEFAULT_ROLE_ARN}

# ─── Environments ─────────────────────────────────────────────────────────────

echo ""
echo "── Environments ──────────────────────────────────────────────────────────"
echo ""

read -p "¿Crear environment 'dev'? [Y/n]: " CREATE_DEV
CREATE_DEV=${CREATE_DEV:-Y}

read -p "¿Crear environment 'prod'? [y/N]: " CREATE_PROD
CREATE_PROD=${CREATE_PROD:-N}

# ─── Resumen ──────────────────────────────────────────────────────────────────

echo ""
echo "── Resumen ───────────────────────────────────────────────────────────────"
echo ""
echo "  Variables:"
echo "    PROJECT_NAME             = $PROJECT_NAME"
echo "    AWS_REGION               = $AWS_REGION"
echo ""
echo "  Secrets:"
echo "    AWS_ROLE_ARN             = ${AWS_ROLE_ARN:0:60}..."
echo ""
echo "  Environments:"
[[ "$CREATE_DEV"  =~ ^[Yy]$ ]] && echo "    dev  → se creará" || echo "    dev  → omitido"
[[ "$CREATE_PROD" =~ ^[Yy]$ ]] && echo "    prod → se creará (agregar reviewers manualmente después)" || echo "    prod → omitido"
echo ""
echo "  Protección de ramas:"
echo "    main    → PR requerido + solo desde develop"
echo "    develop → PR requerido"
echo ""
echo "  Stacks CloudFormation que se crearán al hacer push:"
[[ "$CREATE_DEV"  =~ ^[Yy]$ ]] && echo "    ${PROJECT_NAME}-dev-cognito"
[[ "$CREATE_PROD" =~ ^[Yy]$ ]] && echo "    ${PROJECT_NAME}-prod-cognito"
echo ""

read -p "¿Aplicar? [Y/n]: " CONFIRM
CONFIRM=${CONFIRM:-Y}
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "❌ Cancelado"
    exit 0
fi

# ─── Aplicar variables ────────────────────────────────────────────────────────

echo ""
echo "📋 Configurando variables..."

gh variable set PROJECT_NAME --body "$PROJECT_NAME" && echo "  ✅ PROJECT_NAME"
gh variable set AWS_REGION   --body "$AWS_REGION"   && echo "  ✅ AWS_REGION"

# ─── Aplicar secrets ─────────────────────────────────────────────────────────

echo ""
echo "🔐 Configurando secrets..."

gh secret set AWS_ROLE_ARN --body "$AWS_ROLE_ARN" && echo "  ✅ AWS_ROLE_ARN"

# ─── Crear environments ───────────────────────────────────────────────────────

echo ""
echo "🌍 Configurando environments..."

if [[ "$CREATE_DEV" =~ ^[Yy]$ ]]; then
    gh api --method PUT "repos/$REPO/environments/dev" --input /dev/null > /dev/null 2>&1 || true
    echo "  ✅ Environment 'dev' creado"
fi

if [[ "$CREATE_PROD" =~ ^[Yy]$ ]]; then
    gh api --method PUT "repos/$REPO/environments/prod" --input /dev/null > /dev/null 2>&1 || true
    echo "  ✅ Environment 'prod' creado"
    echo "  ⚠️  Agrega reviewers en: Settings → Environments → prod → Required reviewers"
fi

# ─── Protección de ramas ─────────────────────────────────────────────────────

echo ""
echo "🔒 Configurando protección de ramas..."

gh api "repos/$REPO/branches/main/protection" \
    --method PUT \
    --header "Accept: application/vnd.github+json" \
    --input - <<'JSON' > /dev/null
{
  "required_status_checks": {
    "strict": false,
    "contexts": ["Only PRs from develop are allowed"]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": { "required_approving_review_count": 0 },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
JSON
echo "  ✅ main → PR requerido, solo desde develop, sin push directo"

gh api "repos/$REPO/branches/develop/protection" \
    --method PUT \
    --header "Accept: application/vnd.github+json" \
    --input - <<'JSON' > /dev/null
{
  "required_status_checks": null,
  "enforce_admins": true,
  "required_pull_request_reviews": { "required_approving_review_count": 0 },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
JSON
echo "  ✅ develop → PR requerido, sin push directo"

# ─── Estado final ─────────────────────────────────────────────────────────────

echo ""
echo "── Estado final ──────────────────────────────────────────────────────────"
echo ""
gh variable list
echo ""
gh secret list
echo ""
echo "✅ Setup completo: $REPO"
echo ""
echo "Próximos pasos:"
echo "  1. Aplicar la actualización del IAM role (agrega cloudformation:*):"
echo "     cd infrastructure/iam-oidc && terraform apply"
echo "  2. Destruir la infra Terraform existente si hay recursos desplegados:"
echo "     (recuperar el módulo desde git history o hacer destroy manual en consola)"
echo "  3. Crear rama develop: git checkout -b develop && git push -u origin develop"
echo "  4. Crear feature branch y abrir PR a develop:"
echo "     → cfn-validate corre automáticamente y comenta el change set en el PR"
echo "  5. Merge a develop → cfn-deploy despliega el stack CloudFormation en dev"
