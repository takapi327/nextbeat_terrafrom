resource "aws_ecr_repository" "jvm_microservice_server" {
  name = "jvm-microservice-server"
}

resource "aws_ecr_repository" "aurora_verification_server" {
  name = "aurora-verification-server"
}

resource "aws_ecr_repository" "http4s_ldbc_todo" {
  name = "http4s-ldbc-todo"
}
