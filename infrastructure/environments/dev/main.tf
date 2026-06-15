terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    # Valores inyectados via -backend-config en CI (terraform-plan.yml / terraform-apply.yml)
    # bucket = "control-plane-terraform-states-970547363172"
    # key    = "parking-app/dev/terraform.tfstate"
    # region = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.aws_region
}

