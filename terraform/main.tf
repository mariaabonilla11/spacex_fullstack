terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Solo la tabla DynamoDB para lanzamientos de SpaceX
resource "aws_dynamodb_table" "spacex_launches" {
  name         = "${var.project_name}-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  
  # Clave primaria única
  hash_key = "launch_id"
  
  # Solo definir atributos que se usan en keys o índices
  attribute {
    name = "launch_id"
    type = "S"
  }
  
  attribute {
    name = "mission_name"
    type = "S"
  }
  
  attribute {
    name = "rocket_name"
    type = "S"
  }
  
  attribute {
    name = "launch_date"
    type = "S"
  }
  
  attribute {
    name = "status"
    type = "S"
  }

  # Índices secundarios globales
  global_secondary_index {
    name               = "MissionNameIndex"
    hash_key           = "mission_name"
    projection_type    = "ALL"
  }
  
  global_secondary_index {
    name               = "RocketNameIndex"
    hash_key           = "rocket_name"
    projection_type    = "ALL"
  }
  
  global_secondary_index {
    name               = "LaunchDateIndex"
    hash_key           = "launch_date"
    projection_type    = "ALL"
  }
  
  global_secondary_index {
    name               = "StatusIndex"
    hash_key           = "status"
    projection_type    = "ALL"
  }

  # Configuración adicional
  point_in_time_recovery {
    enabled = var.environment == "prod" ? true : false
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

# Output para obtener el nombre de la tabla
output "dynamodb_table_name" {
  description = "Name of the DynamoDB table"
  value       = aws_dynamodb_table.spacex_launches.name
}

output "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table"
  value       = aws_dynamodb_table.spacex_launches.arn
}