resource "aws_cloudwatch_log_group" "ecs" {
  name = "/ecs/logs"
}

resource "aws_cloudwatch_log_group" "vpclattice_service" {
  name = "/vpclattice/service/logs"
}

resource "aws_cloudwatch_log_group" "lambda_service" {
  name = "/aws/lambda/${aws_lambda_function.microservice_lambda.function_name}"
}
