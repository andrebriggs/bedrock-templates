#!/bin/bash

# Initialize Helm
function helm_init() {
    echo "RUN HELM INIT"
    helm init --client-only
}

# Obtain version for Fabrikate
# If the version number is not provided, then download the latest
function get_fab_version() {
    # shellcheck disable=SC2153
    if [ -z "$VERSION" ]
    then
        # By default, the script will use the most recent non-prerelease, non-draft release Fabrikate
        VERSION_TO_DOWNLOAD=$(curl -s "https://api.github.com/repos/microsoft/fabrikate/releases/latest" | grep "tag_name" | sed -E 's/.*"([^"]+)".*/\1/')
    else
        echo "Fabrikate Version: $VERSION"
        VERSION_TO_DOWNLOAD=$VERSION
    fi
}

# Obtain OS to download the appropriate version of Fabrikate
function get_os() {
    if [[ "$OSTYPE" == "linux-gnu" ]]; then
        eval "$1='linux'"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        eval "$1='darwin'"
    elif [[ "$OSTYPE" == "msys" ]]; then
        eval "$1='windows'"
    else
        eval "$1='linux'"
    fi
}

# Download Fabrikate
function download_fab() {
    echo "DOWNLOADING FABRIKATE"
    echo "Latest Fabrikate Version: $VERSION_TO_DOWNLOAD"
    os=''
    get_os os
    fab_wget=$(wget -SO- "https://github.com/Microsoft/fabrikate/releases/download/$VERSION_TO_DOWNLOAD/fab-v$VERSION_TO_DOWNLOAD-$os-amd64.zip" 2>&1 | grep -E -i "302")
    if [[ $fab_wget == *"302 Found"* ]]; then
       echo "Fabrikate $VERSION_TO_DOWNLOAD downloaded successfully."
    else
        echo "There was an error when downloading Fabrikate. Please check version number and try again."
    fi
    wget "https://github.com/Microsoft/fabrikate/releases/download/$VERSION_TO_DOWNLOAD/fab-v$VERSION_TO_DOWNLOAD-$os-amd64.zip"
    unzip "fab-v$VERSION_TO_DOWNLOAD-$os-amd64.zip" -d fab

    export PATH=$PATH:$HOME/fab
}

helm_init
get_fab_version
download_fab
