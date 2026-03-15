### Dev Environment Setup
- Install Azure CLI [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)
- Install Bicep [Bicep CLI](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/install)
  - TODO: add build target to Makefile
- install [Azure Developer CLI(azd)](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/) to deploy the infrastructure and application to Azure

## Pre-requisites
- Create a keyvault for bot jumpbox admin password: `az keyvault create -n <vault name> -g <resource group name> -l <location> --enabled-for-deployment --enable-rbac-authorization --enabled-for-template-deployment`
- Add jumpbox password to keyvault: adminPassword (secret name)
- Give keyvault RBAC to user identity deploying template
- Create deployment environment using `azd env new <environment-name>`; this will create a new environment in the .azure directory
- Run `azd config set cloud.name <cloud-name>` to set the cloud environment (e.g. `AzureCloud` for commercial and `AzureUSGovernment` for GCC/GCC-H)
- Login to Azure using `azd auth login`
- Azure subscription with Owner RBAC
- Clone this repository to your local machine

## Infrastructure Authoring Conventions
- Reusable object-shaped Bicep contracts MUST be defined as strict shared types in `infra/common/types.bicep` and imported by consuming modules.
- When updating module interfaces, prefer shared user-defined types or resource-derived types over open `object` or `array` declarations.