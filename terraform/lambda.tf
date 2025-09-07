# =============================================================================
# IAM ROLES Y POLICIES PARA LAMBDA
# =============================================================================

# IAM Role para Lambda Execution
resource "aws_iam_role" "lambda_execution_role" {
  name = "${var.project_name}-lambda-execution-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

# Policy básica para Lambda (CloudWatch Logs)
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Policy para acceso a DynamoDB
resource "aws_iam_policy" "lambda_dynamodb_policy" {
  name        = "${var.project_name}-lambda-dynamodb-policy-${var.environment}"
  description = "IAM policy for Lambda to access DynamoDB"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:BatchGetItem",
          "dynamodb:BatchWriteItem"
        ]
        Resource = [
          aws_dynamodb_table.spacex_launches.arn,
          "${aws_dynamodb_table.spacex_launches.arn}/index/*"
        ]
      }
    ]
  })

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# Attach DynamoDB policy al rol
resource "aws_iam_role_policy_attachment" "lambda_dynamodb_access" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.lambda_dynamodb_policy.arn
}

# =============================================================================
# LAMBDA FUNCTION
# =============================================================================

resource "aws_lambda_function" "spacex_processor" {
  filename         = "lambda_packages/spacex_processor.zip"
  function_name    = "${var.project_name}-spacex-processor-${var.environment}"
  role            = aws_iam_role.lambda_execution_role.arn
  handler         = "lambda_function.lambda_handler"
  runtime         = "python3.9"
  timeout         = var.lambda_timeout
  memory_size     = var.lambda_memory_size
  source_code_hash = filebase64sha256("lambda_packages/spacex_processor.zip")

  environment {
    variables = {
      DYNAMODB_TABLE_NAME = aws_dynamodb_table.spacex_launches.name
      ENVIRONMENT        = var.environment
      LOG_LEVEL          = var.environment == "prod" ? "INFO" : "DEBUG"
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic_execution,
    aws_iam_role_policy_attachment.lambda_dynamodb_access
  ]

  tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

# =============================================================================
# EVENTBRIDGE SCHEDULER (CADA 6 HORAS)
# =============================================================================

# EventBridge Rule para ejecutar cada 6 horas
resource "aws_cloudwatch_event_rule" "spacex_processor_schedule" {
  name                = "${var.project_name}-processor-schedule-${var.environment}"
  description         = "Ejecuta el procesador de SpaceX cada 6 horas"
  schedule_expression = var.lambda_schedule_expression

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# Target para la regla de EventBridge
resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.spacex_processor_schedule.name
  target_id = "SpaceXProcessorTarget"
  arn       = aws_lambda_function.spacex_processor.arn

  input = jsonencode({
    source      = "eventbridge-scheduler"
    environment = var.environment
  })
}

# Permiso para que EventBridge invoque Lambda
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.spacex_processor.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.spacex_processor_schedule.arn
}

# =============================================================================
# OUTPUTS
# =============================================================================

output "lambda_function_name" {
  description = "Nombre de la función Lambda"
  value       = aws_lambda_function.spacex_processor.function_name
}

output "lambda_function_arn" {
  description = "ARN de la función Lambda"
  value       = aws_lambda_function.spacex_processor.arn
}

output "lambda_role_arn" {
  description = "ARN del rol de ejecución de Lambda"
  value       = aws_iam_role.lambda_execution_role.arn
}