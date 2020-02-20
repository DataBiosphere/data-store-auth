## DSS Auth Infra Repo

This repo is used to setup an Auth service for the [data-store](https://github.com/databiosphere/data-store).

Setup Steps

1. configure a tenant with Auth0
1. set the secret with the tenant information in the aws secret-store [Secret Setup](#Secret-Setup)
1. deploy infra -> sets up all the stuff. more here later. 


### Terraform Installation

In order to deploy the infra in this repository, you will need to install Terraform and an Auth0 Terraform
provider. We use this Auth0 terraform provider: [alexkappa/terraform-provider-auth0](https://github.com/alexkappa/terraform-provider-auth0).

To install terraform, download the binary for your OS, unzip it to a directory on your path, and test it is available:

```
export TF_VERSION="0.12.16"
export OS=$(uname -s | tr '[:upper:]' '[:lower:]')
wget https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_${OS}_amd64.zip
unzip terraform_${TF_VERSION}_${OS}_amd64.zip -d ${HOME}/bin
export PATH="${HOME}/bin:${PATH}"
which terraform
```

To install the Auth0 provider for terraform, download the binary for your OS and add it to the Terraform plugins
directory:

```
export TF_AUTH0_VERSION="0.5.1"
export OS=$(uname -s | tr '[:upper:]' '[:lower:]')
export TF_PLUGINS_DIR="${HOME}/.terraform.d/plugins"
wget https://github.com/alexkappa/terraform-provider-auth0/releases/download/v${TF_AUTH0_VERSION}/terraform-provider-auth0_v${TF_AUTH0_VERSION}_${OS}_amd64.tar.gz
mkdir -p ${TF_PLUGINS_DIR} && tar xzf terraform-provider-auth0_v${TF_AUTH0_VERSION}_${OS}_amd64.tar.gz -C ${TF_PLUGINS_DIR}
```


### Python Installation

It is recommended that Python dependencies be installed into a virtual environment to avoid versioning conflicts.

To install all Python dependencies for this project:

```
pip install -r requirements.txt
```


### Secret Setup

In order to get the infra scripts setup correctly, some of the auth0 tenant data needs to be uploaded, here is an example:

`$DSS_AUTH_HOME/tenant_secrets.json`
```
"tenant_domain_url":"wassupdawg.auth0.com",
"tenant_client_id":"2333",
"tenant_client_secret": "666"
```
Then use the following command to set the secret within the aws secret manager
```
scripts/set_secret.py --secret-name $AUTH_TENANT_SECRET_NAME < $DSS_AUTH_HOME/tenant_secrets.json   
```

### Infra Deployment


