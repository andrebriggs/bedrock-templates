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

# Checks for changes and only commits if there are changes staged. Optionally can be configured to fail if called to commit and no changes are staged.
# First arg - commit message
# Second arg - "should error if there is nothing to commit" flag. Set to 0 if this behavior should be skipped and it will not error when there are no changes.
# Third arg - variable to check if changes were commited or not. Will be set to 1 if changes were made, 0 if not.
function git_commit_if_changes() {

    echo "GIT STATUS"
    git status

    echo "GIT ADD"
    git add -A

    commitSuccess=0
    if [[ $(git status --porcelain) ]] || [ -z "$2" ]; then
        echo "GIT COMMIT"
        git commit -m "$1"
        retVal=$?
        if [[ "$retVal" != "0" ]]; then
            echo "ERROR COMMITING CHANGES -- MAYBE: NO CHANGES STAGED"
            exit $retVal
        fi
        commitSuccess=1
    else
        echo "NOTHING TO COMMIT"
    fi
    echo "commitSuccess=$commitSuccess"
    printf -v $3 "$commitSuccess"
}

# Perform a Git push
function git_push() {
    # Remove http(s):// protocol from URL so we can insert PA token
    repo_url=$REPO
    repo_url="${repo_url#http://}"
    repo_url="${repo_url#https://}"

    echo "GIT PUSH: https://<ACCESS_TOKEN_SECRET>@$repo_url"
    git push "https://$ACCESS_TOKEN_SECRET@$repo_url"
    retVal=$? && [ $retVal -ne 0 ] && exit $retVal
    echo "GIT STATUS"
    git status
}

export SERVICE_NAME_LOWER=$(echo $SERVICE_NAME | tr '[:upper:]' '[:lower:]')
export FAB_SAFE_SERVICE_NAME=$(echo $SERVICE_NAME_LOWER | tr . - | tr / -)

# Update HLD
export BUILD_REPO_NAME=$(echo $REPO_NAME-$SERVICE_NAME | tr '[:upper:]' '[:lower:]')
export CHECKOUT_BRANCH_NAME=DEPLOY/$BUILD_REPO_NAME-$(echo $BRANCH_NAME | tr / - | tr . - | tr _ - )-$BUILD_VERSION
git checkout -b "$CHECKOUT_BRANCH_NAME"

export IMAGE_TAG=$(echo $BRANCH_NAME | tr / - | tr . - | tr _ - )-$BUILD_VERSION
export IMAGE_NAME=$BUILD_REPO_NAME:$IMAGE_TAG
echo "Image Name: $IMAGE_NAME"
export IMAGE_REPO=$(echo $ACR_NAME.azurecr.io | tr '[:upper:]' '[:lower:]')
echo "Image Repository: $IMAGE_REPO"

echo "Current dir $(pwd)"
FAB_LOCATION="$(pwd)/fab/fab"
ls -lt
cd ..
ls -lt

cd /home/vsts/$REPO_NAME/$FAB_SAFE_SERVICE_NAME/$FAB_SAFE_SERVICE_NAME/$(echo $BRANCH_NAME | tr / - | tr . - | tr _ - )
echo "FAB SET"
$FAB_LOCATION set --subcomponent chart image.tag=$IMAGE_TAG image.repository=$IMAGE_REPO/$BUILD_REPO_NAME

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