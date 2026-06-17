module "api_gateway" {
  source = "../../modules/gateway/wrapper"

  gateway_type = "http-v2"
  name         = "${var.environment}-${var.project_name}-api"
  region       = var.aws_region
  stage_name   = "$default"

  lambda_name       = module.auth_handler.function_name
  lambda_invoke_arn = module.auth_handler.invoke_arn

  routes = {
    # ── auth-handler (público) ────────────────────────────────────────────────
    "POST /api/v1/auth/login"    = { public = true }
    "POST /api/v1/auth/register" = { public = true }

    # ── user-handler (JWT requerido) ──────────────────────────────────────────
    "GET /api/v1/users" = {
      lambda_invoke_arn = module.user_handler.invoke_arn
      lambda_name       = module.user_handler.function_name
    }
    "GET /api/v1/users/{id}" = {
      lambda_invoke_arn = module.user_handler.invoke_arn
      lambda_name       = module.user_handler.function_name
    }
    "PUT /api/v1/users/{id}" = {
      lambda_invoke_arn = module.user_handler.invoke_arn
      lambda_name       = module.user_handler.function_name
    }
    "POST /api/v1/users/{id}/activate" = {
      lambda_invoke_arn = module.user_handler.invoke_arn
      lambda_name       = module.user_handler.function_name
    }
    "POST /api/v1/users/{id}/deactivate" = {
      lambda_invoke_arn = module.user_handler.invoke_arn
      lambda_name       = module.user_handler.function_name
    }
    "POST /api/v1/users/{id}/reset-password" = {
      lambda_invoke_arn = module.user_handler.invoke_arn
      lambda_name       = module.user_handler.function_name
    }
    "DELETE /api/v1/users/{id}" = {
      lambda_invoke_arn = module.user_handler.invoke_arn
      lambda_name       = module.user_handler.function_name
    }
  }

  throttling_burst_limit = 50
  throttling_rate_limit  = 25

  enable_access_logging     = true
  access_log_retention_days = 14

  jwt_issuer   = module.cognito.issuer_url
  jwt_audience = [module.cognito.client_id]

  tags = local.common_tags
}
