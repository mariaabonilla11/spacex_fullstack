import json
import boto3
import requests
from datetime import datetime, timezone
import os
from decimal import Decimal
from typing import Dict, Any, List
import logging

# Configurar logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Cliente DynamoDB
dynamodb = boto3.resource('dynamodb')
table_name = os.environ.get('DYNAMODB_TABLE_NAME', 'spacex-launches-dev')
table = dynamodb.Table(table_name)

def lambda_handler(event, context):
    """
    Función Lambda que obtiene datos de SpaceX API y los guarda en DynamoDB
    Soporta invocación manual para testing y ejecución programada
    """
    try:
        logger.info("Iniciando procesamiento de datos de SpaceX...")
        
        # Detectar tipo de invocación
        is_manual_test = (
            event.get('httpMethod') == 'POST' or  # Viene de API Gateway
            event.get('source') == 'manual-test' or  # Invocación directa
            'body' in event  # API Gateway siempre incluye body
        )
        
        logger.info(f"Tipo de invocación: {'manual' if is_manual_test else 'programada'}")
        
        # Obtener datos de la API de SpaceX
        spacex_data = fetch_spacex_launches()
        
        if not spacex_data:
            logger.error("No se pudieron obtener datos de la API de SpaceX")
            return create_response(500, "Error obteniendo datos de SpaceX")
        
        # Procesar y guardar datos
        result = process_and_save_launches(spacex_data)
        
        logger.info(f"Procesamiento completado: {result}")
        
        # Respuesta detallada para invocación manual
        response_body = {
            'message': 'Procesamiento exitoso',
            'execution_type': 'manual' if is_manual_test else 'scheduled',
            'timestamp': datetime.now(timezone.utc).isoformat(),
            'summary': {
                'total_processed': result['processed'],
                'new_records': result['created'],
                'updated_records': result['updated'],
                'errors': result['errors'],
                'api_endpoint': 'https://api.spacexdata.com/v3/launches',
                'table_name': table_name
            }
        }
        
        # Si es manual, agregar más detalles
        if is_manual_test:
            response_body['details'] = {
                'latest_launches': get_latest_launches_summary(),
                'table_stats': get_table_stats()
            }
        
        return create_response(200, response_body)
        
    except Exception as e:
        logger.error(f"Error en lambda_handler: {str(e)}")
        return create_response(500, f"Error interno: {str(e)}")

def fetch_spacex_launches() -> List[Dict[str, Any]]:
    """
    Obtiene los datos de lanzamientos desde la API de SpaceX v3
    """
    try:
        url = "https://api.spacexdata.com/v3/launches"
        logger.info(f"Realizando petición a: {url}")
        
        response = requests.get(url, timeout=30)
        response.raise_for_status()
        
        launches = response.json()
        logger.info(f"Obtenidos {len(launches)} lanzamientos de la API")
        
        return launches
        
    except requests.RequestException as e:
        logger.error(f"Error en petición HTTP: {str(e)}")
        return []
    except json.JSONDecodeError as e:
        logger.error(f"Error decodificando JSON: {str(e)}")
        return []

def process_and_save_launches(launches: List[Dict[str, Any]]) -> Dict[str, int]:
    """
    Procesa y guarda los lanzamientos en DynamoDB usando upsert
    """
    stats = {
        'processed': 0,
        'created': 0,
        'updated': 0,
        'errors': 0
    }
    
    for launch in launches:
        try:
            # Procesar datos del lanzamiento
            processed_launch = process_launch_data(launch)
            
            # Guardar en DynamoDB con upsert
            save_result = upsert_launch_to_dynamodb(processed_launch)
            
            stats['processed'] += 1
            if save_result == 'created':
                stats['created'] += 1
            elif save_result == 'updated':
                stats['updated'] += 1
                
        except Exception as e:
            logger.error(f"Error procesando lanzamiento {launch.get('flight_number', 'unknown')}: {str(e)}")
            stats['errors'] += 1
    
    return stats

def process_launch_data(launch: Dict[str, Any]) -> Dict[str, Any]:
    """
    Procesa y limpia los datos de un lanzamiento individual
    """
    # Determinar el ID único (usando flight_number como clave)
    launch_id = str(launch.get('flight_number', ''))
    
    # Determinar estado del lanzamiento
    status = determine_launch_status(launch)
    
    # Procesar información del cohete
    rocket_info = launch.get('rocket', {})
    rocket_name = rocket_info.get('rocket_name', 'Unknown')
    
    # Procesar payloads
    payloads = process_payloads(launch.get('payloads', []))
    
    # Procesar launchpad
    launchpad = launch.get('launch_site', {})
    launchpad_name = launchpad.get('site_name_long', launchpad.get('site_name', 'Unknown'))
    
    # Crear el objeto con los datos procesados
    processed_data = {
        'launch_id': launch_id,
        'flight_number': launch.get('flight_number'),
        'mission_name': launch.get('mission_name', 'Unknown Mission'),
        'rocket_name': rocket_name,
        'launch_date': launch.get('launch_date_utc', ''),
        'launch_date_local': launch.get('launch_date_local', ''),
        'status': status,
        'launch_success': launch.get('launch_success'),
        'upcoming': launch.get('upcoming', False),
        'details': launch.get('details', ''),
        'rocket': {
            'rocket_id': rocket_info.get('rocket_id', ''),
            'rocket_name': rocket_info.get('rocket_name', ''),
            'rocket_type': rocket_info.get('rocket_type', '')
        },
        'payloads': payloads,
        'last_updated': datetime.now(timezone.utc).isoformat(),
        'api_version': 'v3'
    }
    
    # Convertir a formato compatible con DynamoDB (Decimal para números)
    return convert_to_dynamodb_format(processed_data)

def determine_launch_status(launch: Dict[str, Any]) -> str:
    """
    Determina el estado del lanzamiento basado en los datos disponibles
    """
    if launch.get('upcoming', False):
        return 'upcoming'
    elif launch.get('launch_success') is True:
        return 'success'
    elif launch.get('launch_success') is False:
        return 'failed'
    else:
        return 'unknown'

def process_payloads(payloads: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """
    Procesa la información de los payloads
    """
    processed_payloads = []
    
    for payload in payloads:
        processed_payload = {
            'payload_id': payload.get('payload_id', ''),
            'payload_type': payload.get('payload_type', ''),
            'payload_mass_kg': payload.get('payload_mass_kg'),
            'payload_mass_lbs': payload.get('payload_mass_lbs'),
            'orbit': payload.get('orbit', ''),
            'customers': payload.get('customers', []),
            'manufacturer': payload.get('manufacturer', ''),
            'nationality': payload.get('nationality', '')
        }
        processed_payloads.append(processed_payload)
    
    return processed_payloads

def convert_to_dynamodb_format(data: Dict[str, Any]) -> Dict[str, Any]:
    """
    Convierte datos a formato compatible con DynamoDB (float -> Decimal)
    """
    return json.loads(json.dumps(data, default=str), parse_float=Decimal)

def upsert_launch_to_dynamodb(launch_data: Dict[str, Any]) -> str:
    """
    Inserta o actualiza un lanzamiento en DynamoDB usando put_item
    Retorna 'created' o 'updated'
    """
    try:
        launch_id = launch_data['launch_id']
        
        # Verificar si el item existe
        try:
            response = table.get_item(Key={'launch_id': launch_id})
            item_exists = 'Item' in response
        except Exception as e:
            logger.error(f"Error verificando existencia del item {launch_id}: {str(e)}")
            item_exists = False
        
        # Usar put_item para insertar/actualizar
        table.put_item(Item=launch_data)
        
        result = 'updated' if item_exists else 'created'
        logger.info(f"Launch {launch_id} {result} successfully")
        
        return result
        
    except Exception as e:
        logger.error(f"Error guardando en DynamoDB: {str(e)}")
        raise

def create_response(status_code: int, body: Any) -> Dict[str, Any]:
    """
    Crea una respuesta HTTP estándar
    """
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
        },
        'body': json.dumps(body, default=str)
    }

def get_latest_launches_summary():
    """Obtener resumen de los últimos lanzamientos procesados"""
    try:
        response = table.scan(Limit=5)
        items = response.get('Items', [])
        
        # Ordenar por flight_number descendente
        sorted_items = sorted(items, 
                            key=lambda x: int(x.get('flight_number', 0)) if x.get('flight_number') else 0, 
                            reverse=True)
        
        summary = []
        for item in sorted_items[:5]:
            summary.append({
                'flight_number': str(item.get('flight_number', '')),
                'mission_name': item.get('mission_name', ''),
                'rocket_name': item.get('rocket_name', ''),
                'launch_date': item.get('launch_date', ''),
                'status': item.get('status', ''),
                'last_updated': item.get('last_updated', '')
            })
        
        return summary
        
    except Exception as e:
        logger.error(f"Error obteniendo resumen: {e}")
        return []

def get_table_stats():
    """Obtener estadísticas de la tabla DynamoDB"""
    try:
        response = table.scan()
        items = response.get('Items', [])
        
        stats = {
            'total_records': len(items),
            'by_status': {},
            'by_rocket': {}
        }
        
        for item in items:
            # Stats por status
            status = item.get('status', 'unknown')
            stats['by_status'][status] = stats['by_status'].get(status, 0) + 1
            
            # Stats por cohete
            rocket = item.get('rocket_name', 'Unknown')
            stats['by_rocket'][rocket] = stats['by_rocket'].get(rocket, 0) + 1
        
        return stats
        
    except Exception as e:
        logger.error(f"Error obteniendo stats: {e}")
        return {}

if __name__ == "__main__":
    # Evento de prueba simulado (ajusta según lo que quieras probar)
    test_event = {}
    test_context = None  # Contexto vacío para pruebas locales

    response = lambda_handler(test_event, test_context)
    print(json.dumps(response, indent=2))