variable "name" {
  description = "API Gateway name"
  type        = string
}

variable "stage_name" {
  description = "Stage name"
  type        = string
  default     = "$default"
}

variable "lambda_name" {
  description = "Default Lambda function name"
  type        = string
}

variable "lambda_invoke_arn" {
  description = "Default Lambda invoke ARN"
  type        = string
}

variable "routes" {
  description = "Map of routes (route_key => config). Each route can override lambda_invoke_arn and lambda_name."
  type = map(object({
    lambda_arn        = optional(string)
    lambda_name       = optional(string)
    lambda_invoke_arn = optional(string)
    public            = optional(bool, false)
  }))

  default = {
    "GET /"     = {}
    "POST /api" = {}
  }
}

variable "cors_allow_origins" {
  type    = list(string)
  default = ["*"]
}

variable "cors_allow_methods" {
  type    = list(string)
  default = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
}

variable "cors_allow_headers" {
  type    = list(string)
  default = ["*"]
}

variable "tags" {
  type    = map(string)
  default = {}
}

# ============================================
# Throttling Configuration
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
# Access Logging Configuration
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

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.access_log_retention_days)
    error_message = "Log retention days must be a valid CloudWatch retention value."
  }
}

# ============================================
# JWT Authorizer Configuration
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
