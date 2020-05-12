# Templating the `bedrock-cli` 
This repository contains a proposal around pipeline generation for the [bedrock-cli](https://github.com/microsoft/bedrock-cli). Inspired by my post [here](https://github.com/microsoft/bedrock/issues/1006#issuecomment-592771163).

## Problem
Customers are on their own between AKS (infra creation) and Azure Devops (orchestration)

Customers dont' want to use Bedrock CLI because:
* They don't want or need to use Fabrikate with their current scenario.
  * Fabrikate might be too advanced for their current needs
* They have to make several changes to `bedrock` generated pipelines
  * Want something more templated that allows csutomization
* `bedrock` can not anticpate all needs in GitOps scenarios upfront

## Proposal 

- Simplify what `bedrock` cli generates
  - Push logic into Azure DevOps Templates 
  - Allow customization of business logic in templates and scripts
- Focus on composition and encapsulation
  - Business logic specific data and functions are packaged
  - More definition of what components need (via parameters)
  - More logic reuse
  - Separation of concerns
- More easily support custom agents
  - We provide switches to turn on and off certain pieces of logic (i.e. don't download Fabrikate)
- We are enabling a library of GitOps AZDO templates and scripts that the community can extend 


- If you don't want to use a variable group you can set ENV VAR (even) secure ones) in your [custom Bedrock build agent](https://github.com/andrebriggs/bedrock-agents)
  - Power users (enterprise_) can bring all their tools in a custom Bedrock build agent.

- Shell scripts that are based on ENV VARs can be easily tested.
- We will rely more on integration tests since the solution space has exploded compared to the hardcoded paths of the current CLI
- The templatizing makes it easier for someone to take what we are doing and massage it to their needs. The current model doesn't invite people to change what has been scaffolding

## Some ideas 

- When calling `bedrock service create` the CLI will download templates and scripts from the maintained bedrock repository
The CLI will generate your `azure-pipelines.yml` that references the templates and in turn the scripts.
Users can customize or add to the templates/scripts

- In mono-repo situations each application will have it's own `azure-pipelines.yml` that will handle orchestration. 

## Canned scenarios
We will have some canned scenarios that the CLI will help you with out the box

GitOps pipeline using High Level Definition repo and Fabrikate
1. Create an App build
2. Push to ACR or DockerHub
3. Update a HLD using Fabrikate repo
4. Create Pull request on AzDO

GitOps pipeline using only Helm
1. Create an App build
2. Push to ACR or DockerHub
3. Update a Helm chart repo, Run Helm template and copy to "Manifest repo"
4. Create Pull request on AzDO