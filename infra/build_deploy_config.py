#!/usr/bin/env python
"""
Build the Terraform deployment configuration files using environment variable values.
Requires a Google service account (but only to get the GCP project ID).
Auth0 Tenant Information is gathered from the secrets manager
"""
import os
import glob
import json
import boto3
import argparse
from google.cloud.storage import Client
GCP_PROJECT_ID = Client().project

infra_root = os.path.abspath(os.path.dirname(__file__))


def get_auth_tenant_config():
    sm_client = boto3.client("secretsmanager")
    secrets_store = os.environ['DDS_SECRETS_STORE']
    stage = os.environ['DDS_DEPLOYMENT_STAGE']
    auth_secret_name = os.environ['AUTH_TENANT_SECRET_NAME']
    secret_id = f'{secrets_store}/{stage}/{auth_secret_name}'
    try:
        resp = sm_client.get_secret_value(SecretID=secret_id)
    except sm_client.exceptions.ResourceNotFoundException:
        print(f'Unable to locate secret: {secret_id} in aws SSM, please inspect')
        exit(-1)
    else:
        return json.loads(resp['SecretString'])


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("component")
args = parser.parse_args()


terraform_variable_template = """
variable "{name}" {{
  default = "{val}"
}}
"""

terraform_backend_template = """# Auto-generated during infra build process.
# Please edit infra/build_deploy_config.py directly.
terraform {{
  backend "s3" {{
    bucket = "{bucket}"
    key = "{comp}-{stage}.tfstate"
    region = "{region}"
    {profile_setting}
  }}
}}
"""

terraform_providers_template = """# Auto-generated during infra build process.
# Please edit infra/build_deploy_config.py directly.
provider aws {{
  region = "{aws_region}"
}}

provider google {{
  project = "{gcp_project_id}"
}}

provider auth0 {{
    domain = "{tenant_domain_url}"
    client_id = "{tenant_client_id}"
    client_secret = "{tenant_client_secret}"
}}
"""

env_vars_to_infra = [
    "DSS_DEPLOYMENT_STAGE",
    "DSS_GCP_SERVICE_ACCOUNT_NAME",
    "DSS_INFRA_TAG_OWNER",
    "DSS_INFRA_TAG_PROJECT",
    "DSS_INFRA_TAG_SERVICE",
    "DSS_SECRETS_STORE",
    "GCP_DEFAULT_REGION",
]

with open(os.path.join(infra_root, args.component, "backend.tf"), "w") as fp:
    caller_info = boto3.client("sts").get_caller_identity()
    if os.environ.get('AWS_PROFILE'):
        profile = os.environ['AWS_PROFILE']
        profile_setting = f'profile = "{profile}"'
    else:
        profile_setting = ''
    fp.write(terraform_backend_template.format(
        bucket=os.environ['DSS_TERRAFORM_BACKEND_BUCKET_TEMPLATE'].format(account_id=caller_info['Account']),
        comp=args.component,
        stage=os.environ['DSS_DEPLOYMENT_STAGE'],
        region=os.environ['AWS_DEFAULT_REGION'],
        profile_setting=profile_setting,
    ))

with open(os.path.join(infra_root, args.component, "variables.tf"), "w") as fp:
    fp.write("# Auto-generated during infra build process." + os.linesep)
    fp.write("# Please edit infra/build_deploy_config.py directly." + os.linesep)
    for key in env_vars_to_infra:
        val = os.environ[key]
        fp.write(terraform_variable_template.format(name=key, val=val))

tenant_data = get_auth_tenant_config()
with open(os.path.join(infra_root, args.component, "providers.tf"), "w") as fp:
    fp.write(terraform_providers_template.format(
        aws_region=os.environ['AWS_DEFAULT_REGION'],
        gcp_project_id=GCP_PROJECT_ID,
        tenant_domain_url=tenant_data['tenant_domain_url'],
        tenant_client_id=tenant_data['tenant_client_id'],
        tenant_client_secret=tenant_data['tenant_client_secret']
    ))
