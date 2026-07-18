import json
import os
import boto3
from boto3.dynamodb.conditions import Key, Attr
from decimal import Decimal

dynamodb = boto3.resource('dynamodb')
SUPPLIERS_TABLE = os.environ.get('SUPPLIERS_TABLE', '')

class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, Decimal):
            return float(obj)
        return super().default(obj)

def lambda_handler(event, context):
    """Get list of suppliers with optional filtering."""
    try:
        table = dynamodb.Table(SUPPLIERS_TABLE)
        query_params = event.get('queryStringParameters') or {}
        
        state_filter = query_params.get('state')
        category_filter = query_params.get('category')
        status_filter = query_params.get('status')
        limit = int(query_params.get('limit', 50))
        
        if state_filter:
            response = table.query(
                IndexName='StateIndex',
                KeyConditionExpression=Key('state').eq(state_filter),
                Limit=limit
            )
        elif category_filter:
            response = table.query(
                IndexName='CategoryIndex',
                KeyConditionExpression=Key('category').eq(category_filter),
                Limit=limit
            )
        else:
            response = table.scan(Limit=limit)
        
        items = response.get('Items', [])
        
        # If table is empty, return demo data
        if not items:
            items = get_demo_suppliers()
        
        return {
            'statusCode': 200,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Content-Type': 'application/json'
            },
            'body': json.dumps({
                'suppliers': items,
                'count': len(items),
                'scannedCount': response.get('ScannedCount', len(items))
            }, cls=DecimalEncoder)
        }
        
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {'Access-Control-Allow-Origin': '*'},
            'body': json.dumps({'error': str(e), 'suppliers': get_demo_suppliers()})
        }

def get_demo_suppliers():
    return [
        {
            'supplierId': 'SUP-001', 'companyName': 'Tata AutoComp Systems',
            'state': 'Maharashtra', 'category': 'Metal Components',
            'complianceScore': 92, 'status': 'Active', 'riskLevel': 'Low',
            'lastAuditDate': '2024-03-15', 'certCount': 5
        },
        {
            'supplierId': 'SUP-002', 'companyName': 'Mahindra Composites',
            'state': 'Tamil Nadu', 'category': 'Plastics & Composites',
            'complianceScore': 78, 'status': 'Active', 'riskLevel': 'Medium',
            'lastAuditDate': '2024-02-28', 'certCount': 3
        },
        {
            'supplierId': 'SUP-003', 'companyName': 'Bosch India Electronics',
            'state': 'Karnataka', 'category': 'Electronics',
            'complianceScore': 96, 'status': 'Active', 'riskLevel': 'Low',
            'lastAuditDate': '2024-04-01', 'certCount': 7
        },
        {
            'supplierId': 'SUP-004', 'companyName': 'Rane Holdings',
            'state': 'Tamil Nadu', 'category': 'Steering Systems',
            'complianceScore': 65, 'status': 'Watch', 'riskLevel': 'High',
            'lastAuditDate': '2024-01-15', 'certCount': 2
        },
        {
            'supplierId': 'SUP-005', 'companyName': 'Sundaram-Clayton',
            'state': 'Tamil Nadu', 'category': 'Die Casting',
            'complianceScore': 88, 'status': 'Active', 'riskLevel': 'Low',
            'lastAuditDate': '2024-03-22', 'certCount': 4
        }
    ]
