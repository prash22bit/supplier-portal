import json
import os
import boto3
from datetime import datetime, timedelta
from decimal import Decimal
from boto3.dynamodb.conditions import Attr

dynamodb = boto3.resource('dynamodb')

SUPPLIERS_TABLE = os.environ.get('SUPPLIERS_TABLE', '')
AUDIT_REPORTS_TABLE = os.environ.get('AUDIT_REPORTS_TABLE', '')
CERTS_TABLE = os.environ.get('CERTS_TABLE', '')

class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, Decimal):
            return float(obj)
        return super().default(obj)

def lambda_handler(event, context):
    """Return aggregated dashboard KPIs and recent activity."""
    try:
        # In production, these would be real DynamoDB queries
        # For demo, return meaningful mock data
        dashboard_data = {
            'kpis': {
                'totalSuppliers': 340,
                'activeSuppliers': 312,
                'complianceRate': 87.4,
                'pendingAudits': 23,
                'criticalAlerts': 5,
                'certsExpiringIn30Days': 12,
                'avgComplianceScore': 81.2,
                'auditCompletionRate': 94.1
            },
            'riskDistribution': {
                'low': 187,
                'medium': 98,
                'high': 27,
                'critical': 8
            },
            'recentAudits': [
                {'auditId': 'AUD-2024-041', 'supplierName': 'Tata AutoComp Systems',
                 'type': 'Annual ISO', 'date': '2024-04-12', 'score': 94, 'status': 'Completed'},
                {'auditId': 'AUD-2024-040', 'supplierName': 'Motherson Sumi',
                 'type': 'Process Audit', 'date': '2024-04-10', 'score': 82, 'status': 'Completed'},
                {'auditId': 'AUD-2024-039', 'supplierName': 'Rane Holdings',
                 'type': 'Compliance Audit', 'date': '2024-04-08', 'score': 61, 'status': 'Failed'},
                {'auditId': 'AUD-2024-038', 'supplierName': 'Bosch India',
                 'type': 'System Audit', 'date': '2024-04-05', 'score': 96, 'status': 'Completed'},
                {'auditId': 'AUD-2024-037', 'supplierName': 'Valeo India',
                 'type': 'Annual ISO', 'date': '2024-04-02', 'score': 88, 'status': 'Completed'},
            ],
            'expiringCertificates': [
                {'certId': 'CERT-001', 'supplierName': 'Rane Holdings',
                 'certType': 'ISO 9001:2015', 'expiryDate': '2024-05-15', 'daysLeft': 17},
                {'certId': 'CERT-002', 'supplierName': 'Lucas TVS',
                 'certType': 'IATF 16949', 'expiryDate': '2024-05-22', 'daysLeft': 24},
                {'certId': 'CERT-003', 'supplierName': 'Sundram Fasteners',
                 'certType': 'ISO 14001', 'expiryDate': '2024-05-30', 'daysLeft': 32},
            ],
            'scoreByState': [
                {'state': 'Maharashtra', 'avgScore': 88.2, 'supplierCount': 67},
                {'state': 'Tamil Nadu', 'avgScore': 85.7, 'supplierCount': 54},
                {'state': 'Karnataka', 'avgScore': 91.3, 'supplierCount': 43},
                {'state': 'Gujarat', 'avgScore': 79.4, 'supplierCount': 38},
                {'state': 'Haryana', 'avgScore': 83.1, 'supplierCount': 31},
                {'state': 'Rajasthan', 'avgScore': 76.8, 'supplierCount': 28},
            ],
            'monthlyTrend': [
                {'month': 'Nov 2023', 'avgScore': 78.4, 'auditsCompleted': 28},
                {'month': 'Dec 2023', 'avgScore': 79.1, 'auditsCompleted': 22},
                {'month': 'Jan 2024', 'avgScore': 80.2, 'auditsCompleted': 31},
                {'month': 'Feb 2024', 'avgScore': 79.8, 'auditsCompleted': 27},
                {'month': 'Mar 2024', 'avgScore': 81.5, 'auditsCompleted': 35},
                {'month': 'Apr 2024', 'avgScore': 81.2, 'auditsCompleted': 18},
            ],
            'categoryBreakdown': [
                {'category': 'Metal Components', 'count': 89, 'avgScore': 84.1},
                {'category': 'Plastics & Composites', 'count': 67, 'avgScore': 79.3},
                {'category': 'Electronics', 'count': 54, 'avgScore': 90.2},
                {'category': 'Rubber & Seals', 'count': 42, 'avgScore': 76.8},
                {'category': 'Fasteners', 'count': 38, 'avgScore': 82.4},
                {'category': 'Others', 'count': 50, 'avgScore': 81.0},
            ],
            'generatedAt': datetime.utcnow().isoformat()
        }
        
        return {
            'statusCode': 200,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Content-Type': 'application/json',
                'Cache-Control': 'max-age=300'
            },
            'body': json.dumps(dashboard_data, cls=DecimalEncoder)
        }
        
    except Exception as e:
        print(f"Dashboard error: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {'Access-Control-Allow-Origin': '*'},
            'body': json.dumps({'error': str(e)})
        }
