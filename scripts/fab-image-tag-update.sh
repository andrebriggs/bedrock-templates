#!/bin/bash

set -e

if [ -z "$REPO_NAME" ]
then
    echo "No Repo name provided. Consider setting AZDO $(Build.Repository.Name) to REPO_NAME"
fi

if [ -z "$BRANCH_NAME" ]
then
    echo "No Branch name provided. Consider setting AZDO $(Build.SourceBranchName) to BRANCH_NAME"
fi

if [ -z "$BUILD_VERSION" ]
then
    echo "No Build version provided. Consider setting AZDO $(Build.BuildNumber) to BUILD_VERSION"
fi

if [ -z "$ACR_NAME" ]
then
    echo "No ACR name provided"
fi

if [ -z "$SERVICE_NAME" ]
then
    echo "No service name provided"
fi

export SERVICE_NAME_LOWER=$(echo $SERVICE_NAME | tr '[:upper:]' '[:lower:]')
export FAB_SAFE_SERVICE_NAME=$(echo $SERVICE_NAME_LOWER | tr . - | tr / -)

# Update HLD
git checkout -b "$BRANCH_NAME"
export BUILD_REPO_NAME=$(echo $REPO_NAME-$SERVICE_NAME | tr '[:upper:]' '[:lower:]')
export IMAGE_TAG=$(echo $BRANCH_NAME | tr / - | tr . - | tr _ - )-$BUILD_VERSION
export IMAGE_NAME=$BUILD_REPO_NAME:$IMAGE_TAG
echo "Image Name: $IMAGE_NAME"
export IMAGE_REPO=$(echo $ACR_NAME.azurecr.io | tr '[:upper:]' '[:lower:]')
echo "Image Repository: $IMAGE_REPO"
cd $(Build.Repository.Name)/$FAB_SAFE_SERVICE_NAME/$(echo $BRANCH_NAME | tr / - | tr . - | tr _ - )
echo "FAB SET"
fab set --subcomponent chart image.tag=$IMAGE_TAG image.repository=$IMAGE_REPO/$BUILD_REPO_NAME

# Set git identity
git config user.email "admin@azuredevops.com"
git config user.name "Automated Account"

# Commit changes
echo "GIT ADD and COMMIT -- Will throw error if there is nothing to commit."
git_commit_if_changes "Updating $SERVICE_NAME_LOWER image tag to $(echo $BRANCH_NAME | tr / - | tr . - | tr _ - )-$BUILD_VERSION)." 1 unusedVar

# Git Push
git_push

# Open PR via az repo cli
echo 'az extension add --name azure-devops'
az extension add --name azure-devops

echo 'az repos pr create --description "Updating $SERVICE_NAME_LOWER to $(echo $BRANCH_NAME | tr / - | tr . - | tr _ - )-$BUILD_VERSION." "PR created by: $(Build.DefinitionName) with buildId: $(Build.BuildId) and buildNumber: $(Build.BuildNumber)"'
response=$(az repos pr create --description "Updating $SERVICE_NAME_LOWER to $(echo $BRANCH_NAME | tr / - | tr . - | tr _ - )-$BUILD_VERSION.") #"PR created by: $(Build.DefinitionName) with buildId: $(Build.BuildId) and buildNumber: $(Build.BuildNumber)")
pr_id=$(echo $response | jq -r '.pullRequestId')