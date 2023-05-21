terraform {
  required_version = ">= 1.4.6"

  cloud {
    organization = "takapi327"

    workspaces {
      name = "productB"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.67.0"
    }
  }
}

data "aws_caller_identity" "current" {}

data "terraform_remote_state" "platform" {
  backend = "remote"

  config = {
    organization = "takapi327"

    workspaces = {
      name = "platform"
    }
  }
}
