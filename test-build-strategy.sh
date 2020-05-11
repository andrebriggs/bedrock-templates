#!/bin/bash

AZP_POOL="Mypool"
export ACR_NAME="andrebriggs"
BUILD_ARG_YAML="AZP_POOL;ACR_NAME"
ACR_BUILD_COMMAND="az acr build -r $(ACR_NAME) --image $IMAGE_NAME ."
IFS=';' read -ra ADDR <<< "$BUILD_ARG_YAML"
for i in "${ADDR[@]}"; do
    # process "$i"
    ACR_BUILD_COMMAND="$ACR_BUILD_COMMAND --build-arg ${i}=${!i}"
done
echo $ACR_BUILD_COMMAND
echo $BUILD_ARG_YAML