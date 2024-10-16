import json
import boto3
import psycopg2
import os
from datetime import datetime

# Initialize S3 client
s3 = boto3.client('s3')

# Environment variables for DB connection (set in Lambda)
DB_HOST = os.getenv('DB_HOST')
DB_NAME = os.getenv('DB_NAME')
DB_USER = os.getenv('DB_USER')
DB_PASSWORD = os.getenv('DB_PASSWORD')

# Bucket and file paths (assumes you are using multiple files for different providers)
S3_BUCKET = os.getenv('S3_BUCKET')

# Database connection function
def connect_db():
    conn = psycopg2.connect(
        host=DB_HOST,
        database=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD
    )
    return conn

def lambda_handler(event, context):
    data_to_store = []

    # Iterate over the files (S3 event provides bucket and object keys)
    for record in event['Records']:
        s3_bucket = record['s3']['bucket']['name']
        s3_key = record['s3']['object']['key']
        
        # Fetch the JSON file from S3
        try:
            response = s3.get_object(Bucket=s3_bucket, Key=s3_key)
            json_data = json.loads(response['Body'].read())

            # Extract provider name from the filename (or other metadata)
            provider_name = extract_provider_name(s3_key)

            # Extract relevant data (e.g., total available vehicles)
            for station in json_data['data']['stations']:
                available_vehicles = station.get('num_bikes_available', 0)  # Or relevant key
                station_id = station.get('station_id', 'unknown')
                timestamp = datetime.utcnow()

                # Append to list for bulk insert
                data_to_store.append((provider_name, station_id, available_vehicles, timestamp))

        except Exception as e:
            print(f"Error reading S3 object {s3_key}: {str(e)}")

    if data_to_store:
        # Insert data into RDS
        insert_into_db(data_to_store)

def extract_provider_name(s3_key):
    # You can infer provider name from the file path (adjust based on your naming convention)
    # Example: s3_key = 'providers/wienmobilerad/station_status.json'
    return s3_key.split('/')[1]  # Modify this depending on your structure

def insert_into_db(data):
    try:
        conn = connect_db()
        cursor = conn.cursor()

        # Insert query for historical data storage
        insert_query = """
            INSERT INTO vehicules (provider_name, station_id, available_vehicles, timestamp)
            VALUES (%s, %s, %s, %s)
        """

        cursor.executemany(insert_query, data)
        conn.commit()

        cursor.close()
        conn.close()

        print(f"Successfully inserted {len(data)} rows into the database.")

    except Exception as e:
        print(f"Error inserting data into database: {str(e)}")

