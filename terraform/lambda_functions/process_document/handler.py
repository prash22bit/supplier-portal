import json
import os
import boto3
from decimal import Decimal
from datetime import datetime

dynamodb = boto3.resource('dynamodb')
textract = boto3.client('textract')
comprehend = boto3.client('comprehend')
s3_client = boto3.client('s3')
sns_client = boto3.client('sns')

CERTS_TABLE = os.environ.get('CERTS_TABLE', '')
SUPPLIERS_TABLE = os.environ.get('SUPPLIERS_TABLE', '')
CERT_EXPIRY_TOPIC = os.environ.get('CERT_EXPIRY_TOPIC', '')

def lambda_handler(event, context):
    """Process uploaded document via Textract and Comprehend."""
    try:
        # S3 event trigger
        for record in event.get('Records', []):
            bucket = record['s3']['bucket']['name']
            key = record['s3']['object']['key']
            
            print(f"Processing document: s3://{bucket}/{key}")
            
            # Extract text using Textract
            textract_response = textract.detect_document_text(
                Document={'S3Object': {'Bucket': bucket, 'Name': key}}
            )
            
            # Get all text blocks
            full_text = ' '.join([
                block['Text'] 
                for block in textract_response.get('Blocks', [])
                if block['BlockType'] == 'LINE'
            ])
            
            print(f"Extracted text length: {len(full_text)}")
            
            # Analyze with Comprehend
            if full_text:
                entities_response = comprehend.detect_entities(
                    Text=full_text[:4900],  # Comprehend limit
                    LanguageCode='en'
                )
                
                key_phrases_response = comprehend.detect_key_phrases(
                    Text=full_text[:4900],
                    LanguageCode='en'
                )
                
                entities = entities_response.get('Entities', [])
                key_phrases = [kp['Text'] for kp in key_phrases_response.get('KeyPhrases', [])]
                
                # Extract certificate info from path
                # path format: uploads/{supplierId}/{docType}/{docId}/{fileName}
                path_parts = key.split('/')
                supplier_id = path_parts[1] if len(path_parts) > 1 else 'unknown'
                doc_type = path_parts[2] if len(path_parts) > 2 else 'certificate'
                doc_id = path_parts[3] if len(path_parts) > 3 else 'unknown'
                
                # Store processing result in DynamoDB
                certs_table = dynamodb.Table(CERTS_TABLE)
                
                item = {
                    'certId': doc_id,
                    'supplierId': supplier_id,
                    'certType': doc_type,
                    's3Bucket': bucket,
                    's3Key': key,
                    'fullText': full_text[:10000],
                    'entities': json.dumps(entities[:20]),
                    'keyPhrases': json.dumps(key_phrases[:20]),
                    'processingStatus': 'COMPLETED',
                    'processedAt': datetime.utcnow().isoformat(),
                    'expiryDate': '2026-12-31'  # Would be extracted via regex in production
                }
                
                certs_table.put_item(Item=item)
                print(f"Document processed and stored: {doc_id}")
        
        return {'statusCode': 200, 'body': 'Processing complete'}
        
    except Exception as e:
        print(f"Error processing document: {str(e)}")
        raise e
