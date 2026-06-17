# ============================================
# DynamoDB Single-Table
# ============================================

resource "aws_dynamodb_table" "this" {
  name         = var.table_name
  billing_mode = var.billing_mode
  hash_key     = "PK"
  range_key    = "SK"

  # ── Claves primarias ──────────────────────────────────────────────────────────
  attribute {
    name = "PK"
    type = "S"
  }

  attribute {
    name = "SK"
    type = "S"
  }

  # ── Atributos dispersos para GSIs ─────────────────────────────────────────────
  attribute {
    name = "GSI1PK"
    type = "S"
  }

  attribute {
    name = "GSI1SK"
    type = "S"
  }

  attribute {
    name = "GSI2PK"
    type = "S"
  }

  attribute {
    name = "GSI2SK"
    type = "S"
  }

  # ── GSI1 — Lookups de alta frecuencia por clave alterna ───────────────────────
  # Cubre: COGNITO#<sub> → User, SERIAL#<num> → Terminal, PLATE#<plate> → ParkingSession activa
  # Proyección ALL: ítems pequeños, frecuencia muy alta, evita second GetItem
  global_secondary_index {
    name            = "GSI1"
    hash_key        = "GSI1PK"
    range_key       = "GSI1SK"
    projection_type = "ALL"
  }

  # ── GSI2 — Lookups por email (User) y auditoría por usuario (AuditLog) ────────
  # Proyección KEYS_ONLY: frecuencia media/baja, se acepta second fetch
  global_secondary_index {
    name            = "GSI2"
    hash_key        = "GSI2PK"
    range_key       = "GSI2SK"
    projection_type = "KEYS_ONLY"
  }

  # ── TTL — Eliminación automática de sesiones huérfanas ───────────────────────
  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  # ── PITR — Recomendado en prod ────────────────────────────────────────────────
  point_in_time_recovery {
    enabled = var.point_in_time_recovery
  }

  tags = var.tags
}
