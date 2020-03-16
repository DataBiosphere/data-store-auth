locals {
  common_tags = "${map(
    "project"   , "${var.DSS_INFRA_TAG_PROJECT}",
    "env"       , "${var.DSS_DEPLOYMENT_STAGE}",
    "service"   , "${var.DSS_INFRA_TAG_SERVICE}",
    "Name"      , "${var.DSS_INFRA_TAG_SERVICE}-auth",
    "owner"     , "${var.DSS_INFRA_TAG_OWNER}",
    "managedBy" , "terraform"
  )}"
}

resource "auth0_resource_server" "dev_api_resource_server" {
  name        = "Redwood Dev Resource Server"
  identifier  = var.OIDC_AUDIENCE
  signing_alg = "RS256"

  allow_offline_access                            = true
  token_lifetime                                  = 8600
  skip_consent_for_verifiable_first_party_clients = true
}

resource "auth0_client" "dss_auth" {
  name = "data-store-auth"
  description = "simple auth system for the data-store; managed by Terraform"
  app_type = "regular_web"
  is_first_party = true
  is_token_endpoint_ip_header_trusted = true
  token_endpoint_auth_method = "client_secret_post"
  oidc_conformant = true
  callbacks = [ "http://localhost:8080", "https://dss.dev.ucsc-cgp-redwood.org/internal/echo" ]
  allowed_origins = [ "http://localhost:8080" ]
  grant_types = [ "authorization_code", "refresh_token" ]


  jwt_configuration {
    lifetime_in_seconds = 300
    secret_encoded = true
    alg = "RS256"
    scopes = {
      foo = "bar"
      # this has to be updated at a later time
    }
  }
  client_metadata = local.common_tags
}

resource "auth0_connection" "google_connector" {
  # tie this into google provider for IdP at a later time
  # need to sort out domain ownership....
  name = "google"
  strategy = "google-oauth2"
  enabled_clients = ["${auth0_client.dss_auth.client_id}"]
}

resource "auth0_rule" "custom_claim" {
  name = "jwt-claim-from-domain"
  // this script might need to be migrated out of this and into the build script....
  script = <<EOF
function (user, context, callback) {
    var privileged_domains = ["ucsc.edu","platform-hca.iam.gserviceaccount.com"]; //authorized domains
    var domain = user.email.split('@').pop();
    const namespace = "${var.OIDC_AUDIENCE}";
    var userHasAccess = privileged_domains.some(
      function (email) {
        return email === domain;
      });

    context.accessToken[namespace + 'email']= user.email;
    context.accessToken[namespace + 'auth0'] = {
 		groups : user.groups,
 		roles: user.roles,
 		permissions: user.permissions
    };

    if (userHasAccess) {
      context.accessToken[namespace + 'group'] = 'dbio';
    } else {
      context.accessToken[namespace + 'group'] = 'public';
    }

    callback(null, user, context);
}
EOF
  enabled = true
}


resource "auth0_tenant" "tenant" {
  default_audience  = var.OIDC_AUDIENCE
  friendly_name = "${var.DSS_PLATFORM}-${var.DSS_DEPLOYMENT_STAGE}"
  support_email = var.DSS_INFRA_TAG_OWNER
  flags {
    change_pwd_flow_v1 = false
    disable_clickjack_protection_headers = true
    enable_apis_section = false
    enable_client_connections = false
    enable_custom_domain_in_emails = false
    enable_dynamic_client_registration = false
    enable_legacy_logs_search_v2 = false
    enable_pipeline2 = false
    enable_public_signup_user_exists_error = true
    universal_login = false
  }
}


output "dss_application_secrets" {
  value = {
    "installed"= {
    "auth_uri" = "${var.OPENID_PROVIDER}authorize",
    "token_uri"= "${var.OPENID_PROVIDER}oauth/token",
    "client_id"= auth0_client.dss_auth.client_id,
    "client_secret"= auth0_client.dss_auth.client_secret,
    "redirect_uris"= ["urn:ietf:wg:oauth:2.0:oob", "http://localhost:8080"]
    }
  }
}

output "dss_env_vars" {
  value = <<EOF
# Warning back slashes are sensitive here
OIDC_AUDIENCE="${var.OIDC_AUDIENCE}"
AUTH_URL="${var.AUTH_URL}"
OPENID_PROVIDER="${var.OPENID_PROVIDER}"
OIDC_EMAIL_CLAIM="${var.OIDC_AUDIENCE}email"
OIDC_GROUP_CLAIM="${var.OIDC_AUDIENCE}group"
EOF
}
