## DSS Auth Infra Repo

This repo is used to setup an Auth service for the [data-store](https://github.com/databiosphere/data-store).

Auth0 provides a resource server that is used for Auth service requests, enabling certain users to perform protected actions.
The Auth server client is connected into Google IdProvider as a social identity provider. JWT's are populated with custom
OIDC_Claims (email / group) to indicate additional information to the resource-server for access control.

### Setup/Deploy Steps

1. Install Terraform provider: [see info below](#Terraform-Installation) 
1. Configure a tenant with Auth0
1. Update `$DSS_AUTH_HOME/environment` values with information from Tenant
1. Set the secret with the Auth0 Management API in the aws secret-store [Secret Setup](#Secret-Setup)
1. Run `make deploy-infra`
1. Setup google-IdP: see auth0 documentation [here](https://auth0.com/docs/connections/social/google)
1. Update DSS environment values and use the outputted application_secret within the data-store

### Fine-Grained Access Control
The data-store uses the auth0 authorization extension to add in `groups`, `permissions`, and `roles` information within the JWT.

1. Enable the extension on the tenant using the following [guide](https://auth0.com/docs/extensions/authorization-extension/v2)
1. Configure the extension rule with the following [guide](https://auth0.com/docs/extensions/authorization-extension/v2/implementation/configuration)
1. Within the rules, move the `auth0-authorization-extension` rule above the `jwt-claim-from-domain` rule within the Rules page.

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
The `tentant_client_id` and `tenant_client_secret` can be found by creating an `Auth0 Management API`, then into the
Application settings for the `API Exploration Application`**** 

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

### Updating Requirements

The file `requirements.txt.in` contains a short list of less strict version requirements. These are resolved and
the specific version numbers for all software dpeendencies are pinned in `requirements.txt`.

To update the requirements file `requirements.txt` from `requirements.txt.in`, use the `refresh_all_requirements` make rule:

```
make refresh_all_requirements
```

