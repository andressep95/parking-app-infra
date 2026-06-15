variable "user_pool_name" {
  description = "Name of the Cognito User Pool"
  type        = string
}

variable "client_name" {
  description = "Name of the Cognito User Pool Client"
  type        = string
}

variable "password_minimum_length" {
  description = "Minimum password length"
  type        = number
  default     = 8
}

variable "mfa_configuration" {
  description = "MFA configuration: OFF, ON, or OPTIONAL"
  type        = string
  default     = "OFF"

  validation {
    condition     = contains(["OFF", "ON", "OPTIONAL"], var.mfa_configuration)
    error_message = "mfa_configuration must be OFF, ON, or OPTIONAL"
  }
}

variable "access_token_validity_hours" {
  description = "Access token validity in hours"
  type        = number
  default     = 1
}

variable "refresh_token_validity_days" {
  description = "Refresh token validity in days"
  type        = number
  default     = 30
}

variable "callback_urls" {
  description = "Callback URLs for OAuth flows"
  type        = list(string)
  default     = []
}

variable "logout_urls" {
  description = "Logout URLs for OAuth flows"
  type        = list(string)
  default     = []
}

variable "deletion_protection" {
  description = "Enable deletion protection for the User Pool"
  type        = bool
  default     = true
}

variable "required_attributes" {
  description = "Atributos estándar de Cognito marcados como requeridos en el User Pool"
  type        = list(string)
  default     = []
}

variable "read_attributes" {
  description = "Atributos que el App Client puede leer"
  type        = list(string)
  default     = ["email", "email_verified", "custom:role"]
}

variable "write_attributes" {
  description = "Atributos que el App Client puede escribir al registrar"
  type        = list(string)
  default     = ["email"]
}

variable "username_attributes" {
  description = "Atributos usados como username para login. [] = username libre (ej: RUT), ['email'] = login con email"
  type        = list(string)
  default     = ["email"]
}

variable "auto_verified_attributes" {
  description = "Atributos que Cognito verifica automáticamente"
  type        = list(string)
  default     = ["email"]
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
