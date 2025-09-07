# API Gateway REST API
resource "aws_api_gateway_rest_api" "spacex_test_api" {
  name        = "${var.project_name}-test-api-${var.environment}"
  description = "API para probar Lambda de SpaceX manualmente"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# Resource para /trigger
resource "aws_api_gateway_resource" "trigger" {
  rest_api_id = aws_api_gateway_rest_api.spacex_test_api.id
  parent_id   = aws_api_gateway_rest_api.spacex_test_api.root_resource_id
  path_part   = "trigger"
}

# Method POST /trigger
resource "aws_api_gateway_method" "trigger_post" {
  rest_api_id   = aws_api_gateway_rest_api.spacex_test_api.id
  resource_id   = aws_api_gateway_resource.trigger.id
  http_method   = "POST"
  authorization = "NONE"
}

# Integration con Lambda
resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id = aws_api_gateway_rest_api.spacex_test_api.id
  resource_id = aws_api_gateway_resource.trigger.id
  http_method = aws_api_gateway_method.trigger_post.http_method

  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = aws_lambda_function.spacex_processor.invoke_arn
}

# Permiso para API Gateway
resource "aws_lambda_permission" "api_gateway_invoke" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.spacex_processor.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.spacex_test_api.execution_arn}/*/*"
}

# Deployment
resource "aws_api_gateway_deployment" "spacex_api_deployment" {
  depends_on = [
    aws_api_gateway_integration.lambda_integration
  ]

  rest_api_id = aws_api_gateway_rest_api.spacex_test_api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.trigger.id,
      aws_api_gateway_method.trigger_post.id,
      aws_api_gateway_integration.lambda_integration.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Stage
resource "aws_api_gateway_stage" "test_stage" {
  deployment_id = aws_api_gateway_deployment.spacex_api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.spacex_test_api.id
  stage_name    = "test"

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# Output del endpoint
output "api_test_endpoint" {
  description = "URL del endpoint para probar Lambda manualmente"
  value       = "https://${aws_api_gateway_rest_api.spacex_test_api.id}.execute-api.${var.aws_region}.amazonaws.com/test/trigger"
}