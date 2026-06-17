output "user_pool_id" {
  description = "ID of the Cognito User Pool"
  value       = aws_cognito_user_pool.this.id
}

output "user_pool_arn" {
  description = "ARN of the Cognito User Pool"
  value       = aws_cognito_user_pool.this.arn
}

output "user_pool_endpoint" {
  description = "Endpoint of the Cognito User Pool"
  value       = aws_cognito_user_pool.this.endpoint
}

output "client_id" {
  description = "ID of the Cognito User Pool Client"
  value       = aws_cognito_user_pool_client.this.id
}

output "issuer_url" {
  description = "Issuer URL for JWT validation"
  value       = "https://${aws_cognito_user_pool.this.endpoint}"
}

output "group_admin" {
  description = "Nombre del grupo ADMIN"
  value       = aws_cognito_user_group.admin.name
}

output "group_customer" {
  description = "Nombre del grupo CUSTOMER"
  value       = aws_cognito_user_group.customer.name
}

output "group_customer_operator" {
  description = "Nombre del grupo CUSTOMER_OPERATOR"
  value       = aws_cognito_user_group.customer_operator.name
}

output "public_group_name" {
  description = "Nombre del grupo público por defecto"
  value       = aws_cognito_user_group.public.name
}
