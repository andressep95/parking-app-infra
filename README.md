# parking-app-infra

Repositorio de infraestructura GitOps para **parking-app**. Toda modificación de infraestructura pasa por Pull Request — nunca directamente en AWS.

> **Stack actual:** CloudFormation · GitHub Actions OIDC · Cognito como IdP

---

## Tabla de contenidos

- [Arquitectura general](#arquitectura-general)
- [Estructura del repositorio](#estructura-del-repositorio)
- [Roles IAM y autenticación OIDC](#roles-iam-y-autenticación-oidc)
- [Flujo GitOps paso a paso](#flujo-gitops-paso-a-paso)
- [Workflows de GitHub Actions](#workflows-de-github-actions)
- [Configuración inicial (bootstrap)](#configuración-inicial-bootstrap)
- [Cognito — decisiones de arquitectura](#cognito--decisiones-de-arquitectura)
- [Variables y secrets requeridos](#variables-y-secrets-requeridos)
- [Pendientes](#pendientes)

---

## Arquitectura general

```
parking-app-infra (este repo)           parking-app-backend
        │                                       │
        │  PR → cfn-validate (changeset)        │  push a develop/main
        │  merge → cfn-deploy                   │  → build + deploy
        ▼                                       ▼
  GitHub Actions ──OIDC──► AWS IAM       GitHub Actions ──OIDC──► AWS IAM
  role: github-actions-parking-app       role: github-actions-parking-app-backend
        │                                       │
        ▼                                       ▼
  CloudFormation stacks               aws lambda update-function-code
  parking-app-{env}-cognito                (o equivalente según stack)


  Spring Boot (VPS Contabo)
        │
        │  POST /auth/login
        │  → valida terminal en PostgreSQL
        │  → AdminInitiateAuth (AWS SDK + IAM user)
        ▼
  Cognito User Pool
        │
        ▼
  JWT access token (1h) + refresh token (30d)
```

La autenticación de GitHub Actions con AWS es **sin credenciales estáticas**: se obtiene un token OIDC temporal que AWS valida directamente contra el proveedor registrado. No hay `AWS_ACCESS_KEY_ID` ni `AWS_SECRET_ACCESS_KEY` en los workflows.

---

## Estructura del repositorio

```
parking-app-infra/
├── .github/
│   └── workflows/
│       ├── cfn-validate.yml          # PR → crea changeset y comenta el diff
│       ├── cfn-deploy.yml            # merge → aws cloudformation deploy
│       ├── cfn-drift-detection.yml   # cada 6h → detecta drift, abre Issue si hay
│       └── check-pr-source.yml       # bloquea PRs a main que no vengan de develop
│
├── infrastructure/
│   └── cloudformation/
│       ├── github-oidc.yaml          # Bootstrap: OIDC provider + roles IAM (deploy manual)
│       └── cognito.yaml              # Cognito User Pool + App Client + Grupos
│
└── scripts/
    └── setup-github.sh               # Configura variables/secrets/environments en GitHub
```

---

## Roles IAM y autenticación OIDC

El bootstrap (`github-oidc.yaml`) crea dos roles IAM y el OIDC provider. Stack: `parking-app-github-oidc`.

### `github-actions-parking-app`
- **Usado por:** `parking-app-infra` (este repo)
- **Propósito:** Ejecutar cfn-validate y cfn-deploy
- **Permisos:** Acceso amplio a servicios AWS (CloudFormation, Cognito, Lambda, S3, etc.)
- **Restricción IAM:** Solo puede crear/modificar roles con prefijo `parking-app-*`
- **Trust policy:** `repo:andressep95/parking-app-infra:*`

### `github-actions-parking-app-backend`
- **Usado por:** `parking-app-backend`
- **Propósito:** Desplegar Lambdas u otros recursos del backend
- **Permisos mínimos:** `lambda:UpdateFunctionCode`, `lambda:GetFunction`, `lambda:GetFunctionConfiguration`
- **Scope:** Solo funciones con patrón `*-parking-app-*`
- **Trust policy:** `repo:andressep95/parking-app-backend:*`

### Cómo funciona el OIDC

```
GitHub Actions Runner
       │  1. Solicita token OIDC a GitHub
       ▼
GitHub Token Service
       │  2. Emite JWT firmado:
       │     sub: repo:andressep95/parking-app-infra:ref:refs/heads/develop
       │     aud: sts.amazonaws.com
       ▼
AWS STS (AssumeRoleWithWebIdentity)
       │  3. Valida JWT, verifica sub contra trust policy del rol
       ▼
  Credenciales temporales (~1h)
       ▼
  AWS API calls (CloudFormation / Lambda deploy)
```

---

## Flujo GitOps paso a paso

### Desarrollo normal (feature → develop)

```
1. Crear rama desde develop
   git checkout develop && git pull
   git checkout -b feat/mi-cambio

2. Modificar templates en infrastructure/cloudformation/

3. Abrir PR hacia develop
   → cfn-validate crea un changeset y comenta el diff en el PR:
     🟢 Add | 🟡 Modify | 🔴 Remove  —  recurso  —  ¿requiere reemplazo?
   → Revisar el changeset antes de mergear

4. Mergear PR a develop
   → cfn-deploy ejecuta aws cloudformation deploy en el entorno dev
   → Los outputs del stack se publican en el Step Summary del workflow
```

### Promoción a producción (develop → main)

```
5. Abrir PR desde develop hacia main
   → check-pr-source.yml valida que el origen sea develop (bloquea cualquier otra)
   → cfn-validate comenta el changeset para prod

6. Revisar changeset de prod y mergear
   → cfn-deploy aplica en prod
   → El environment 'prod' en GitHub puede tener reviewers requeridos
```

### Diagrama del flujo completo

```
feature/x ──PR──► develop ──merge──► [cfn-deploy DEV]
                     │
                    PR
                     │
                     ▼
                   main ──merge──► [cfn-deploy PROD]
```

**Reglas de protección de ramas:**
- `main` — solo acepta PRs desde `develop`, sin push directo
- `develop` — requiere PR, sin push directo

---

## Workflows de GitHub Actions

### `cfn-validate.yml`
**Trigger:** Pull request hacia `develop` o `main` con cambios en `infrastructure/cloudformation/`

1. Detecta el entorno destino (`develop` → `dev`, `main` → `prod`)
2. Autentica con AWS via OIDC
3. Crea un changeset (`CREATE` si el stack no existe, `UPDATE` si ya existe)
4. Espera hasta que el changeset esté listo (poll manual — `aws wait` falla en FAILED state)
5. Comenta el diff en el PR con tabla: Acción | Recurso | Tipo | ¿Reemplazo?
6. Elimina el changeset al finalizar (`if: always()`)

### `cfn-deploy.yml`
**Trigger:** Push a `develop` o `main` con cambios en `infrastructure/cloudformation/`

1. Detecta el entorno según la rama
2. Autentica con AWS via OIDC
3. `aws cloudformation deploy --no-fail-on-empty-changeset`
4. Obtiene los outputs del stack y los publica en el Step Summary

### `cfn-drift-detection.yml`
**Trigger:** Schedule cada 6 horas + manual via `workflow_dispatch`

1. Verifica que el stack exista (omite si no está desplegado aún)
2. Lanza drift detection y espera el resultado
3. Si hay drift: abre un Issue en GitHub con los recursos afectados y las diferencias de propiedades
4. **No auto-remedia:** CloudFormation no puede corregir drift re-desplegando el mismo template.
   La remediación es manual: revertir en consola o actualizar el template.

### `check-pr-source.yml`
**Trigger:** Pull request hacia `main`

Valida que la rama origen sea `develop`. Si no, el PR queda bloqueado.

---

## Configuración inicial (bootstrap)

Estos pasos se hacen **una sola vez** al crear el proyecto en una cuenta AWS nueva.

### Prerequisitos

```bash
brew install gh awscli
gh auth login
# Tener credenciales AWS temporales disponibles para el deploy manual
```

### Paso 1 — Desplegar el bootstrap IAM (una vez, manual)

```bash
aws cloudformation deploy \
  --template-file infrastructure/cloudformation/github-oidc.yaml \
  --stack-name parking-app-github-oidc \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1
```

Esto crea el OIDC provider y los dos roles IAM. Sin este stack, los workflows de GitHub Actions no pueden autenticar con AWS.

### Paso 2 — Configurar GitHub

```bash
bash scripts/setup-github.sh
```

Configura en el repo:
- **Variables:** `PROJECT_NAME`, `AWS_REGION`
- **Secret:** `AWS_ROLE_ARN`
- **Environments:** `dev` (y `prod` si aplica)
- **Protección de ramas:** `main` y `develop`

### Paso 3 — Primer despliegue de Cognito

```bash
git checkout -b feat/initial-cognito
# (sin cambios necesarios — solo para trigger el workflow)
git push origin feat/initial-cognito
# Abrir PR a develop → cfn-validate comenta el changeset → mergear → cfn-deploy crea el stack
```

---

## Cognito — decisiones de arquitectura

### Flujo de autenticación

El backend (Spring Boot en VPS) **intercepta todos los logins** para validar que el usuario opera desde una terminal autorizada antes de autenticar contra Cognito:

```
Terminal/App → POST /auth/login → Spring Boot
                                   ├─ ¿terminal en PostgreSQL? ─► 401 si no
                                   └─ AdminInitiateAuth (SDK + IAM)
                                              │
                                              ▼
                                         Cognito
                                              │
                                              ▼
                                   access token + refresh token
                                              │
                                   ◄──────────┘
```

Por este motivo el app client tiene `ALLOW_ADMIN_USER_PASSWORD_AUTH` y **no** `ALLOW_USER_SRP_AUTH` — este último permitiría al cliente ir directo a Cognito saltándose la validación de terminal.

### Grupos RBAC

| Grupo | Precedencia | Descripción |
|-------|------------|-------------|
| `ADMIN` | 0 | Equipo interno — acceso total |
| `CUSTOMER` | 10 | Empresa cliente — gestiona sus locations y operadores |
| `OPERATOR` | 20 | Cajero — opera el terminal en una location asignada |

Spring Boot lee el claim `cognito:groups` del JWT y lo convierte en roles de Spring Security via `JwtGrantedAuthoritiesConverter`.

### Usuarios

Solo admins crean usuarios (`AdminCreateUserOnly: true`). No hay autoregistro. La contraseña temporal expira en 3 días.

### Tokens

| Token | Validez | Notas |
|-------|---------|-------|
| Access token | 1 hora | Valida cada request HTTP en Spring Boot |
| ID token | 1 hora | Mismo lifetime que access token |
| Refresh token | 30 días | Para terminales TUU con uso diario continuo |

---

## Variables y secrets requeridos

### `parking-app-infra` (este repo)

| Nombre | Tipo | Valor | Descripción |
|--------|------|-------|-------------|
| `PROJECT_NAME` | Variable | `parking-app` | Prefijo para nombres de stacks |
| `AWS_REGION` | Variable | `us-east-1` | Región AWS |
| `AWS_ROLE_ARN` | Secret | `arn:aws:iam::970547363172:role/github-actions-parking-app` | Rol OIDC para cfn-deploy |

### `parking-app-backend`

| Nombre | Tipo | Valor | Descripción |
|--------|------|-------|-------------|
| `PROJECT_NAME` | Variable | `parking-app` | Prefijo de recursos |
| `AWS_REGION` | Variable | `us-east-1` | Región AWS |
| `AWS_ROLE_ARN` | Secret | `arn:aws:iam::970547363172:role/github-actions-parking-app-backend` | Rol OIDC para deploy |

---

## Pendientes

- [ ] **IAM user para VPS (runtime):** Crear IAM user con permisos mínimos para que Spring Boot pueda llamar `AdminInitiateAuth` desde el VPS Contabo. Scope: `cognito-idp:AdminInitiateAuth` + `cognito-idp:AdminUserGlobalSignOut` sobre el ARN del User Pool del entorno correspondiente.
- [ ] **Variables de entorno Spring Boot:** Una vez desplegado el stack Cognito, configurar en el VPS:
  - `COGNITO_USER_POOL_ID` → output `UserPoolId` del stack `parking-app-dev-cognito`
  - `COGNITO_CLIENT_ID` → output `ClientId`
  - `SPRING_SECURITY_OAUTH2_RESOURCESERVER_JWT_ISSUER_URI` → output `IssuerUrl`
  - `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` del IAM user de runtime
