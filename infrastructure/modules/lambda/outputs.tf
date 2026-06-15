# ============================================
# Lambda Module - Outputs
# ============================================

output "function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.this.function_name
}

output "function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.this.arn
}

output "invoke_arn" {
  description = "Invoke ARN of the Lambda function"
  value       = aws_lambda_function.this.invoke_arn
}

output "runtime" {
  description = "Runtime of the Lambda function"
  value       = aws_lambda_function.this.runtime
}

output "memory_size" {
  description = "Memory size of the Lambda function"
  value       = aws_lambda_function.this.memory_size
}

output "environment_variables" {
  description = "Environment variables of the Lambda function"
  value = (
    length(aws_lambda_function.this.environment) > 0
    ? aws_lambda_function.this.environment[0].variables
    : {}
  )
}


output "architecture" {
  description = "Architecture of the Lambda function"
  value       = aws_lambda_function.this.architectures
}

output "qualified_arn" {
  description = "Qualified ARN of the Lambda function"
  value       = aws_lambda_function.this.qualified_arn
}

output "version" {
  description = "Latest published version of the Lambda function"
  value       = aws_lambda_function.this.version
}

output "log_group_name" {
  description = "Name of the CloudWatch Log Group"
  value       = length(aws_cloudwatch_log_group.lambda_log_group) > 0 ? aws_cloudwatch_log_group.lambda_log_group[0].name : null
}

output "log_group_arn" {
  description = "ARN of the CloudWatch Log Group"
  value       = length(aws_cloudwatch_log_group.lambda_log_group) > 0 ? aws_cloudwatch_log_group.lambda_log_group[0].arn : null
}
