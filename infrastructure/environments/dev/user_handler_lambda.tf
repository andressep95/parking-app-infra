# ============================================
# User Handler Lambda (CRUD de usuarios)
# ============================================

module "user_handler" {
  source = "../../modules/lambda"

  function_name = "${var.environment}-${var.project_name}-user-handler"
  role_arn      = aws_iam_role.user_handler.arn
  handler       = "bootstrap"
  runtime       = "provided.al2023"
  architecture  = "arm64"

  memory_size = 256
  timeout     = 30

  environment_variables = {
    COGNITO_USER_POOL_ID = module.cognito.user_pool_id
    DYNAMODB_TABLE_NAME  = module.main_table.table_name
  }

  log_retention_days = 30
  create_log_group   = true

  environment = var.environment
  tags = merge(local.common_tags, {
    Component = "user-handler"
  })
}

# ─── IAM Role ─────────────────────────────────────────────────────────────────

resource "aws_iam_role" "user_handler" {
  name = "${var.project_name}-${var.environment}-user-handler-role"

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

resource "aws_iam_role_policy_attachment" "user_handler_logs" {
  role       = aws_iam_role.user_handler.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# ─── Permisos Cognito ─────────────────────────────────────────────────────────

resource "aws_iam_role_policy" "user_handler_cognito" {
  name = "${var.environment}-${var.project_name}-user-handler-cognito"
  role = aws_iam_role.user_handler.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "cognito-idp:AdminGetUser",
        "cognito-idp:AdminUpdateUserAttributes",
        "cognito-idp:AdminDisableUser",
        "cognito-idp:AdminEnableUser",
        "cognito-idp:AdminSetUserPassword",
        "cognito-idp:AdminDeleteUser",
        "cognito-idp:AdminAddUserToGroup",
        "cognito-idp:AdminRemoveUserFromGroup",
        "cognito-idp:AdminListGroupsForUser",
        "cognito-idp:ListUsers",
        "cognito-idp:ListUsersInGroup",
      ]
      Resource = module.cognito.user_pool_arn
    }]
  })
}

# ─── Permisos DynamoDB ────────────────────────────────────────────────────────

resource "aws_iam_role_policy" "user_handler_dynamodb" {
  name = "${var.environment}-${var.project_name}-user-handler-dynamodb"
  role = aws_iam_role.user_handler.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem",
        "dynamodb:Query",
        "dynamodb:TransactWriteItems",
      ]
      Resource = [
        module.main_table.table_arn,
        "${module.main_table.table_arn}/index/*",
      ]
    }]
  })
}
