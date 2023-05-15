terraform {
  required_version = ">= 1.4.6"

  cloud {
    organization = "takapi327"

    workspaces {
      name = "productA"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.67.0"
    }
  }
}
