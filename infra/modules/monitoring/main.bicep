// infra/modules/monitoring/main.bicep
param appInsightsName string
param location string = resourceGroup().location
param tags object = {}
param workspaceResourceId string = ''
param deployPrivateEndpoints bool = false
param appNames array

module law 'br:mcr.microsoft.com/bicep/avm/res/operational-insights/workspace:0.15.0' = if (empty(workspaceResourceId)) {
  name: 'logAnalyticsWorkspace'
  params: {
    name: '${appInsightsName}-law'
    location: location
    tags: tags
    skuName: 'PerGB2018'
    dataRetention: 30
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: deployPrivateEndpoints ? 'Disabled' : 'Enabled'
  }
}

// bot app insights
module appInsights 'br/public:avm/res/insights/component:0.7.1' = {
  name: '${appInsightsName}-bot'
  params: {
    name: appInsightsName
    location: location
    tags: tags
    kind: 'web'
    applicationType: 'web'
    workspaceResourceId: empty(workspaceResourceId) ? law.outputs.resourceId : workspaceResourceId
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

module ampls 'br/public:avm/res/insights/private-link-scope:0.7.2' = if (deployPrivateEndpoints) {
  name: 'appInsightsPrivateLinkScope'
  params: {
    name: '${appInsightsName}-amps'
    location: 'global'
    tags: tags
    scopedResources: [
      {
        name: appInsightsName
        linkedResourceId: appInsights.outputs.resourceId
      }
      {
        name: law.name
        linkedResourceId: empty(workspaceResourceId) ? law.outputs.resourceId : workspaceResourceId
      }
    ]
  }
}


// app insights for kernel, data, and mcp services
// manually add to amplms after deployment
module appsInsights 'br/public:avm/res/insights/component:0.7.1' = [for (app, index) in appNames: {
  name: '${appInsightsName}-${app}'
  params: {
    name: '${appInsightsName}-${app}'
    location: location
    tags: tags
    kind: 'web'
    applicationType: 'web'
    workspaceResourceId: empty(workspaceResourceId) ? law.outputs.resourceId : workspaceResourceId
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}]

output appInsightsId string = appInsights.outputs.applicationId
output appInsightsName string = appInsights.name
output instrumentationKey string = appInsights.outputs.instrumentationKey
output connectionString string = appInsights.outputs.connectionString
output workspaceId string = empty(workspaceResourceId) ? law.outputs.resourceId : workspaceResourceId

output monitoringPepData object[] = deployPrivateEndpoints ? [
  {
    name: 'azuremonitor'
    id: ampls.outputs.resourceId
    groupId: 'azuremonitor'
  }
] : []

// create array of appInsights objects for kernel, data, and mcp services
output appInsightsConnectionStrings array = [
  for (app, index) in appNames: {
    name: appsInsights[index].name
    instrumentationKey: appsInsights[index].outputs.instrumentationKey
    connectionString: appsInsights[index].outputs.connectionString
    applicationId: appsInsights[index].outputs.applicationId
  }
]
