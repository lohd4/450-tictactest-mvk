terraform {
  required_version = ">= 1.8.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # Upper bound on purpose: a new major version of the provider may rename
      # or remove arguments, and this configuration must keep working for the
      # whole module without a surprise rewrite.
      version = ">= 5.60.0, < 7.0.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "Terraform"
      Repo      = "lohd4/450-tictactest-mvk"
    }
  }
}
