#!/bin/bash

# Authenticate with Git
function git_connect() {
    cd "$HOME"
    # Remove http(s):// protocol from URL so we can insert PA token
    repo_url=$REPO
    repo_url="${repo_url#http://}"
    repo_url="${repo_url#https://}"

    echo "GIT CLONE: https://automated:<ACCESS_TOKEN_SECRET>@$repo_url"
    git clone "https://automated:$ACCESS_TOKEN_SECRET@$repo_url"
    retVal=$? && [ $retVal -ne 0 ] && exit $retVal

    # Extract repo name from url
    repo_url=$REPO
    repo=${repo_url##*/}
    repo_name=${repo%.*}

    cd "$repo_name"
    echo "GIT PULL ORIGIN MASTER"
    git pull origin master
}