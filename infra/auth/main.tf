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
  identifier  = "https://dev.ucsc-cgp-redwood.org/"
  signing_alg = "RS256"

  allow_offline_access                            = true
  token_lifetime                                  = 8600
  skip_consent_for_verifiable_first_party_clients = true
}

resource "auth0_client" "dss_auth" {
  name = "data-store-auth"
  description = "simple auth system for the data-store"
  app_type = "regular_web"
  is_first_party = true
  is_token_endpoint_ip_header_trusted = true
  token_endpoint_auth_method = "client_secret_post"
  oidc_conformant = true
  callbacks = [ "https://example.com/callback", "http://localhost:8080" ]
  allowed_origins = [ "http://localhost:8080" ]
  grant_types = [ "authorization_code", "refresh_token" ]
  allowed_logout_urls = [ "https://example.com" ]
  web_origins = [ "https://example.com" ]
  jwt_configuration {
    lifetime_in_seconds = 300
    secret_encoded = true
    alg = "RS256"
    scopes = {
      foo = "bar"
      # this might need to be
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

    context.accessToken[namespace + '/email']= user.email;

    if (userHasAccess) {
      context.accessToken[namespace + '/group'] = 'dbio';
    } else {
      context.accessToken[namespace + '/group'] = 'public';
    }
    callback(null, user, context);
}
EOF
  enabled = true
}

output  "google-connector" {
  # these values are need to setup social login on google...
  sensitive = true
  value = [
    "${auth0_connection.google_connector}"]
}
