# ============================================
# Locals - Parse routes into method + path
# ============================================
locals {
  # Parse routes like "GET /" into {method: "GET", path: "/"}
  parsed_routes = {
    for route_key, route_config in var.routes : route_key => {
      method = split(" ", route_key)[0]
      path   = split(" ", route_key)[1]
    }
  }

  # Extract all unique path segments
  # For "/api/convert" we need both "/api" and "/api/convert"
  all_path_segments = flatten([
    for route_key, route in local.parsed_routes : [
      for i in range(1, length(split("/", route.path))) :
      join("/", slice(split("/", route.path), 0, i + 1))
    ] if route.path != "/"
  ])

  # Remove duplicates and sort by depth (shorter paths first)
  unique_path_segments = distinct(sort(local.all_path_segments))

  # Map each path to its parts
  path_parts_map = {
    for path in local.unique_path_segments : path => {
      parts       = split("/", trimprefix(path, "/"))
      parent_path = length(split("/", trimprefix(path, "/"))) > 1 ? join("/", slice(split("/", path), 0, length(split("/", path)) - 1)) : "/"
      path_part   = element(reverse(split("/", trimprefix(path, "/"))), 0)
    }
  }
}

# ============================================
# API Gateway REST API
# ============================================
resource "aws_api_gateway_rest_api" "this" {
  name = var.name
}

# ============================================
# Resources for non-root paths (split by depth to avoid circular dependency)
# ============================================
resource "aws_api_gateway_resource" "level1" {
  for_each = { for p, v in local.path_parts_map : p => v if length(v.parts) == 1 }

  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = each.value.path_part
}

resource "aws_api_gateway_resource" "level2" {
  for_each = { for p, v in local.path_parts_map : p => v if length(v.parts) == 2 }

  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.level1[each.value.parent_path].id
  path_part   = each.value.path_part
}

resource "aws_api_gateway_resource" "level3" {
  for_each = { for p, v in local.path_parts_map : p => v if length(v.parts) == 3 }

  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.level2[each.value.parent_path].id
  path_part   = each.value.path_part
}

resource "aws_api_gateway_resource" "level4" {
  for_each = { for p, v in local.path_parts_map : p => v if length(v.parts) == 4 }

  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.level3[each.value.parent_path].id
  path_part   = each.value.path_part
}

locals {
  # Merge all level resources into a single map for easy lookup
  all_path_resources = merge(
    aws_api_gateway_resource.level1,
    aws_api_gateway_resource.level2,
    aws_api_gateway_resource.level3,
    aws_api_gateway_resource.level4,
  )
}

# ============================================
# Methods and Integrations
# ============================================
resource "aws_api_gateway_method" "routes" {
  for_each = local.parsed_routes

  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = each.value.path == "/" ? aws_api_gateway_rest_api.this.root_resource_id : local.all_path_resources[each.value.path].id
  http_method   = each.value.method
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "routes" {
  for_each = local.parsed_routes

  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = each.value.path == "/" ? aws_api_gateway_rest_api.this.root_resource_id : local.all_path_resources[each.value.path].id
  http_method = aws_api_gateway_method.routes[each.key].http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${coalesce(var.routes[each.key].lambda_arn, var.lambda_arn)}/invocations"
}

# ============================================
# Deployment
# ============================================
resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id

  triggers = {
    # Trigger redeployment when any method or integration changes
    redeployment = sha1(jsonencode([
      [for k, v in aws_api_gateway_method.routes : v.id],
      [for k, v in aws_api_gateway_integration.routes : v.id]
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.routes
  ]
}

# ============================================
# Stage
# ============================================
resource "aws_api_gateway_stage" "this" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  deployment_id = aws_api_gateway_deployment.this.id
  stage_name    = var.stage_name
}

# ============================================
# Lambda Permissions (one per unique lambda)
# ============================================
locals {
  unique_lambdas = {
    for name in distinct([
      for route_key, route_config in var.routes :
      coalesce(route_config.lambda_name, var.lambda_name)
    ]) : name => name
  }
}

resource "aws_lambda_permission" "apigw" {
  for_each = local.unique_lambdas

  statement_id  = "AllowAPIGatewayInvoke-${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = each.value
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.this.execution_arn}/*/*"
}
