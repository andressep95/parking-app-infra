# ============================================
# DynamoDB — Single-Table (dev-parking-app)
# ============================================

module "main_table" {
  source = "../../modules/dynamodb"

  table_name = "${var.environment}-${var.project_name}"

  # On-demand en dev — sin costos en reposo
  billing_mode = "PAY_PER_REQUEST"

  # PITR solo en prod
  point_in_time_recovery = false

  tags = merge(local.common_tags, {
    Component = "main-table"
  })
}
