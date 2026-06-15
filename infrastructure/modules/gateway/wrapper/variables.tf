variable "gateway_type" {
  description = "API Gateway type: rest-v1 or http-v2"
  type        = string

  validation {
    condition     = contains(["rest-v1", "http-v2"], var.gateway_type)
    error_message = "gateway_type must be 'rest-v1' or 'http-v2'"
  }
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "name" {
  description = "API Gateway name"
  type        = string
}

variable "stage_name" {
  description = "Stage name"
  type        = string
  default     = "dev"
}

variable "lambda_name" {
  description = "Lambda function name"
  type        = string
  default     = ""
}

# REST v1 usa ARN normal
variable "lambda_arn" {
  description = "Lambda ARN (REST v1)"
  type        = string
  default     = null
}

# HTTP v2 usa invoke ARN
variable "lambda_invoke_arn" {
  description = "Lambda invoke ARN (HTTP v2)"
  type        = string
  default     = null
}

variable "routes" {
  description = "Routes configuration. Format: 'METHOD /path' => { lambda_arn?, lambda_name?, lambda_invoke_arn?, public? }"
  type = map(object({
    lambda_arn        = optional(string)
    lambda_name       = optional(string)
    lambda_invoke_arn = optional(string)
    public            = optional(bool, false)
  }))
  default = {}
}

variable "tags" {
  type    = map(string)
  default = {}
}

# ============================================
# Throttling Configuration (HTTP v2 only)
# ============================================

variable "throttling_burst_limit" {
  description = "Maximum number of concurrent requests API Gateway can handle"
  type        = number
  default     = 100
}

variable "throttling_rate_limit" {
  description = "Maximum number of requests per second"
  type        = number
  default     = 50
}

# ============================================
# Access Logging Configuration (HTTP v2 only)
# ============================================

variable "enable_access_logging" {
  description = "Enable access logging for API Gateway"
  type        = bool
  default     = false
}

variable "access_log_retention_days" {
  description = "Number of days to retain access logs"
  type        = number
  default     = 14
}

# ============================================
# JWT Authorizer Configuration (HTTP v2 only)
# ============================================

variable "jwt_issuer" {
  description = "JWT issuer URL (Cognito User Pool endpoint). Set to null to disable JWT auth."
  type        = string
  default     = null
}

variable "jwt_audience" {
  description = "JWT audience (Cognito App Client IDs)"
  type        = list(string)
  default     = []
}
