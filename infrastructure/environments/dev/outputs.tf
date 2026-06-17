output "api_endpoint" {
  description = "URL base del API Gateway"
  value       = module.api_gateway.api_endpoint
}

output "cognito_user_pool_id" {
  description = "ID del Cognito User Pool"
  value       = module.cognito.user_pool_id
}

output "cognito_client_id" {
  description = "ID del Cognito App Client"
  value       = module.cognito.client_id
}

output "cognito_issuer_url" {
  description = "Issuer URL para validación JWT"
  value       = module.cognito.issuer_url
}

output "auth_lambda_name" {
  description = "Nombre de la Lambda de auth"
  value       = module.auth_handler.function_name
}

output "user_handler_lambda_name" {
  description = "Nombre de la Lambda de gestión de usuarios"
  value       = module.user_handler.function_name
}

output "dynamodb_table_name" {
  description = "Nombre de la tabla DynamoDB principal"
  value       = module.main_table.table_name
}

output "dynamodb_table_arn" {
  description = "ARN de la tabla DynamoDB principal"
  value       = module.main_table.table_arn
}

output "cognito_group_admin" {
  description = "Nombre del grupo Cognito ADMIN"
  value       = module.cognito.group_admin
}

output "cognito_group_customer" {
  description = "Nombre del grupo Cognito CUSTOMER"
  value       = module.cognito.group_customer
}

output "cognito_group_customer_operator" {
  description = "Nombre del grupo Cognito CUSTOMER_OPERATOR"
  value       = module.cognito.group_customer_operator
}
