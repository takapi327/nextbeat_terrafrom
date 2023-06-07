resource "aws_lambda_function" "microservice_lambda" {
  function_name = "microservice-lambda"
  role          = aws_iam_role.lambda_role.arn
  filename      = "./dist.zip"

  runtime = "nodejs16.x"
  handler = "index.handler"
  timeout = 30
}
