module "cognito" {
  source = "../../modules/cognito"

  user_pool_name = "${var.environment}-${var.project_name}-user-pool"
  client_name    = "${var.environment}-${var.project_name}-client"

  # Login con RUT como username (campo libre, no email)
  username_attributes      = []
  auto_verified_attributes = []

  # Atributos requeridos en el registro
  required_attributes = ["email", "given_name", "family_name"]

  # Atributos que el App Client puede leer y escribir
  read_attributes = [
    "email",
    "given_name",
    "family_name",
    "phone_number",
    "custom:role",
  ]

  write_attributes = [
    "email",
    "given_name",
    "family_name",
    "phone_number",
  ]

  password_minimum_length     = 8
  mfa_configuration           = "OFF"
  access_token_validity_hours = 1
  refresh_token_validity_days = 30

  deletion_protection = false

  tags = local.common_tags
}
