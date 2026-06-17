variable "table_name" {
  description = "Nombre de la tabla DynamoDB"
  type        = string
}

variable "billing_mode" {
  description = "Modo de facturación: PAY_PER_REQUEST (on-demand) o PROVISIONED"
  type        = string
  default     = "PAY_PER_REQUEST"

  validation {
    condition     = contains(["PAY_PER_REQUEST", "PROVISIONED"], var.billing_mode)
    error_message = "billing_mode debe ser PAY_PER_REQUEST o PROVISIONED"
  }
}

variable "point_in_time_recovery" {
  description = "Habilita Point-In-Time Recovery (recomendado en prod)"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags aplicados a la tabla"
  type        = map(string)
  default     = {}
}
