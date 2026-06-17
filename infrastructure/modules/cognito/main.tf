# ============================================
# Cognito User Pool
# ============================================

resource "aws_cognito_user_pool" "this" {
  name                     = var.user_pool_name
  deletion_protection      = var.deletion_protection ? "ACTIVE" : "INACTIVE"
  auto_verified_attributes = var.auto_verified_attributes
  username_attributes      = var.username_attributes
  mfa_configuration        = var.mfa_configuration

  password_policy {
    minimum_length    = var.password_minimum_length
    require_lowercase = true
    require_numbers   = true
    require_symbols   = false
    require_uppercase = true
  }

  schema {
    name                = "role"
    attribute_data_type = "String"
    mutable             = true

    string_attribute_constraints {
      min_length = 1
      max_length = 50
    }
  }

  dynamic "schema" {
    for_each = var.required_attributes
    content {
      name                     = schema.value
      attribute_data_type      = "String"
      required                 = true
      mutable                  = true
      developer_only_attribute = false

      string_attribute_constraints {
        min_length = 1
        max_length = 256
      }
    }
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }

  tags = var.tags
}

# ============================================
# Cognito User Pool Client (SPA - no secret)
# ============================================

resource "aws_cognito_user_pool_client" "this" {
  name         = var.client_name
  user_pool_id = aws_cognito_user_pool.this.id

  generate_secret = false

  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_ADMIN_USER_PASSWORD_AUTH",
  ]

  supported_identity_providers = ["COGNITO"]

  access_token_validity  = var.access_token_validity_hours
  id_token_validity      = var.access_token_validity_hours
  refresh_token_validity = var.refresh_token_validity_days

  token_validity_units {
    access_token  = "hours"
    id_token      = "hours"
    refresh_token = "days"
  }

  # ==========================================
  # Attribute permissions (app client level)
  # Users can READ role (for UI),
  # but CANNOT WRITE it. Only admins can
  # change it via AdminUpdateUserAttributes.
  # Multi-tenancy is handled via Cognito Groups.
  # ==========================================
  read_attributes  = var.read_attributes
  write_attributes = var.write_attributes

  callback_urls = var.callback_urls
  logout_urls   = var.logout_urls

  allowed_oauth_flows_user_pool_client = length(var.callback_urls) > 0
  allowed_oauth_flows                  = length(var.callback_urls) > 0 ? ["code"] : []
  allowed_oauth_scopes                 = length(var.callback_urls) > 0 ? ["openid", "email", "profile"] : []

  prevent_user_existence_errors = "ENABLED"
}

# ============================================
# Grupos de roles (precedence menor = mayor prioridad en el token)
# ============================================

resource "aws_cognito_user_group" "admin" {
  name         = "ADMIN"
  user_pool_id = aws_cognito_user_pool.this.id
  description  = "Equipo Haulmer — acceso total a todos los customers y locations"
  precedence   = 0
}

resource "aws_cognito_user_group" "customer" {
  name         = "CUSTOMER"
  user_pool_id = aws_cognito_user_pool.this.id
  description  = "Empresa cliente — gestiona sus propias locations y operadores"
  precedence   = 10
}

resource "aws_cognito_user_group" "customer_operator" {
  name         = "CUSTOMER_OPERATOR"
  user_pool_id = aws_cognito_user_pool.this.id
  description  = "Cajero/operador — opera el terminal en una location asignada"
  precedence   = 20
}

resource "aws_cognito_user_group" "public" {
  name         = "Public"
  user_pool_id = aws_cognito_user_pool.this.id
  description  = "Grupo por defecto para usuarios sin rol asignado"
  precedence   = 100
}
