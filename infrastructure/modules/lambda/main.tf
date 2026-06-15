# ============================================
# Lambda Module - Template
# ============================================

# Placeholder ZIP incluido en el módulo — el backend repo reemplaza el código via update-function-code
locals {
  effective_file = var.filename != null ? var.filename : "${path.module}/placeholder.zip"
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "lambda_log_group" {
  count = var.create_log_group ? 1 : 0

  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.log_kms_key_id

  tags = var.tags
}

# Lambda Function
resource "aws_lambda_function" "this" {
  function_name    = var.function_name
  filename         = local.effective_file
  source_code_hash = var.source_code_hash != null ? var.source_code_hash : filebase64sha256(local.effective_file)
  role             = var.role_arn
  handler          = var.handler
  runtime          = var.runtime
  timeout          = var.timeout
  memory_size      = var.memory_size

  architectures                  = [var.architecture]
  reserved_concurrent_executions = var.reserved_concurrent_executions

  dynamic "environment" {
    for_each = length(var.environment_variables) > 0 ? [1] : []
    content {
      variables = var.environment_variables
    }
  }

  tracing_config {
    mode = var.xray_tracing_enabled ? "Active" : "PassThrough"
  }

  dynamic "dead_letter_config" {
    for_each = var.dlq_arn != null ? [1] : []
    content {
      target_arn = var.dlq_arn
    }
  }

  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }

  layers = length(var.layer_arns) > 0 ? var.layer_arns : null

  # El backend repo actualiza el código — Terraform no lo toca después del primer deploy
  lifecycle {
    ignore_changes = [filename, source_code_hash]
  }

  tags = var.tags
}

# Error Rate Alarm
resource "aws_cloudwatch_metric_alarm" "high_errors" {
  count = var.create_error_alarm ? 1 : 0

  alarm_name          = "${var.function_name}-high-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.error_evaluation_periods
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = var.error_period
  statistic           = "Sum"
  threshold           = var.error_threshold
  alarm_description   = "Lambda error rate exceeded threshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.this.function_name
  }

  alarm_actions = var.alarm_sns_topic_arns

  tags = var.tags
}

# Duration Alarm
resource "aws_cloudwatch_metric_alarm" "high_duration" {
  count = var.create_duration_alarm ? 1 : 0

  alarm_name          = "${var.function_name}-high-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.duration_evaluation_periods
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = var.duration_period
  statistic           = "Average"
  threshold           = var.duration_threshold
  alarm_description   = "Lambda duration exceeded threshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.this.function_name
  }

  alarm_actions = var.alarm_sns_topic_arns

  tags = var.tags
}

# Lambda Permission for API Gateway
resource "aws_lambda_permission" "api_gateway" {
  count = var.create_api_gateway_permission && var.api_gateway_source_arn != "" ? 1 : 0

  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = var.api_gateway_source_arn
}
