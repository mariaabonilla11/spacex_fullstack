#!/bin/bash

set -e

echo "Building Lambda package..."

# Rutas corregidas (desde terraform/)
LAMBDA_DIR="../src/lambda"
BUILD_DIR="../build/lambda"
PACKAGE_DIR="lambda_packages"

# Limpiar build anterior
rm -rf $BUILD_DIR
rm -rf $PACKAGE_DIR
mkdir -p $BUILD_DIR
mkdir -p $PACKAGE_DIR

# Verificar que el archivo existe
if [ ! -f "$LAMBDA_DIR/lambda_function.py" ]; then
    echo "Error: No se encuentra lambda_function.py en $LAMBDA_DIR"
    echo "Estructura actual:"
    ls -la $LAMBDA_DIR/ || echo "Directorio no existe"
    exit 1
fi

# Copiar código fuente
cp $LAMBDA_DIR/*.py $BUILD_DIR/

# Instalar dependencias - CAMBIO AQUÍ
python3 -m pip install -r $LAMBDA_DIR/requirements.txt -t $BUILD_DIR/

# Crear ZIP
cd $BUILD_DIR
zip -r ../../terraform/$PACKAGE_DIR/spacex_processor.zip .
cd ../../terraform

echo "Lambda package created: $PACKAGE_DIR/spacex_processor.zip"