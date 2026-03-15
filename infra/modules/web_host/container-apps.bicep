param appEnvName string
param appName string
param registryName string
param subnetResourceId array
param containerRegistryAdminUserEnabled bool = false 
param acrSku string = 'Premium'
param deployPrivateEndpoints bool

var infrastructureSubnetId = filter(subnetResourceId[0], item => contains(item, 'ContainerAppsSubnet'))

resource appIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2025-01-31-preview' = {
  name: '${appName}-aca-identity'
  location: resourceGroup().location
}

module appEnv 'br/public:avm/res/app/managed-environment:0.11.3' = {
  name: 'cae'
  params: {
    name: appEnvName
    location: resourceGroup().location
    infrastructureSubnetResourceId: infrastructureSubnetId[0]
    internal: false
    zoneRedundant: false
    publicNetworkAccess: deployPrivateEndpoints ? 'Disabled' : 'Enabled'
    workloadProfiles: [
      {
        name: 'consumption'
        workloadProfileType: 'Consumption'
      }
    ]
  }
}

module registry 'br/public:avm/res/container-registry/registry:0.10.0' = {
  name: 'acr'
  params: {
    name: registryName
    location: resourceGroup().location
    acrAdminUserEnabled: containerRegistryAdminUserEnabled
    acrSku: deployPrivateEndpoints ? acrSku : 'Standard'
    publicNetworkAccess: deployPrivateEndpoints ? 'Disabled' : 'Enabled'
    zoneRedundancy: 'Disabled'
  }
}

output defaultDomain string = appEnv.outputs.defaultDomain
output environmentName string = appEnv.outputs.name
output environmentId string = appEnv.outputs.resourceId
output registryLoginServer string = registry.outputs.loginServer
output registryName string = registry.outputs.name
output principalId string = appIdentity.properties.principalId
output clientId string = appIdentity.properties.clientId
output principalIdName string = appIdentity.name
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = registry.outputs.loginServer
output containerAppsPepData object[] = [
  {
    name: appEnv.name
    id: appEnv.outputs.resourceId
    groupId: 'managedEnvironments'
  }
  {
    name: registry.name
    id: registry.outputs.resourceId
    groupId: 'registry'
  }
]
