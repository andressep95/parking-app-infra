# ============================================
# Lambda Module - Variables
# ============================================

variable "function_name" {
  description = "Name of the Lambda function"
  type        = string
}

variable "filename" {
  description = "Path to the Lambda deployment package. Defaults to a minimal placeholder ZIP."
  type        = string
  default     = null
}

variable "source_code_hash" {
  description = "Hash of the Lambda source code. Auto-calculated from placeholder if not provided."
  type        = string
  default     = null
}

variable "role_arn" {
  description = "ARN of the IAM role for Lambda"
  type        = string
}

variable "handler" {
  description = "Lambda function handler"
  type        = string
}

variable "runtime" {
  description = "Lambda runtime"
  type        = string
  default     = "provided.al2023"
}

variable "timeout" {
  description = "Lambda timeout in seconds"
  type        = number
  default     = 30

  validation {
    condition     = var.timeout >= 1 && var.timeout <= 900
    error_message = "Timeout must be between 1 and 900 seconds."
  }
}

variable "memory_size" {
  description = "Lambda memory size in MB"
  type        = number
  default     = 128

  validation {
    condition     = var.memory_size >= 128 && var.memory_size <= 10240
    error_message = "Memory size must be between 128 and 10240 MB."
  }
}

variable "environment_variables" {
  description = "Environment variables for Lambda"
  type        = map(string)
  default     = {}
}

variable "vpc_config" {
  description = "VPC configuration for Lambda"
  type = object({
    subnet_ids         = list(string)
    security_group_ids = list(string)
  })
  default = null
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "Log retention days must be a valid CloudWatch retention value."
  }
}

variable "log_kms_key_id" {
  description = "KMS key ID for CloudWatch log encryption"
  type        = string
  default     = null
}

variable "create_log_group" {
  description = "Create CloudWatch log group (disable for LocalStack)"
  type        = bool
  default     = true
}

variable "create_api_gateway_permission" {
  description = "Create permission for API Gateway to invoke Lambda"
  type        = bool
  default     = false
}

variable "api_gateway_source_arn" {
  description = "Source ARN of API Gateway"
  type        = string
  default     = ""
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}

variable "architecture" {
  description = "Instruction set architecture (x86_64 or arm64)"
  type        = string
  default     = "arm64"

  validation {
    condition     = contains(["x86_64", "arm64"], var.architecture)
    error_message = "Architecture must be x86_64 or arm64"
  }
}

variable "reserved_concurrent_executions" {
  description = "Reserved concurrent executions (-1 for unreserved)"
  type        = number
  default     = -1
}

variable "xray_tracing_enabled" {
  description = "Enable AWS X-Ray tracing"
  type        = bool
  default     = true
}

variable "dlq_arn" {
  description = "ARN of SQS queue or SNS topic for dead letter queue"
  type        = string
  default     = null
}

variable "layer_arns" {
  description = "List of Lambda Layer ARNs"
  type        = list(string)
  default     = []
}

# Alarm variables
variable "create_error_alarm" {
  description = "Create CloudWatch alarm for errors"
  type        = bool
  default     = true
}

variable "error_threshold" {
  description = "Error count threshold for alarm"
  type        = number
  default     = 10
}

variable "error_period" {
  description = "Period in seconds for error alarm"
  type        = number
  default     = 300
}

variable "error_evaluation_periods" {
  description = "Evaluation periods for error alarm"
  type        = number
  default     = 2
}

variable "create_duration_alarm" {
  description = "Create CloudWatch alarm for duration"
  type        = bool
  default     = true
}

variable "duration_threshold" {
  description = "Duration threshold in milliseconds"
  type        = number
  default     = 10000
}

variable "duration_period" {
  description = "Period in seconds for duration alarm"
  type        = number
  default     = 60
}

variable "duration_evaluation_periods" {
  description = "Evaluation periods for duration alarm"
  type        = number
  default     = 3
}

variable "alarm_sns_topic_arns" {
  description = "SNS topic ARNs for alarm notifications"
  type        = list(string)
  default     = []
}
