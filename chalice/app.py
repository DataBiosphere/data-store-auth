import logging
import chalice
import os
import sys
import json

pkg_root = os.path.abspath(os.path.join(os.path.dirname(__file__), 'chalicelib'))  # noqa
sys.path.insert(0, pkg_root)  # noqa

import auth
from auth import util


logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

stage = os.getenv('DSS_DEPLOYMENT_STAGE')
app = chalice.Chalice(app_name=f"auth0-proxy-{stage}")
app.log.setLevel(logging.DEBUG)


@app.route('/', methods=['GET'])
def index():
    logger.info(dict(status='OK'))
    return chalice.Response(body='OK',
                            headers={"Content-Type": "text/plain"},
                            status_code=200)

@app.route('/internal/login')
def login():
    """DSS Auth Integration: used to initiate login functionality for swagger interaction"""
    application_secret_file = os.environ["GOOGLE_APPLICATION_SECRETS"]

    with open(application_secret_file, 'r') as fh:
        application_secrets = json.loads(fh.read())
    query_params = dict(audience=Config.get_audience(),
                        client_id=util._deep_get(application_secrets, ['installed', 'client_id']),
                        client_secrets=util._deep_get(application_secrets, ['installed', 'client_secrets']),
                        redirect_uri=f'https://{Config.get_api_domain_name()}/internal/cb',
                        response_type='code',
                        scope='openid email profile')
    # URL builder here
    auth_url = UrlBuilder(url=Config.get_authz_url()).set(path='authorize')
    for k, v in query_params.items():
        auth_url.add_query(query_name=k, query_value=v)
    return chalice.Response(status_code=302, body='', headers=dict(Location=str(auth_url)))
