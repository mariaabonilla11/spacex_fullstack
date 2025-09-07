#!/bin/bash
set -e

echo "Building Lambda package with Docker..."

# Limpiar
rm -rf terraform/lambda_packages
mkdir -p terraform/lambda_packages

# Usar imagen de Amazon Linux compatible con Lambda
docker run --rm \
  -v $(pwd)/src/lambda:/var/task/src \
  -v $(pwd)/terraform/lambda_packages:/var/task/output \
  amazonlinux:2 \
  bash -c "
    yum update -y && \
    yum install -y python3 python3-pip zip && \
    cd /var/task && \
    cp src/*.py . && \
    python3 -m pip install -r src/requirements.txt -t . && \
    zip -r output/spacex_processor.zip . -x '*.pyc' '*/__pycache__/*'
  "

echo "Lambda package created with Docker"