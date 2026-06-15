# parking-app-infra

Repositorio de infraestructura GitOps para **parking-app**. Toda modificación de infraestructura pasa por Pull Request — nunca directamente en AWS.

---

## Tabla de contenidos

- [Arquitectura general](#arquitectura-general)
- [Estructura del repositorio](#estructura-del-repositorio)
- [Roles IAM y autenticación OIDC](#roles-iam-y-autenticación-oidc)
- [Flujo GitOps paso a paso](#flujo-gitops-paso-a-paso)
- [Workflows de GitHub Actions](#workflows-de-github-actions)
- [Configuración inicial (bootstrap)](#configuración-inicial-bootstrap)
- [Agregar un nuevo entorno](#agregar-un-nuevo-entorno)
- [Agregar un nuevo módulo o recurso](#agregar-un-nuevo-módulo-o-recurso)
- [Detección de drift](#detección-de-drift)
- [Variables y secrets requeridos](#variables-y-secrets-requeridos)

---

## Arquitectura general

```
parking-app-infra (este repo)          parking-app-backend
        │                                      │
        │  PR → terraform plan                 │  push a develop/main
        │  merge → terraform apply             │  → build Go + deploy Lambda
        ▼                                      ▼
  GitHub Actions ──OIDC──► AWS IAM      GitHub Actions ──OIDC──► AWS IAM
  role: github-actions-parking-app      role: github-actions-parking-app-backend
        │                                      │
        ▼                                      ▼
   Terraform State                       aws lambda update-function-code
   S3: control-plane-terraform-states-*       (sin S3, zip directo)
```

La autenticación con AWS es **sin credenciales estáticas**: GitHub Actions obtiene un token OIDC temporal que AWS valida directamente. No hay `AWS_ACCESS_KEY_ID` ni `AWS_SECRET_ACCESS_KEY` en ningún lado.

---

## Estructura del repositorio

```
parking-app-infra/
├── .github/
│   └── workflows/
│       ├── terraform-plan.yml            # Corre en cada PR → comenta el plan
│       ├── terraform-apply.yml           # Corre al mergear → aplica los cambios
│       ├── drift-detection-remediation.yml  # Cada 6h detecta drift y auto-remedia
│       └── check-pr-source.yml           # Bloquea PRs a main que no vengan de develop
│
├── infrastructure/
│   ├── iam-oidc/
│   │   └── main.tf                       # Bootstrap: OIDC provider + roles IAM
│   │
│   ├── environments/
│   │   └── dev/                          # Un directorio por entorno
│   │       ├── main.tf                   # Backend S3 + provider
│   │       ├── variables.tf
│   │       ├── outputs.tf
│   │       ├── data.tf
│   │       ├── cognito.tf
│   │       ├── auth_lambda.tf
│   │       └── api_gateway.tf
│   │
│   └── modules/                          # Módulos reutilizables
│       ├── cognito/
│       ├── lambda/
│       └── gateway/
│           ├── http-v2/
│           ├── rest-v1/
│           └── wrapper/
│
└── scripts/
    ├── init-iam-oidc.sh                  # Aplica el bootstrap de OIDC manualmente
    └── setup-github.sh                   # Configura variables/secrets/environments en GitHub
```

---

## Roles IAM y autenticación OIDC

Existen **dos roles IAM**, cada uno asociado a un repositorio distinto:

### `github-actions-parking-app`
- **Usado por:** `parking-app-infra` (este repo)
- **Propósito:** Ejecutar `terraform plan` y `terraform apply`
- **Permisos:** Acceso amplio a servicios AWS (EC2, RDS, Lambda, S3, Cognito, API GW, etc.) — necesario para que Terraform pueda crear/modificar cualquier recurso
- **Restricción IAM:** Solo puede crear/modificar roles IAM con prefijo `parking-app-*`
- **Trust policy:** `repo:andressep95/parking-app-infra:*`

### `github-actions-parking-app-backend`
- **Usado por:** `parking-app-backend`
- **Propósito:** Desplegar funciones Lambda (update-function-code)
- **Permisos mínimos:**
  - `lambda:UpdateFunctionCode`
  - `lambda:GetFunction`
  - `lambda:GetFunctionConfiguration`
- **Scope:** Solo funciones con patrón `*-parking-app-*` (ej: `dev-parking-app-auth-handler`)
- **Trust policy:** `repo:andressep95/parking-app-backend:*`

### Cómo funciona el OIDC

```
GitHub Actions Runner
       │
       │  1. Solicita token OIDC a GitHub
       ▼
GitHub Token Service
       │
       │  2. Emite JWT firmado con claims:
       │     sub: repo:andressep95/parking-app-infra:ref:refs/heads/develop
       │     aud: sts.amazonaws.com
       ▼
AWS STS (AssumeRoleWithWebIdentity)
       │
       │  3. Valida JWT contra OIDC provider registrado
       │     Verifica que sub coincida con la trust policy del rol
       ▼
  Credenciales temporales (~1h)
       │
       ▼
  AWS API calls (Terraform / Lambda deploy)
```

Los roles IAM viven en `infrastructure/iam-oidc/main.tf` y se aplican **manualmente** con `scripts/init-iam-oidc.sh` — este es el único paso fuera del flujo GitOps automático porque es el bootstrap que habilita el resto.

---

## Flujo GitOps paso a paso

### Desarrollo normal (feature → dev)

```
1. Crear rama desde develop
   git checkout develop && git pull
   git checkout -b feat/mi-nuevo-recurso

2. Modificar Terraform en infrastructure/environments/dev/ o infrastructure/modules/

3. Abrir PR hacia develop
   → terraform-plan.yml se ejecuta automáticamente
   → El plan se comenta en el PR (qué se crea, modifica o destruye)
   → Revisar el plan antes de mergear

4. Mergear PR a develop
   → terraform-apply.yml se ejecuta automáticamente
   → Terraform aplica los cambios en el entorno dev
   → Los outputs se comentan en el commit
```

### Promoción a producción (develop → main)

```
5. Abrir PR desde develop hacia main
   → check-pr-source.yml valida que la rama origen sea develop (bloquea cualquier otra)
   → terraform-plan.yml corre el plan para prod

6. Revisar plan de prod y mergear
   → terraform-apply.yml aplica en prod
   → El environment 'prod' en GitHub puede tener reviewers requeridos como protección adicional
```

### Diagrama del flujo completo

```
feature/x ──PR──► develop ──merge──► [terraform apply DEV]
                     │
                    PR
                     │
                     ▼
                   main ──merge──► [terraform apply PROD]
```

**Reglas de protección de ramas:**
- `main` — solo acepta PRs desde `develop`, sin push directo
- `develop` — requiere PR, sin push directo

---

## Workflows de GitHub Actions

### `terraform-plan.yml`
**Trigger:** Pull request hacia `develop` o `main` con cambios en `infrastructure/`

1. Detecta el entorno destino (`develop` → `dev`, `main` → `prod`)
2. Autentica con AWS via OIDC
3. `terraform fmt -check` — valida formato
4. `terraform init` con backend S3
5. `terraform validate`
6. `terraform plan` — genera el plan
7. Comenta el plan completo en el PR

### `terraform-apply.yml`
**Trigger:** Push a `develop` o `main` con cambios en `infrastructure/`

1. Detecta el entorno según la rama
2. Autentica con AWS via OIDC
3. `terraform init` con backend S3
4. `terraform plan -out=tfplan`
5. `terraform apply tfplan` — aplica los cambios
6. Comenta los outputs en el commit

**Nota importante:** Este workflow solo se activa con cambios en `infrastructure/environments/**` o `infrastructure/modules/**`. Los cambios en `infrastructure/iam-oidc/` requieren aplicación manual (ver [bootstrap](#configuración-inicial-bootstrap)).

### `drift-detection-remediation.yml`
**Trigger:** Schedule cada 6 horas + manual via `workflow_dispatch`

1. Corre `terraform plan -detailed-exitcode` en cada entorno
2. Si hay drift (exit code 2): genera reporte JSON, lo sube a S3, abre un Issue en GitHub
3. Si `AUTO_REMEDIATE=true`: aplica `terraform apply` automáticamente y actualiza el reporte

### `check-pr-source.yml`
**Trigger:** Pull request hacia `main`

Valida que la rama origen sea `develop`. Si no, el PR queda bloqueado.

---

## Configuración inicial (bootstrap)

Estos pasos se hacen **una sola vez** al crear el proyecto. Ya están aplicados en parking-app.

### Prerequisitos

```bash
brew install gh terraform
gh auth login
aws configure  # o exportar AWS_PROFILE
```

### Paso 1 — Aplicar OIDC y roles IAM

```bash
cd parking-app-infra
bash scripts/init-iam-oidc.sh
```

Este script:
- Inicializa Terraform en `infrastructure/iam-oidc/`
- Importa el OIDC provider si ya existe en la cuenta (para no duplicarlo)
- Crea los dos roles IAM (`github-actions-parking-app` y `github-actions-parking-app-backend`)
- Muestra los ARNs de salida

### Paso 2 — Configurar GitHub

```bash
bash scripts/setup-github.sh
```

Este script configura en el repo de GitHub:
- **Variables:** `PROJECT_NAME`, `AWS_REGION`, `TF_STATE_BUCKET`, `DRIFT_DETECTION_SCHEDULE`, `AUTO_REMEDIATE`
- **Secret:** `AWS_ROLE_ARN` (ARN del rol de infra)
- **Environments:** `dev` y `prod`
- **Protección de ramas:** `main` y `develop`

### Paso 3 — Configurar parking-app-backend

```bash
cd ../parking-app-backend
gh secret set AWS_ROLE_ARN --body "arn:aws:iam::ACCOUNT_ID:role/github-actions-parking-app-backend"
gh variable set PROJECT_NAME --body "parking-app"
gh variable set AWS_REGION --body "us-east-1"
```

### Estado actual del backend S3

El estado de Terraform se guarda en:

| Módulo | S3 Key |
|--------|--------|
| iam-oidc | `parking-app/iam-oidc/terraform.tfstate` |
| dev | `parking-app/dev/terraform.tfstate` |
| prod (futuro) | `parking-app/prod/terraform.tfstate` |

**Bucket:** `control-plane-terraform-states-970547363172` (cuenta `970547363172`, región `us-east-1`)

---

## Agregar un nuevo entorno

1. Copiar `infrastructure/environments/dev/` a `infrastructure/environments/prod/`
2. Ajustar variables (nombre de entorno, tamaños, configuraciones de prod)
3. El workflow detecta el directorio automáticamente al hacer PR a `main`

---

## Agregar un nuevo módulo o recurso

1. Si es un recurso reutilizable: crear módulo en `infrastructure/modules/mi-modulo/`
2. Llamar al módulo desde `infrastructure/environments/dev/mi-recurso.tf`
3. Abrir PR a `develop` → el plan mostrará los recursos nuevos antes de aplicar

Convención de nombres de recursos AWS:
```
{environment}-{project_name}-{recurso}
Ejemplo: dev-parking-app-auth-handler
```

---

## Detección de drift

El drift ocurre cuando alguien modifica recursos en AWS directamente (fuera de Terraform). El workflow de drift detection corre cada 6 horas y:

- **Sin drift:** registra `✅ No drift detected` en el summary
- **Con drift y `AUTO_REMEDIATE=true`:** aplica terraform automáticamente y abre un Issue
- **Con drift y `AUTO_REMEDIATE=false`:** solo genera reporte y abre un Issue

Los reportes se guardan en S3:
```
s3://control-plane-terraform-states-970547363172/parking-app/{env}/drift-reports/{fecha}/drift-{hora}.json
```

Para disparar manualmente desde GitHub Actions:
> Actions → Drift Detection & Auto-Remediation → Run workflow

---

## Variables y secrets requeridos

### `parking-app-infra` (este repo)

| Nombre | Tipo | Valor | Descripción |
|--------|------|-------|-------------|
| `PROJECT_NAME` | Variable | `parking-app` | Prefijo de recursos y clave de estado |
| `AWS_REGION` | Variable | `us-east-1` | Región AWS |
| `TF_STATE_BUCKET` | Variable | `control-plane-terraform-states-970547363172` | Bucket del estado Terraform |
| `DRIFT_DETECTION_SCHEDULE` | Variable | `0 */6 * * *` | Referencial (el cron está hardcodeado en el workflow) |
| `AUTO_REMEDIATE` | Variable | `false` | Auto-aplicar en caso de drift |
| `AWS_ROLE_ARN` | Secret | `arn:aws:iam::970547363172:role/github-actions-parking-app` | Rol OIDC para Terraform |

### `parking-app-backend`

| Nombre | Tipo | Valor | Descripción |
|--------|------|-------|-------------|
| `PROJECT_NAME` | Variable | `parking-app` | Prefijo de funciones Lambda |
| `AWS_REGION` | Variable | `us-east-1` | Región AWS |
| `AWS_ROLE_ARN` | Secret | `arn:aws:iam::970547363172:role/github-actions-parking-app-backend` | Rol OIDC para deploy de Lambdas |
