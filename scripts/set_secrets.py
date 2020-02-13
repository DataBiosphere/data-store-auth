#!/usr/bin/env python
import os
import sys
import boto3
import select
import argparse


sm_client = boto3.client('secretsmanager')
secrets_store = os.environ['DSS_SECRETS_STORE']
stage = os.environ['DSS_DEPLOYMENT_STAGE']


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--secret-name", required=True)
parser.add_argument("--secret-value")
args = parser.parse_args()


secret_id = f'{secrets_store}/{stage}/{args.secret_name}'


if args.secret_value:
    val = args.secret_value
elif select.select([sys.stdin,],[],[],0.0)[0]:
    val = sys.stdin.read()
else:
    print(f"No data in stdin. Did you mean to use '--secret-value'?")
    print(f"Exiting without setting {secret_id}")
    sys.exit()


try:
    resp = sm_client.get_secret_value(
        SecretId=secret_id
    )
except sm_client.exceptions.ResourceNotFoundException:
    resp = sm_client.create_secret(
        Name=secret_id,
        SecretString=val
    )
else:
    resp = sm_client.update_secret(
        SecretId=secret_id,
        SecretString=val
    )
