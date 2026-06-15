variable "project_name" {
  description = "Nombre del proyecto, usado como prefijo en los recursos"
  type        = string
  default     = "parking-app"
}

variable "aws_region" {
  description = "Región AWS donde se despliega la infraestructura"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Entorno de despliegue"
  type        = string
  default     = "dev"
}

locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
