#!/usr/bin/env bash

set -euo pipefail

if [[ -z $DSS_DEPLOYMENT_STAGE ]]; then
    echo 'Please run "source environment" in the data-store repo root directory before running this command'
    exit 1
fi

export stage=$DSS_DEPLOYMENT_STAGE
export dss_secrets_store=$DSS_SECRETS_STORE
deployed_json="$(dirname $0)/.chalice/deployed.json"
config_json="$(dirname $0)/.chalice/config.json"
policy_json="$(dirname $0)/.chalice/policy.json"
stage_policy_json="$(dirname $0)/.chalice/policy-${stage}.json"
export app_name=$(cat "$config_json" | jq -r .app_name)
iam_policy_template="$(dirname $0)/../iam/policy-templates/auth-proxy-lambda.json"
export lambda_name="${CHALICE_APP_NAME}"
export chalice_version=$(chalice --version)
export account_id=$(aws sts get-caller-identity | jq -r .Account)

cat "$config_json" | jq ".app_name=\"${CHALICE_APP_NAME}\" " | sponge "$config_json"
cat "$config_json" | jq ".stages.$stage.api_gateway_stage=env.stage" | sponge "$config_json"

export lambda_arn=$(aws lambda list-functions | jq -r '.Functions[] | select(.FunctionName==env.lambda_name) | .FunctionArn')
if [[ -z $lambda_arn ]]; then
    echo "Lambda function $lambda_name not found, resetting Chalice config"
    rm -f "$deployed_json"
else
    api_arn=$(aws lambda get-policy --function-name "$lambda_name" | jq -r .Policy | jq -r '.Statement[0].Condition.ArnLike["AWS:SourceArn"]')
    export api_id=$(echo "$api_arn" | cut -d ':' -f 6 | cut -d '/' -f 1)
    jq -n ".$stage.api_handler_name = env.lambda_name | \
           .$stage.api_handler_arn = env.lambda_arn | \
           .$stage.rest_api_id = env.api_id | \
           .$stage.region = env.AWS_DEFAULT_REGION | \
           .$stage.api_gateway_stage = env.stage | \
           .$stage.backend = \"api\" | \
           .$stage.chalice_version = env.chalice_version | \
           .$stage.lambda_functions = {}" > "$deployed_json"
fi

export DEPLOY_ORIGIN="$(whoami)-$(hostname)-$(git describe --tags --always)-$(date -u +'%Y-%m-%d-%H-%M-%S').deploy"
cat "$config_json" | jq ".stages.$stage.tags.DSS_DEPLOY_ORIGIN=\"$DEPLOY_ORIGIN\" | \
	.stages.$stage.tags.Name=\"${DSS_INFRA_TAG_PROJECT}-${DSS_INFRA_TAG_STAGE}-${DSS_INFRA_TAG_SERVICE}\" | \
	.stages.$stage.tags.service=\"${DSS_INFRA_TAG_SERVICE}\"  | \
	.stages.$stage.tags.project=\"$DSS_INFRA_TAG_PROJECT\" | \
	.stages.$stage.tags.owner=\"${DSS_INFRA_TAG_OWNER}\" | \
	.stages.$stage.tags.env=\"${DSS_INFRA_TAG_STAGE}\""  | sponge "$config_json"


for ENV_KEY in $EXPORT_ENV_VARS_TO_LAMBDA; do
	export env_val=$(printenv $ENV_KEY)
	cat "$config_json" | jq ".stages.$stage.environment_variables.$ENV_KEY=\"$env_val\"" |  sponge "$config_json"
done

if [[ ${CI:-} != true ]]; then
	# IAM policies must be updated from an operators machine, this will not run on CI environments.
	echo "Looking for IAM Role: $iam_role_arn"
	if ! aws iam get-role --role-name $lambda_name; then
		export trust_policy_path=${DSS_HOME}/iam/trust-relations/lambda.json
		aws iam create-role --role-name $lambda_name --path / --assume-role-policy-document file://$trust_policy_path
		echo "created IAM Role: $lambda_name, with trust policy from $trust_policy_path"
	fi
	echo "updating $iam_role_arn with $stage_policy_json"
	aws iam put-role-policy --role-name $lambda_name --policy-name $lambda_name --policy-document file://$stage_policy_json
fi


cat "$iam_policy_template" | envsubst '$DSS_MON_SECRETS_STORE $account_id $stage' > "$policy_json"
cp "$policy_json" "$stage_policy_json"
