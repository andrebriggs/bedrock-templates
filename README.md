# Templating the `bedrock-cli`

This repository contains a proposal around pipeline generation for the [bedrock-cli](https://github.com/microsoft/bedrock-cli). Inspired by my post [here](https://github.com/microsoft/bedrock/issues/1006#issuecomment-592771163).

## Problem

Customers are on their own between AKS (infra creation) and Azure Devops (orchestration). The Bedrock CLI is a tool that provides solutions for automating deployments on to AKS.

Some customers don't want to use Bedrock CLI because:

* They don't want or need to use Fabrikate with their current scenario.
  * Fabrikate might be too advanced for their current needs
* They have to make several changes to `bedrock` generated pipelines
  * Want something more templated that allows customization
* `bedrock` can not anticpate all needs in GitOps scenarios upfront

## Proposal

This repo contains a proof of concept of what `bedrock` could be doing instead. Simplify what `bedrock` cli generates. Push logic into Azure DevOps Templates to allow customization of business logic in templates and scripts

The reason for this is to make `bedrock` pipeline generation less rigid. Instead we can focus on composition and encapsulation. This unlocks several benefits:

* Business logic specific data and functions are packaged
* More definition of what components need (via parameters)
* More logic reuse
* Separation of concerns
  
## Scenarios

__GitOps pipeline using High Level Definition repo and Fabrikate__: The default scenario `bedrock` provides has the user calling `bedrock service create` and `bedrock service install-build-pipeline` to install the pipeline to AzDO and build a Docker image, push to ACR, and update a HLD repo using Fabrikate.

__GitOps pipeline with Fabrikate__:Consider a user who doesn't want to use Fabrikate for any variety of reasons. The user specifies a pre-canned template such as `helm-gitops`. This template generates a pipeline for Docker build/push but instead of having Fabrikate being called on a HLD repo it will modify a Helm chart then call `helm template` to generate yaml manifests. These yaml manifest can be saved in a "manifest" repository. A user has a GitOps pipeline using only Helm.

__Not using ACR__: Another scenario builds on top of the previous two examples but instead of pushing to an Azure Container Registry we can push the built Docker image to DockerHub or any other Docker registry.

__Bedrock in private networks__: Customers who don't want to download external packages outside of their private network but want to take advantage of Bedrock style deployment. We've thought about these story of scenarios from the [build agent](https://github.com/andrebriggs/bedrock-agents) side but a complete solution requires generated pipelines from `bedrock` to be aware. Such a solution would require confuguration that can be easily manipulated with minimal changes to the the Bedrock CLI. If we provide switches to turn on and off certain pieces of logic (i.e. don't download Fabrikate) we can make these sort of scenario easier to acheive to for customers. These switches are just conditionals in the in the templated AzDO yaml.

## How it would work

The use of templates is applicable to any AzDO pipeline that `bedrock` generates. In this repository example we simulate calling `bedrock service create` which creates a `build-update-hld.yaml` file.

Consider the `azure-pipelines.yml` files in thie repository has a new version of the `build-update-hld.yaml` file. The `azure-pipelines.yml` references templates yaml files that in turn reference bash scripts:

`azure-pipelines.yml` --> `templates/*` --> `scripts/*`

The *templates* and *scripts* directories can be copied locally to the [project](https://microsoft.github.io/bedrock-cli/commands/#master@project_init) level of bedrock scaffolded service. Alternatively Azure DevOps Yaml templates __can be referenced from other repositories__. This is very powerful because it allows the Bedrock repo to store these default templates or users can choose to copy the templates to their own repository.

The vision here is that users can __extend__ the logic `bedrock` sets up for them. We are enabling a library of GitOps AZDO templates and scripts that the community can extend.

## Testing

* With so much logic pushed down into bash scripts that are based on ENV VARs, it becomes easier to test building blocks of logic.
* We will rely more on integration tests since the solution space has exploded compared to the hardcoded paths of the current CLI
* The templatizing makes it easier for someone to take what we are doing and massage it to their needs. The current model doesn't invite people to change what has been scaffolding

## Appendix

### Current `bedrock service create` yaml

```yaml
# GENERATED WITH BEDROCK VERSION 0.6.5
trigger:
  branches:
    include:
      - master
variables:
  - group: quick-start-vg
stages:
  - stage: build
    jobs:
      - job: run_build_push_acr
        pool:
          vmImage: ubuntu-latest
        steps:
          - task: HelmInstaller@1
            inputs:
              helmVersionToInstall: 2.16.3
          - script: |-
              set -e
              echo "az login --service-principal --username $(SP_APP_ID) --password $(SP_PASS) --tenant $(SP_TENANT)"
              az login --service-principal --username "$(SP_APP_ID)" --password "$(SP_PASS)" --tenant "$(SP_TENANT)"
            displayName: Azure Login
          - script: |-
              set -e
              # Download build.sh
              curl $BEDROCK_BUILD_SCRIPT > build.sh
              chmod +x ./build.sh
            displayName: Download bedrock bash scripts
            env:
              BEDROCK_BUILD_SCRIPT: $(BUILD_SCRIPT_URL)
          - script: |-
              set -e
              . ./build.sh --source-only
              get_bedrock_version
              download_bedrock
              export BUILD_REPO_NAME=$(echo $(Build.Repository.Name)-quick-start-app | tr '[:upper:]' '[:lower:]')
              tag_name="$BUILD_REPO_NAME:$(echo $(Build.SourceBranchName) | tr / - | tr . - | tr _ - )-$(Build.BuildNumber)"
              commitId=$(Build.SourceVersion)
              commitId=$(echo "${commitId:0:7}")
              service=$(./bedrock/bedrock service get-display-name -p ./)
              url=$(git remote --verbose | grep origin | grep fetch | cut -f2 | cut -d' ' -f1)
              repourl=${url##*@}
              ./bedrock/bedrock deployment create -n $(INTROSPECTION_ACCOUNT_NAME) -k $(INTROSPECTION_ACCOUNT_KEY) -t $(INTROSPECTION_TABLE_NAME) -p $(INTROSPECTION_PARTITION_KEY) --p1 $(Build.BuildId) --image-tag $tag_name --commit-id $commitId --service $service --repository $repourl
            displayName: 'If configured, update Spektate storage with build pipeline'
            condition: 'and(ne(variables[''INTROSPECTION_ACCOUNT_NAME''], ''''), ne(variables[''INTROSPECTION_ACCOUNT_KEY''], ''''),ne(variables[''INTROSPECTION_TABLE_NAME''], ''''),ne(variables[''INTROSPECTION_PARTITION_KEY''], ''''))'
          - script: |-
              set -e
              export BUILD_REPO_NAME=$(echo $(Build.Repository.Name)-quick-start-app | tr '[:upper:]' '[:lower:]')
              export IMAGE_TAG=$(echo $(Build.SourceBranchName) | tr / - | tr . - | tr _ - )-$(Build.BuildNumber)
              export IMAGE_NAME=$BUILD_REPO_NAME:$IMAGE_TAG
              echo "Image Name: $IMAGE_NAME"
              ACR_BUILD_COMMAND="az acr build -r $(ACR_NAME) --image $IMAGE_NAME ."

              echo "Exporting build variables from variable groups, if available: "
              echo "Build Variables: "

              cd ./
              echo "ACR BUILD COMMAND: $ACR_BUILD_COMMAND"
              $ACR_BUILD_COMMAND
            displayName: ACR Build and Publish
  - stage: hld_update
    dependsOn: build
    condition: succeeded('build')
    jobs:
      - job: update_image_tag
        pool:
          vmImage: ubuntu-latest
        steps:
          - task: HelmInstaller@1
            inputs:
              helmVersionToInstall: 2.16.3
          - script: |-
              set -e
              # Download build.sh
              curl $BEDROCK_BUILD_SCRIPT > build.sh
              chmod +x ./build.sh
            displayName: Download bedrock bash scripts
            env:
              BEDROCK_BUILD_SCRIPT: $(BUILD_SCRIPT_URL)
          - script: |-
              set -e
              export SERVICE_NAME_LOWER=$(echo quick-start-app | tr '[:upper:]' '[:lower:]')
              export BUILD_REPO_NAME=$(echo $(Build.Repository.Name)-quick-start-app | tr '[:upper:]' '[:lower:]')
              export BRANCH_NAME=DEPLOY/$BUILD_REPO_NAME-$(echo $(Build.SourceBranchName) | tr / - | tr . - | tr _ - )-$(Build.BuildNumber)
              export FAB_SAFE_SERVICE_NAME=$(echo $SERVICE_NAME_LOWER | tr . - | tr / -)
              # --- From https://raw.githubusercontent.com/Microsoft/bedrock/master/gitops/azure-devops/release.sh
              . build.sh --source-only

              # Initialization
              verify_access_token
              init
              helm_init

              # Fabrikate
              get_fab_version
              download_fab

              # Clone HLD repo
              git_connect
              # --- End Script

              # Update HLD
              git checkout -b "$BRANCH_NAME"
              export BUILD_REPO_NAME=$(echo $(Build.Repository.Name)-quick-start-app | tr '[:upper:]' '[:lower:]')
              export IMAGE_TAG=$(echo $(Build.SourceBranchName) | tr / - | tr . - | tr _ - )-$(Build.BuildNumber)
              export IMAGE_NAME=$BUILD_REPO_NAME:$IMAGE_TAG
              echo "Image Name: $IMAGE_NAME"
              export IMAGE_REPO=$(echo $(ACR_NAME).azurecr.io | tr '[:upper:]' '[:lower:]')
              echo "Image Repository: $IMAGE_REPO"
              cd $(Build.Repository.Name)/$FAB_SAFE_SERVICE_NAME/$(echo $(Build.SourceBranchName) | tr / - | tr . - | tr _ - )
              echo "FAB SET"
              fab set --subcomponent chart image.tag=$IMAGE_TAG image.repository=$IMAGE_REPO/$BUILD_REPO_NAME

              # Set git identity
              git config user.email "admin@azuredevops.com"
              git config user.name "Automated Account"

              # Commit changes
              echo "GIT ADD and COMMIT -- Will throw error if there is nothing to commit."
              git_commit_if_changes "Updating $SERVICE_NAME_LOWER image tag to $(echo $(Build.SourceBranchName) | tr / - | tr . - | tr _ - )-$(Build.BuildNumber)." 1 unusedVar

              # Git Push
              git_push

              # Open PR via az repo cli
              echo 'az extension add --name azure-devops'
              az extension add --name azure-devops

              echo 'az repos pr create --description "Updating $SERVICE_NAME_LOWER to $(echo $(Build.SourceBranchName) | tr / - | tr . - | tr _ - )-$(Build.BuildNumber)." "PR created by: $(Build.DefinitionName) with buildId: $(Build.BuildId) and buildNumber: $(Build.BuildNumber)"'
              response=$(az repos pr create --description "Updating $SERVICE_NAME_LOWER to $(echo $(Build.SourceBranchName) | tr / - | tr . - | tr _ - )-$(Build.BuildNumber)." "PR created by: $(Build.DefinitionName) with buildId: $(Build.BuildId) and buildNumber: $(Build.BuildNumber)")
              pr_id=$(echo $response | jq -r '.pullRequestId')

              # Update introspection storage with this information, if applicable
              if [ -z "$(INTROSPECTION_ACCOUNT_NAME)" -o -z "$(INTROSPECTION_ACCOUNT_KEY)" -o -z "$(INTROSPECTION_TABLE_NAME)" -o -z "$(INTROSPECTION_PARTITION_KEY)" ]; then
              echo "Introspection variables are not defined. Skipping..."
              else
              latest_commit=$(git rev-parse --short HEAD)
              tag_name="$BUILD_REPO_NAME:$(Build.SourceBranchName)-$(Build.BuildNumber)"
              url=$(git remote --verbose | grep origin | grep fetch | cut -f2 | cut -d' ' -f1)
              repourl=${url##*@}
              get_bedrock_version
              download_bedrock
              ./bedrock/bedrock deployment create  -n $(INTROSPECTION_ACCOUNT_NAME) -k $(INTROSPECTION_ACCOUNT_KEY) -t $(INTROSPECTION_TABLE_NAME) -p $(INTROSPECTION_PARTITION_KEY) --p2 $(Build.BuildId) --hld-commit-id $latest_commit --env $(Build.SourceBranchName) --image-tag $tag_name --pr $pr_id --repository $repourl
              fi
            displayName: 'Download Fabrikate, Update HLD, Push changes, Open PR, and if configured, push to Spektate storage'
            env:
              ACCESS_TOKEN_SECRET: $(PAT)
              AZURE_DEVOPS_EXT_PAT: $(PAT)
              REPO: $(HLD_REPO)
```

### Proposed yaml style

```yaml
# File: azure-pipelines.yml
trigger:
- master

variables:
  - group: quick-start-vg
  - name: APP_NAME
    value: quick-start-app

stages:
  - stage: build
    jobs:
      - job: run_build_push_acr
        pool:
          vmImage: ubuntu-latest
        steps:
        - template: templates/azure-login.yml  # Template reference
          parameters:
            appId: $(SP_APP_ID)
            password: $(SP_PASS)
            tenantId: $(SP_TENANT)
        - template: templates/container-build-strategy.yml  # Template reference
          parameters:
            downloadTools: false
            imageRepoType: ACR
            imageName: "$(APP_NAME)-$(Build.SourceBranchName)"
            imageTag: $(Build.BuildNumber)
            buildArgs:
            - AZP_POOL
            - ACR_NAME
  - stage: hld_update
    dependsOn: build
    condition: succeeded('build')
    jobs:
      - job: update_image_tag
        pool:
          vmImage: ubuntu-latest
        steps:
        - template: templates/git-update-strategy.yml  # Template reference
          parameters:
            downloadFab: true
            downloadTools: true
            azureContainerRegistry: $(ACR_NAME)
            gitUpdateType: HLD
            gitRepoURL: $(HLD_REPO)
            gitAccessToken: $(PAT)
            imageName: "$(APP_NAME)-$(Build.SourceBranchName)"
            imageTag: $(Build.BuildNumber)
```

<!--
<pre>
.
├── README.md
├── azure-pipelines.yml
├── <b>scripts</b>
│   ├── AzureContainerRegistryBuild.sh
│   ├── Test.AzureContainerRegistryBuild.sh
│   ├── download-fabrikate.sh
│   ├── fab-image-tag-update.sh
│   ├── git-clone.sh
│   └── git-pull-request-azdo.sh
└── <b>templates</b>
    ├── app-variables.yml
    ├── azure-login.yml
    ├── container-build-strategy.yml
    └── git-update-strategy.yml
</pre>
-->
