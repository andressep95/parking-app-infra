output "api_id" {
  value = local.is_rest_v1 ? module.rest_v1[0].api_id : module.http_v2[0].api_id
}

output "api_endpoint" {
  value = local.is_rest_v1 ? module.rest_v1[0].invoke_url : module.http_v2[0].api_endpoint
}

output "execution_arn" {
  value = local.is_http_v2 ? module.http_v2[0].execution_arn : null
}
