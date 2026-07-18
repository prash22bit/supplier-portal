import json
import os
import boto3
import uuid
from datetime import datetime

dynamodb = boto3.resource('dynamodb')
s3_client = boto3.client('s3')

SUPPLIERS_TABLE = os.environ.get('SUPPLIERS_TABLE', 'suppliers')
DOCUMENTS_BUCKET = os.environ.get('DOCUMENTS_BUCKET', '')

def lambda_handler(event, context):
    """Generate a presigned URL for direct S3 upload."""
    try:
        http_method = event.get('httpMethod', 'POST')
        
        if http_method == 'POST':
            body = json.loads(event.get('body', '{}'))
            file_name = body.get('fileName', 'document.pdf')
            supplier_id = body.get('supplierId', 'unknown')
            doc_type = body.get('documentType', 'certificate')
            content_type = body.get('contentType', 'application/pdf')
            
            # Generate unique key
            doc_id = str(uuid.uuid4())
            s3_key = f"uploads/{supplier_id}/{doc_type}/{doc_id}/{file_name}"
            
            # Generate presigned URL (valid for 15 min)
            presigned_url = s3_client.generate_presigned_url(
                'put_object',
                Params={
                    'Bucket': DOCUMENTS_BUCKET,
                    'Key': s3_key,
                    'ContentType': content_type
                },
                ExpiresIn=900
            )
            
            return {
                'statusCode': 200,
                'headers': {
                    'Access-Control-Allow-Origin': '*',
                    'Content-Type': 'application/json'
                },
                'body': json.dumps({
                    'uploadUrl': presigned_url,
                    'documentId': doc_id,
                    's3Key': s3_key,
                    'supplierId': supplier_id,
                    'documentType': doc_type,
                    'message': 'Presigned URL generated successfully'
                })
            }
        
        return {
            'statusCode': 405,
            'headers': {'Access-Control-Allow-Origin': '*'},
            'body': json.dumps({'error': 'Method not allowed'})
        }
        
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {'Access-Control-Allow-Origin': '*'},
            'body': json.dumps({'error': str(e)})
        }
