import unittest
from unittest.mock import patch, MagicMock
import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '../src/lambda')))
from lambda_function import (
    lambda_handler,
    process_launch_data,
    determine_launch_status,
    upsert_launch_to_dynamodb,
)

class TestLambdaFunction(unittest.TestCase):
    @patch("lambda_function.fetch_spacex_launches")
    @patch("lambda_function.process_and_save_launches")
    def test_lambda_handler_success(self, mock_process_and_save, mock_fetch_launches):
        # Simula datos de la API y resultado del procesamiento
        mock_fetch_launches.return_value = [{"flight_number": 1}]
        mock_process_and_save.return_value = {"processed": 1, "created": 1, "updated": 0, "errors": 0}

        event = {}
        context = None
        response = lambda_handler(event, context)

        self.assertEqual(response["statusCode"], 200)
        self.assertIn("Procesamiento exitoso", response["body"])

    @patch("lambda_function.fetch_spacex_launches")
    def test_lambda_handler_api_error(self, mock_fetch_launches):
        # Simula error al obtener datos de la API
        mock_fetch_launches.return_value = []

        event = {}
        context = None
        response = lambda_handler(event, context)

        self.assertEqual(response["statusCode"], 500)
        self.assertIn("Error obteniendo datos de SpaceX", response["body"])

    def test_process_launch_data_parsing(self):
        launch = {
            "flight_number": 42,
            "mission_name": "Test Mission",
            "rocket": {"rocket_name": "Falcon 9"},
            "launch_date_utc": "2020-01-01T00:00:00Z",
            "launch_success": True,
            "upcoming": False,
            "payloads": [],
            "launch_site": {"site_name": "CCAFS", "site_name_long": "Cape Canaveral"},
        }
        result = process_launch_data(launch)
        self.assertEqual(result["launch_id"], "42")
        self.assertEqual(result["mission_name"], "Test Mission")
        self.assertEqual(result["rocket_name"], "Falcon 9")
        self.assertEqual(result["status"], "success")

    def test_determine_launch_status(self):
        self.assertEqual(determine_launch_status({"upcoming": True}), "upcoming")
        self.assertEqual(determine_launch_status({"launch_success": True}), "success")
        self.assertEqual(determine_launch_status({"launch_success": False}), "failed")
        self.assertEqual(determine_launch_status({}), "unknown")

    @patch("lambda_function.table")
    def test_upsert_launch_to_dynamodb_created(self, mock_table):
        # Simula que el item no existe
        mock_table.get_item.return_value = {}
        mock_table.put_item.return_value = {}
        launch_data = {"launch_id": "99"}
        result = upsert_launch_to_dynamodb(launch_data)
        self.assertEqual(result, "created")

    @patch("lambda_function.table")
    def test_upsert_launch_to_dynamodb_updated(self, mock_table):
        # Simula que el item sí existe
        mock_table.get_item.return_value = {"Item": {"launch_id": "99"}}
        mock_table.put_item.return_value = {}
        launch_data = {"launch_id": "99"}
        result = upsert_launch_to_dynamodb(launch_data)
        self.assertEqual(result, "updated")

    @patch("lambda_function.table")
    def test_upsert_launch_to_dynamodb_error(self, mock_table):
        # Simula error en put_item
        mock_table.get_item.return_value = {}
        mock_table.put_item.side_effect = Exception("Dynamo error")
        with self.assertRaises(Exception):
            upsert_launch_to_dynamodb({"launch_id": "error"})

if __name__ == "__main__":
    unittest.main()