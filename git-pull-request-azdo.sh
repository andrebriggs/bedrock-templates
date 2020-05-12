#!/bin/bash

# Open PR via az repo cli
echo 'az extension add --name azure-devops'
az extension add --name azure-devops

echo 'az repos pr create --description "Updating $SERVICE_NAME_LOWER to $(echo $(Build.SourceBranchName) | tr / - | tr . - | tr _ - )-$(Build.BuildNumber)." "PR created by: $(Build.DefinitionName) with buildId: $(Build.BuildId) and buildNumber: $(Build.BuildNumber)"'
response=$(az repos pr create --description "Updating $SERVICE_NAME_LOWER to $(echo $(Build.SourceBranchName) | tr / - | tr . - | tr _ - )-$(Build.BuildNumber)." "PR created by: $(Build.DefinitionName) with buildId: $(Build.BuildId) and buildNumber: $(Build.BuildNumber)")
pr_id=$(echo $response | jq -r '.pullRequestId')


# Skip introspection for now


# Update introspection storage with this information, if applicable
# if [ -z "$(INTROSPECTION_ACCOUNT_NAME)" -o -z "$(INTROSPECTION_ACCOUNT_KEY)" -o -z "$(INTROSPECTION_TABLE_NAME)" -o -z "$(INTROSPECTION_PARTITION_KEY)" ]; then
# echo "Introspection variables are not defined. Skipping..."
# else
# latest_commit=$(git rev-parse --short HEAD)
# tag_name="$BUILD_REPO_NAME:$(Build.SourceBranchName)-$(Build.BuildNumber)"
# url=$(git remote --verbose | grep origin | grep fetch | cut -f2 | cut -d' ' -f1)
# repourl=${url##*@}
# get_bedrock_version
# download_bedrock
# ./bedrock/bedrock deployment create  -n $(INTROSPECTION_ACCOUNT_NAME) -k $(INTROSPECTION_ACCOUNT_KEY) -t $(INTROSPECTION_TABLE_NAME) -p $(INTROSPECTION_PARTITION_KEY) --p2 $(Build.BuildId) --hld-commit-id $latest_commit --env $(Build.SourceBranchName) --image-tag $tag_name --pr $pr_id --repository $repourl
# fi