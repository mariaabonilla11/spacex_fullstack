FROM python:3.11-slim

# Instala dependencias del sistema
RUN apt-get update && apt-get install -y \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Establece el directorio de trabajo
WORKDIR /app

# Copia los archivos de requerimientos
COPY requirements.txt .

# requirements.txt debe contener:
# aws-cdk-lib==2.213.0
# constructs>=10.0.0,<11.0.0
# requests==2.31.0
# boto3==1.34.0
# botocore==1.34.0

# Instala las dependencias de Python
RUN pip install --no-cache-dir -r requirements.txt

# Copia el código fuente
COPY . .
