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
