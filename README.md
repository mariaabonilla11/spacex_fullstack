# SpaceX Lambda Function

Función Lambda que se ejecuta automáticamente cada 6 horas para consumir la API pública de SpaceX y almacenar los datos de lanzamientos en DynamoDB. Incluye capacidad de invocación manual para pruebas y desarrollo.

## 🚀 Características

- **Ejecución automática** cada 6 horas via EventBridge
- **Consumo de API SpaceX** (https://api.spacexdata.com/v3/launches)
- **Almacenamiento en DynamoDB** con lógica de upsert
- **Invocación manual** para testing via API Gateway
- **Pruebas unitarias** completas con unittest
- **Infraestructura como código** con Terraform
- **Logs estructurados** en CloudWatch

## 🛠️ Tecnologías

- **Python 3.11** - Runtime de la función
- **AWS Lambda** - Compute serverless
- **DynamoDB** - Base de datos NoSQL
- **EventBridge** - Programación automática
- **API Gateway** - Endpoint para invocación manual
- **Terraform** - Infraestructura como código
- **Docker** - Containerización para desarrollo

## 📋 Requisitos

- Python 3.11+
- AWS CLI configurado
- Terraform >= 1.0
- Docker (para desarrollo local)
- Credenciales AWS con permisos para:
  - Lambda
  - DynamoDB
  - EventBridge
  - API Gateway
  - CloudWatch Logs

## 🔧 Estructura del Proyecto

```
spacex-fullstack/
├── .venv/                          # Entorno virtual de Python
├── build/                          # Archivos de construcción
├── cdk.out/                        # Salida de AWS CDK
├── scripts/                        # Scripts de automatización
├── src/
│   └── lambda/                     # Funciones Lambda
│       ├── __pycache__/            # Cache de Python
│       ├── lambda_function.py      # Función Lambda principal
│       └── requirements.txt        # Dependencias de Lambda
├── terraform/                      # Infraestructura como código
│   ├── main.tf                     # Configuración principal
│   ├── lambda.tf                   # Recursos Lambda
│   ├── api_gateway.tf              # API Gateway
│   └── variables.tf                # Variables Terraform
├── tests/                          # Pruebas automatizadas
│   └── test_lambda_function.py     # Tests unitarios
├── .env                            # Variables de entorno
├── .env-example                    # Ejemplo de variables
├── Dockerfile                      # Imagen principal
├── Dockerfile.terraform            # Imagen para Terraform
└── requirements.txt                # Dependencias de producción
```

## ⚙️ Configuración

### Variables de entorno

Crear archivo `.env` basado en `.env-example`:

```env
AWS_ACCESS_KEY_ID=tu_access_key
AWS_SECRET_ACCESS_KEY=tu_secret_key
AWS_DEFAULT_REGION=us-east-1
DYNAMODB_TABLE_NAME=spacex-launches-dev
```

### Configuración de AWS

```bash
# Configurar credenciales AWS
aws configure

# Verificar configuración
aws sts get-caller-identity
```

## 🏗️ Instalación y Desarrollo

### 1. Clonar el repositorio

```bash
git clone https://github.com/mariaabonilla11/spacex_fullstack.git
cd spacex_fullstack
```

### 2. Configurar entorno virtual

```bash
python -m venv .venv
source .venv/bin/activate  # En Windows: .venv\Scripts\activate
pip install -r requirements.txt
```

### 3. Desarrollo con Docker

#### Construcción de imagen principal

```bash
docker build -t spacex-lambda .
```

#### Ejecución local

```bash
docker run --env-file .env spacex-lambda
```

#### Ejecución de la función Lambda

```bash
docker run -it -v $(pwd):/workspace --env-file .env spacex-lambda \
  python3 /workspace/src/lambda/lambda_function.py
```

### 4. Desarrollo con Terraform (Docker)

```bash
# Construir imagen Terraform
docker build -f Dockerfile.terraform -t terraform-aws .

# Ejecutar contenedor Terraform
docker run -it \
  -v $(pwd):/workspace \
  -v ~/.aws:/root/.aws \
  -e AWS_PROFILE=default \
  terraform-aws
```

## 🧪 Testing

### Ejecutar pruebas unitarias

```bash
# Ejecutar con Docker
docker run -it -v $(pwd):/workspace --env-file .env spacex-lambda \
  python3 -m unittest tests/test_lambda_function.py -v

# Ejecutar localmente (si tienes Python configurado)
python -m unittest tests/test_lambda_function.py -v
```

### Resultado esperado

```
test_determine_launch_status ... ok
test_lambda_handler_api_error ... ok
test_lambda_handler_success ... ok
test_parse_launch_data ... ok
test_process_launch_data_parsing ... ok
test_upsert_launch_to_dynamodb_created ... ok
test_upsert_launch_to_dynamodb_error ... ok
test_upsert_launch_to_dynamodb_updated ... ok

Ran 7 tests in 0.004s
OK
```

## 🚀 Despliegue

### 1. Inicializar Terraform

```bash
cd terraform
terraform init
```

### 2. Planificar despliegue

```bash
# Verificar tabla DynamoDB
terraform plan -target=aws_dynamodb_table.spacex_launches

# Planificar función Lambda
terraform plan
```

### 3. Aplicar cambios

```bash
# Crear tabla DynamoDB
terraform apply -target=aws_dynamodb_table.spacex_launches

# Desplegar Lambda completa
terraform apply
```

## 📊 Función Lambda

### Estructura de la función

```python
def lambda_handler(event, context):
    """
    Función principal que procesa lanzamientos de SpaceX
    
    Args:
        event: Evento de Lambda (EventBridge o API Gateway)
        context: Contexto de ejecución
        
    Returns:
        dict: Respuesta con estadísticas de procesamiento
    """
    # Lógica de procesamiento
```

### Flujo de datos

1. **Consumo API**: Obtiene datos de `https://api.spacexdata.com/v3/launches`
2. **Parsing**: Extrae campos relevantes de cada lanzamiento
3. **Transformación**: Convierte datos al formato DynamoDB
4. **Upsert**: Inserta o actualiza registros en DynamoDB
5. **Respuesta**: Retorna estadísticas de procesamiento

### Campos procesados

```json
{
  "flight_number": 1,
  "mission_name": "FalconSat",
  "launch_date": "2006-03-24T22:30:00.000Z",
  "rocket_name": "Falcon 1",
  "launch_success": false,
  "launch_site": "Kwajalein Atoll",
  "details": "Engine failure at 33 seconds...",
  "api_endpoint": "https://api.spacexdata.com/v3/launches",
  "table_name": "spacex-launches-dev"
}
```

## 🔄 Programación Automática

### EventBridge Rule

La función se ejecuta automáticamente cada 6 horas:

```bash
# Verificar regla de EventBridge
aws events describe-rule --name spacex-launches-processor-schedule-dev
```

### Logs en tiempo real

```bash
# Monitorear logs de Lambda
aws logs tail /aws/lambda/spacex-launches-spacex-processor-dev --follow
```

## 🌐 API Gateway

### Endpoint manual

```
POST https://xn0dljszfc.execute-api.us-east-1.amazonaws.com/test/trigger
```

### Respuesta ejemplo

```json
{
  "message": "Successfully processed",
  "execution_type": "manual",
  "timestamp": "2024-01-15T10:30:00.000Z",
  "summary": {
    "new_records": 15,
    "updated_records": 94,
    "total_processed": 109
  },
  "details": {
    "latest_launches": [
      {
        "flight_number": 109,
        "mission_name": "Starlink-15 v1.0"
      }
    ]
  }
}
```

## 🔍 Verificación y Monitoreo

### Verificar función Lambda

```bash
aws lambda get-function --function-name spacex-launches-spacex-processor-dev
```

### Verificar datos en DynamoDB

```bash
aws dynamodb scan --table-name spacex-launches-dev --limit 5
```

### Verificar regla de EventBridge

```bash
aws events describe-rule --name spacex-launches-processor-schedule-dev
```

### Monitorear logs

```bash
aws logs tail /aws/lambda/spacex-launches-spacex-processor-dev --follow
```

## 📈 Arquitectura

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   EventBridge   │───▶│  Lambda Function │───▶│   DynamoDB      │
│  (Every 6hrs)   │    │  spacex-processor│    │ spacex-launches │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                │
                         ┌─────────────────┐
                         │  SpaceX API     │
                         │ api.spacexdata. │
                         │    com/v3       │
                         └─────────────────┘
                                │
                         ┌─────────────────┐
                         │  API Gateway    │
                         │ (Manual trigger)│
                         └─────────────────┘
```

## 🛡️ Permisos IAM

La función Lambda requiere los siguientes permisos:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:PutItem",
        "dynamodb:GetItem",
        "dynamodb:UpdateItem",
        "dynamodb:Query",
        "dynamodb:Scan"
      ],
      "Resource": "arn:aws:dynamodb:us-east-1:*:table/spacex-launches-*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    }
  ]
}
```

## 🔧 Troubleshooting

### Problemas comunes

#### Error de permisos DynamoDB
```bash
# Verificar permisos IAM del rol Lambda
aws iam get-role-policy --role-name lambda-execution-role --policy-name dynamodb-access
```

#### Error de timeout
```bash
# Aumentar timeout en configuración Terraform
timeout = 300  # 5 minutos
```

#### Error de memoria
```bash
# Aumentar memoria en configuración Terraform
memory_size = 512  # MB
```

### Logs de debugging

```python
import logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    logger.info(f"Event received: {json.dumps(event)}")
    # Resto de la función
```

## 🔗 Enlaces

- **Repositorio**: https://github.com/mariaabonilla11/spacex_fullstack
- **SpaceX API**: https://api.spacexdata.com/v3/launches
- **Documentación AWS Lambda**: https://docs.aws.amazon.com/lambda/
- **Terraform AWS Provider**: https://registry.terraform.io/providers/hashicorp/aws/

## 👨‍💻 Autor

**Maria del Pilar Bonilla**
- GitHub: [@mariaabonilla11](https://github.com/mariaabonilla11)
