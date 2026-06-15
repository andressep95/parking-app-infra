locals {
  is_rest_v1 = var.gateway_type == "rest-v1"
  is_http_v2 = var.gateway_type == "http-v2"
}

############################
# REST API Gateway v1
############################
module "rest_v1" {
  count  = local.is_rest_v1 ? 1 : 0
  source = "../rest-v1"

  name       = var.name
  region     = var.region
  stage_name = var.stage_name

  lambda_name = var.lambda_name
  lambda_arn  = var.lambda_arn

  routes = var.routes
}

############################
# HTTP API Gateway v2
############################
module "http_v2" {
  count  = local.is_http_v2 ? 1 : 0
  source = "../http-v2"

  name       = var.name
  stage_name = var.stage_name

  lambda_name       = var.lambda_name
  lambda_invoke_arn = var.lambda_invoke_arn

  routes = var.routes
  tags   = var.tags

  # Throttling configuration
  throttling_burst_limit = var.throttling_burst_limit
  throttling_rate_limit  = var.throttling_rate_limit

  # Access logging configuration
  enable_access_logging     = var.enable_access_logging
  access_log_retention_days = var.access_log_retention_days

  # JWT authorizer configuration
  jwt_issuer   = var.jwt_issuer
  jwt_audience = var.jwt_audience
}
