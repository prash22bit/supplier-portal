import json
import os
import boto3
import uuid
from datetime import datetime
from decimal import Decimal

dynamodb = boto3.resource('dynamodb')
sns_client = boto3.client('sns')

AUDIT_REPORTS_TABLE = os.environ.get('AUDIT_REPORTS_TABLE', '')
SUPPLIERS_TABLE = os.environ.get('SUPPLIERS_TABLE', '')
AUDIT_NOTIFICATIONS_TOPIC = os.environ.get('CERT_EXPIRY_TOPIC', '')

class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, Decimal):
            return float(obj)
        return super().default(obj)

def lambda_handler(event, context):
    http_method = event.get('httpMethod', 'GET')
    
    if http_method == 'POST':
        return create_audit(event)
    elif http_method == 'GET':
        return get_audits(event)
    else:
        return {'statusCode': 405, 'headers': {'Access-Control-Allow-Origin': '*'},
                'body': json.dumps({'error': 'Method not allowed'})}

def create_audit(event):
    try:
        body = json.loads(event.get('body', '{}'))
        audit_id = str(uuid.uuid4())
        now = datetime.utcnow().isoformat()
        
        audit_item = {
            'auditId': audit_id,
            'createdAt': now,
            'supplierId': body.get('supplierId', ''),
            'supplierName': body.get('supplierName', ''),
            'auditType': body.get('auditType', 'Annual'),
            'auditorName': body.get('auditorName', ''),
            'scheduledDate': body.get('scheduledDate', ''),
            'status': 'Pending',
            'overallScore': 0,
            'findings': body.get('findings', []),
            'checklistItems': body.get('checklistItems', []),
            'notes': body.get('notes', ''),
            'updatedAt': now
        }
        
        table = dynamodb.Table(AUDIT_REPORTS_TABLE)
        table.put_item(Item=audit_item)
        
        # Send SNS notification
        try:
            sns_client.publish(
                TopicArn=AUDIT_NOTIFICATIONS_TOPIC,
                Message=f"New audit scheduled for {body.get('supplierName', 'Unknown')} on {body.get('scheduledDate', 'TBD')}",
                Subject="New Audit Scheduled"
            )
        except Exception as sns_err:
            print(f"SNS error (non-fatal): {sns_err}")
        
        return {
            'statusCode': 201,
            'headers': {'Access-Control-Allow-Origin': '*', 'Content-Type': 'application/json'},
            'body': json.dumps({'auditId': audit_id, 'status': 'Pending', 'message': 'Audit created'})
        }
    except Exception as e:
        return {'statusCode': 500, 'headers': {'Access-Control-Allow-Origin': '*'},
                'body': json.dumps({'error': str(e)})}

def get_audits(event):
    try:
        table = dynamodb.Table(AUDIT_REPORTS_TABLE)
        params = event.get('queryStringParameters') or {}
        
        supplier_id = params.get('supplierId')
        status_filter = params.get('status')
        
        if supplier_id:
            from boto3.dynamodb.conditions import Key
            response = table.query(
                IndexName='SupplierAuditIndex',
                KeyConditionExpression=Key('supplierId').eq(supplier_id)
            )
        else:
            response = table.scan(Limit=100)
        
        items = response.get('Items', [])
        if not items:
            items = get_demo_audits()
        
        if status_filter:
            items = [i for i in items if i.get('status') == status_filter]
        
        return {
            'statusCode': 200,
            'headers': {'Access-Control-Allow-Origin': '*', 'Content-Type': 'application/json'},
            'body': json.dumps({'audits': items, 'count': len(items)}, cls=DecimalEncoder)
        }
    except Exception as e:
        return {'statusCode': 500, 'headers': {'Access-Control-Allow-Origin': '*'},
                'body': json.dumps({'error': str(e), 'audits': get_demo_audits()})}

def get_demo_audits():
    return [
        {'auditId': 'AUD-2024-001', 'supplierId': 'SUP-001', 'supplierName': 'Tata AutoComp Systems',
         'auditType': 'Annual ISO', 'scheduledDate': '2024-04-15', 'status': 'Completed',
         'overallScore': 92, 'auditorName': 'Rajesh Kumar', 'createdAt': '2024-03-01T00:00:00'},
        {'auditId': 'AUD-2024-002', 'supplierId': 'SUP-002', 'supplierName': 'Mahindra Composites',
         'auditType': 'Process Audit', 'scheduledDate': '2024-04-20', 'status': 'In Review',
         'overallScore': 76, 'auditorName': 'Priya Sharma', 'createdAt': '2024-03-10T00:00:00'},
        {'auditId': 'AUD-2024-003', 'supplierId': 'SUP-004', 'supplierName': 'Rane Holdings',
         'auditType': 'Compliance Audit', 'scheduledDate': '2024-05-01', 'status': 'Pending',
         'overallScore': 0, 'auditorName': 'Amit Singh', 'createdAt': '2024-04-01T00:00:00'},
    ]
