# =============================================================================
# CONFIGURACIÓN GENERAL
# =============================================================================

variable "aws_region" {
  description = "AWS region donde desplegar los recursos"
  type        = string
  default     = "us-east-1"
  
  validation {
    condition = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "AWS region must be in valid format (e.g., us-east-1)."
  }
}

variable "environment" {
  description = "Nombre del ambiente (dev, staging, prod)"
  type        = string
  default     = "dev"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "project_name" {
  description = "Nombre del proyecto (usado en naming de recursos)"
  type        = string
  default     = "spacex-launches"
  
  validation {
    condition = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

# =============================================================================
# CONFIGURACIÓN ECS FARGATE
# =============================================================================

variable "ecs_cpu" {
  description = "CPU units para ECS task (256, 512, 1024, 2048, 4096)"
  type        = string
  default     = "256"
  
  validation {
    condition = contains(["256", "512", "1024", "2048", "4096"], var.ecs_cpu)
    error_message = "ECS CPU must be one of: 256, 512, 1024, 2048, 4096."
  }
}

variable "ecs_memory" {
  description = "Memoria en MB para ECS task (debe ser compatible con CPU)"
  type        = string
  default     = "512"
  
  validation {
    condition = can(regex("^[0-9]+$", var.ecs_memory))
    error_message = "ECS memory must be a valid number."
  }
}

variable "ecs_desired_count" {
  description = "Número deseado de tasks ECS ejecutándose"
  type        = number
  default     = 2
  
  validation {
    condition = var.ecs_desired_count >= 1 && var.ecs_desired_count <= 100
    error_message = "ECS desired count must be between 1 and 100."
  }
}

variable "ecs_min_capacity" {
  description = "Capacidad mínima para Auto Scaling"
  type        = number
  default     = 1
  
  validation {
    condition = var.ecs_min_capacity >= 1
    error_message = "ECS min capacity must be at least 1."
  }
}

variable "ecs_max_capacity" {
  description = "Capacidad máxima para Auto Scaling"
  type        = number
  default     = 10
  
  validation {
    condition = var.ecs_max_capacity >= 1 && var.ecs_max_capacity <= 100
    error_message = "ECS max capacity must be between 1 and 100."
  }
}

# =============================================================================
# CONFIGURACIÓN LAMBDA
# =============================================================================

variable "lambda_timeout" {
  description = "Timeout de la función Lambda en segundos"
  type        = number
  default     = 300
  
  validation {
    condition = var.lambda_timeout >= 3 && var.lambda_timeout <= 900
    error_message = "Lambda timeout must be between 3 and 900 seconds."
  }
}

variable "lambda_memory_size" {
  description = "Memoria de la función Lambda en MB"
  type        = number
  default     = 512
  
  validation {
    condition = var.lambda_memory_size >= 128 && var.lambda_memory_size <= 10240
    error_message = "Lambda memory size must be between 128 and 10240 MB."
  }
}

variable "lambda_schedule_expression" {
  description = "Expresión de schedule para EventBridge (rate o cron)"
  type        = string
  default     = "rate(6 hours)"
  
  validation {
    condition = can(regex("^(rate\\([0-9]+ (minute|minutes|hour|hours|day|days)\\)|cron\\(.+\\))$", var.lambda_schedule_expression))
    error_message = "Must be a valid rate() or cron() expression."
  }
}

# =============================================================================
# CONFIGURACIÓN DE RED
# =============================================================================

variable "lambda_in_vpc" {
  description = "Si desplegar Lambda dentro de VPC"
  type        = bool
  default     = false
}

variable "lambda_subnet_ids" {
  description = "IDs de subnets para Lambda (si está en VPC)"
  type        = list(string)
  default     = []
  
  validation {
    condition = var.lambda_in_vpc == false || length(var.lambda_subnet_ids) > 0
    error_message = "Subnet IDs must be provided when lambda_in_vpc is true."
  }
}

variable "vpc_id" {
  description = "ID de la VPC (si se usa VPC existente)"
  type        = string
  default     = ""
}

# =============================================================================
# CONFIGURACIÓN DE MONITOREO
# =============================================================================

variable "enable_monitoring" {
  description = "Habilitar CloudWatch alarms para Lambda"
  type        = bool
  default     = true
}

variable "enable_dlq" {
  description = "Habilitar Dead Letter Queue para Lambda"
  type        = bool
  default     = false
}

variable "sns_alarm_topic_arn" {
  description = "ARN del tópico SNS para alarmas (opcional)"
  type        = string
  default     = ""
  
  validation {
    condition = var.sns_alarm_topic_arn == "" || can(regex("^arn:aws:sns:", var.sns_alarm_topic_arn))
    error_message = "SNS topic ARN must be empty or a valid SNS ARN."
  }
}

# =============================================================================
# CONFIGURACIÓN DE API
# =============================================================================

variable "api_stage_name" {
  description = "Nombre del stage de API Gateway"
  type        = string
  default     = "v1"
  
  validation {
    condition = can(regex("^[a-zA-Z0-9]+$", var.api_stage_name))
    error_message = "API stage name must contain only alphanumeric characters."
  }
}

# =============================================================================
# TAGS GLOBALES
# =============================================================================

variable "common_tags" {
  description = "Tags comunes para todos los recursos"
  type        = map(string)
  default = {
    ManagedBy = "Terraform"
    Project   = "SpaceX-Launches"
  }
}

# =============================================================================
# CONFIGURACIÓN POR AMBIENTE
# =============================================================================

locals {
  # Configuraciones específicas por ambiente
  environment_config = {
    dev = {
      log_retention_days = 7
      backup_enabled     = false
      deletion_protection = false
    }
    staging = {
      log_retention_days = 14
      backup_enabled     = true
      deletion_protection = false
    }
    prod = {
      log_retention_days = 30
      backup_enabled     = true
      deletion_protection = true
    }
  }
  
  # Configuración actual basada en el ambiente
  current_config = local.environment_config[var.environment]
  
  # Tags combinados
  merged_tags = merge(var.common_tags, {
    Environment = var.environment
    Project     = var.project_name
  })
}