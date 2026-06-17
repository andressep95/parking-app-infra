# ============================================
# Auth Handler Lambda (login, register)
# ============================================

module "auth_handler" {
  source = "../../modules/lambda"

  function_name = "${var.environment}-${var.project_name}-auth-handler"
  role_arn      = aws_iam_role.auth_handler.arn
  handler       = "bootstrap"
  runtime       = "provided.al2023"
  architecture  = "arm64"

  memory_size = 256
  timeout     = 30

  environment_variables = {
    COGNITO_USER_POOL_ID = module.cognito.user_pool_id
    COGNITO_CLIENT_ID    = module.cognito.client_id
    DYNAMODB_TABLE_NAME  = module.main_table.table_name
  }

  log_retention_days = 30
  create_log_group   = true

  environment = var.environment
  tags = merge(local.common_tags, {
    Component = "auth-handler"
  })
}

# ─── IAM Role ─────────────────────────────────────────────────────────────────

resource "aws_iam_role" "auth_handler" {
  name = "${var.project_name}-${var.environment}-auth-handler-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "auth_handler_logs" {
  role       = aws_iam_role.auth_handler.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "auth_handler_cognito" {
  name = "${var.environment}-${var.project_name}-auth-handler-cognito"
  role = aws_iam_role.auth_handler.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "cognito-idp:InitiateAuth",
        "cognito-idp:AdminCreateUser",
        "cognito-idp:AdminSetUserPassword",
        "cognito-idp:AdminAddUserToGroup",
        "cognito-idp:AdminGetUser",
      ]
      Resource = module.cognito.user_pool_arn
    }]
  })
}

resource "aws_iam_role_policy" "auth_handler_dynamodb" {
  name = "${var.environment}-${var.project_name}-auth-handler-dynamodb"
  role = aws_iam_role.auth_handler.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "dynamodb:PutItem",
        "dynamodb:GetItem",
        "dynamodb:Query",
      ]
      Resource = [
        module.main_table.table_arn,
        "${module.main_table.table_arn}/index/*",
      ]
    }]
  })
}
