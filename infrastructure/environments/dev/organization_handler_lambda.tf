# ============================================
# Organization Handler Lambda (CRUD de organizaciones)
# ============================================

module "organization_handler" {
  source = "../../modules/lambda"

  function_name = "${var.environment}-${var.project_name}-organization-handler"
  role_arn      = aws_iam_role.organization_handler.arn
  handler       = "bootstrap"
  runtime       = "provided.al2023"
  architecture  = "arm64"

  memory_size = 256
  timeout     = 30

  environment_variables = {
    DYNAMODB_TABLE_NAME = module.main_table.table_name
  }

  log_retention_days = 30
  create_log_group   = true

  environment = var.environment
  tags = merge(local.common_tags, {
    Component = "organization-handler"
  })
}

# ─── IAM Role ─────────────────────────────────────────────────────────────────

resource "aws_iam_role" "organization_handler" {
  name = "${var.project_name}-${var.environment}-organization-handler-role"

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

resource "aws_iam_role_policy_attachment" "organization_handler_logs" {
  role       = aws_iam_role.organization_handler.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# ─── Permisos DynamoDB ────────────────────────────────────────────────────────

resource "aws_iam_role_policy" "organization_handler_dynamodb" {
  name = "${var.environment}-${var.project_name}-organization-handler-dynamodb"
  role = aws_iam_role.organization_handler.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "dynamodb:GetItem",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem",
        "dynamodb:Query",
        "dynamodb:Scan",
        "dynamodb:TransactWriteItems",
      ]
      Resource = [
        module.main_table.table_arn,
        "${module.main_table.table_arn}/index/*",
      ]
    }]
  })
}
