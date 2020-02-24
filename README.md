## DSS Auth Infra Repo

This repo is used to setup an Auth service for the [data-store](https://github.com/databiosphere/data-store).


Setup Steps

1. configure a tenant with Auth0
1. set the secret with the Auth0 Management API in the aws secret-store [Secret Setup](#Secret-Setup)
1. deploy infra -> sets up all the stuff. more here later. 



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

### Infra Deployment


