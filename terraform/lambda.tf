# ===== IAM ROLES Y POLICIES =====

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

# Policy para acceso a internet (si necesitas VPC)
resource "aws_iam_role_policy_attachment" "lambda_vpc_access" {
  count      = var.lambda_in_vpc ? 1 : 0
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# ===== LAMBDA FUNCTION =====

# Data source para obtener el archivo ZIP (inicial)
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../src/lambda"
  output_path = "${path.module}/lambda_packages/spacex_processor.zip"
  excludes    = ["__pycache__", "*.pyc", ".pytest_cache", "tests"]
}

# Lambda Function
resource "aws_lambda_function" "spacex_processor" {
  function_name    = "${var.project_name}-spacex-processor-${var.environment}"
  description      = "Procesa datos de SpaceX API y los guarda en DynamoDB"
  role            = aws_iam_role.lambda_execution_role.arn
  handler         = "lambda_function.lambda_handler"
  runtime         = "python3.9"
  timeout         = var.lambda_timeout
  memory_size     = var.lambda_memory_size

  # Código inicial (será actualizado por pipeline)
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  # Variables de entorno
  environment {
    variables = {
      DYNAMODB_TABLE_NAME = aws_dynamodb_table.spacex_launches.name
      ENVIRONMENT        = var.environment
      LOG_LEVEL          = var.environment == "prod" ? "INFO" : "DEBUG"
    }
  }

  # Configuración de VPC (opcional)
  dynamic "vpc_config" {
    for_each = var.lambda_in_vpc ? [1] : []
    content {
      subnet_ids         = var.lambda_subnet_ids
      security_group_ids = [aws_security_group.lambda_sg[0].id]
    }
  }

  # Dead Letter Queue (opcional)
  dynamic "dead_letter_config" {
    for_each = var.enable_dlq ? [1] : []
    content {
      target_arn = aws_sqs_queue.lambda_dlq[0].arn
    }
  }

  # Prevenir que Terraform sobrescriba updates del pipeline
  lifecycle {
    ignore_changes = [
      source_code_hash,
      filename,
      last_modified
    ]
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic_execution,
    aws_iam_role_policy_attachment.lambda_dynamodb_access
  ]

  tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
    DeployedBy  = "Pipeline"
  }
}

# ===== EVENTBRIDGE SCHEDULER =====

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
    timestamp   = timestamp()
  })
}

# Permiso para que EventBridge invoque la Lambda
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.spacex_processor.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.spacex_processor_schedule.arn
}

# ===== OPCIONALES: SECURITY GROUP PARA VPC =====

resource "aws_security_group" "lambda_sg" {
  count = var.lambda_in_vpc ? 1 : 0

  name_prefix = "${var.project_name}-lambda-sg-${var.environment}"
  vpc_id      = var.vpc_id
  description = "Security group for Lambda function"

  # Egress para HTTPS (SpaceX API)
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS outbound for SpaceX API"
  }

  # Egress para HTTP (si necesario)
  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP outbound"
  }

  tags = {
    Name        = "${var.project_name}-lambda-sg-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
  }
}

# ===== OPCIONALES: DEAD LETTER QUEUE =====

resource "aws_sqs_queue" "lambda_dlq" {
  count = var.enable_dlq ? 1 : 0

  name                      = "${var.project_name}-lambda-dlq-${var.environment}"
  message_retention_seconds = 1209600  # 14 días

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# Policy para que Lambda pueda enviar a DLQ
resource "aws_iam_role_policy" "lambda_dlq_policy" {
  count = var.enable_dlq ? 1 : 0

  name = "${var.project_name}-lambda-dlq-policy-${var.environment}"
  role = aws_iam_role.lambda_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage"
        ]
        Resource = aws_sqs_queue.lambda_dlq[0].arn
      }
    ]
  })
}

# ===== OUTPUTS =====

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

output "eventbridge_rule_name" {
  description = "Nombre de la regla de EventBridge"
  value       = aws_cloudwatch_event_rule.spacex_processor_schedule.name
}