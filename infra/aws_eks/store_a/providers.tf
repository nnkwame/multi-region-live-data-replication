terraform {
  required_version = ">= 1.5.0"

  backend "s3" {
    # Shared bucket (us-east-1) for all stacks; the key is unique per stack so
    # store_a / store_b / data_replication can never overwrite each other's
    # state. Workspaces append `env:<workspace>/` to this key automatically.
    bucket         = "kwames-terraform-state-bucket"
    key            = "store-a/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "kwames-terraform-state-lock"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0" # Restricts updates to minor versions only
    }
  }
}

provider "aws" {
  # Actual deployment region comes from the variable (us-east-1 for store_a,
  # eu-central-1 for store_b). The backend bucket above stays in us-east-1;
  # backend and provider regions are independent.
  region = var.region
}
