variable "name" {
  type        = string
  description = "Nombre del API Gateway"
}

variable "region" {
  type        = string
  description = "AWS region"
}

variable "lambda_arn" {
  type        = string
  description = "ARN de la Lambda por defecto"
  default     = ""
}

variable "lambda_name" {
  type        = string
  description = "Nombre de la Lambda por defecto (para permisos)"
  default     = ""
}

variable "stage_name" {
  type    = string
  default = "dev"
}

variable "routes" {
  description = "Map of routes (route_key => config). Format: 'METHOD /path' => { lambda_arn?, lambda_name? }"
  type = map(object({
    lambda_arn        = optional(string)
    lambda_name       = optional(string)
    lambda_invoke_arn = optional(string)
  }))

  default = {
    "GET /" = {}
  }
}
