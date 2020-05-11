#!/bin/bash

if [ -z "$IMAGE_TAG" ]
then
    echo "No ImageTag provided"
    export IMAGE_TAG=$(echo $(Build.BuildNumber) | tr / - | tr . - | tr _ - )
else
    echo "ImageTag is NOT empty"
    export IMAGE_TAG=$(echo $IMAGE_TAG | tr / - | tr . - | tr _ - )
fi
export BUILD_REPO_NAME=$(echo $BUILD_REPO_NAME | tr '[:upper:]' '[:lower:]')
export IMAGE_NAME=$BUILD_REPO_NAME:$IMAGE_TAG
export ACR_NAME=$ACR_NAME
echo "BUILD_ARG_YAML: $BUILD_ARG_YAML"

ACR_BUILD_COMMAND="az acr build -r $ACR_NAME --image $IMAGE_NAME ."
IFS=';' read -ra ARGS <<< "$BUILD_ARG_YAML"
for i in "${ARGS[@]}"; do
    ACR_BUILD_COMMAND="$ACR_BUILD_COMMAND --build-arg ${i}=${!i}"
done

echo "Command to run: $ACR_BUILD_COMMAND"
