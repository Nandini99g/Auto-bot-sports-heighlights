# app/s3_utils.py
import boto3
import os

def s3_client(region):
    return boto3.client("s3", region_name=region)

def upload_bytes(bucket, key, data_bytes, region):
    s3 = s3_client(region)
    s3.put_object(Bucket=bucket, Key=key, Body=data_bytes)

def upload_file(bucket, key, local_path, region):
    s3 = s3_client(region)
    s3.upload_file(local_path, bucket, key)

def list_objects(bucket, prefix, region):
    s3 = s3_client(region)
    paginator = s3.get_paginator("list_objects_v2")
    objs = []
    for page in paginator.paginate(Bucket=bucket, Prefix=prefix):
        for o in page.get("Contents", []):
            objs.append(o["Key"])
    return objs

def exists(bucket, key, region):
    s3 = s3_client(region)
    try:
        s3.head_object(Bucket=bucket, Key=key)
        return True
    except Exception:
        return False
