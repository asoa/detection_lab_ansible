// adapted from https://github.com/Azure-Samples/azure-search-openai-demo.git
param environmentResourceId string
param name string
param ingressAllowInsecure bool = false
param ingressTargetPort int
@allowed(['auto', 'http', 'http2', 'tcp'])
param ingressTransport string = 'auto'
param registries array = []
param daprEnabled bool = false
param daprAppId string = name
@allowed(['http', 'grpc'])
param daprAppProtocol string = 'http'
@description('The name of the container image')
param imageName string
@description('The name of the container')
param containerName string = 'main'
@description('The environment variables for the container')
param env array = []
@description('RBAC roles applied to the container app')
param containerMinReplicas int = 1
param containerMaxReplicas int = 5
// param workloadProfile string = 'Consumption'
param allowedOrigins array = []
param userAssignedResourceIds array = []
param tags object = {}
param containerCpuCoreCount int
param containerMemory string
param deployPrivateEndpoints bool
param devVMIpAddress string

module app 'br/public:avm/res/app/container-app:0.20.0' = {
   params: {
    name: name
    location: resourceGroup().location
    environmentResourceId: environmentResourceId
    registries: registries
    dapr: daprEnabled ? {
      enabled: true
      appId: daprAppId
      appProtocol: daprAppProtocol
    } : { enabled : false}
    containers: [
      {
        image: !empty(imageName) ? imageName : 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
        name: containerName
        env: env
        resources: {
          cpu: containerCpuCoreCount
          memory: containerMemory
        }
      }
    ]
    scaleSettings: {
      minReplicas: containerMinReplicas
      maxReplicas: containerMaxReplicas
    }
    ingressTransport: ingressTransport
    ingressTargetPort: ingressTargetPort
    ingressAllowInsecure: ingressAllowInsecure
    corsPolicy: {
      allowedOrigins: union([ 'https://portal.azure.com', 'https://ms.portal.azure.com' ], allowedOrigins)
    }
    managedIdentities: {
      userAssignedResourceIds: userAssignedResourceIds
    }
    tags: tags
    // TODO: enable private endpoints in production
    // ipSecurityRestrictions: deployPrivateEndpoints ? [] : [
    //   {
    //     name: 'devVM'
    //     description: 'Allow access from development VM'
    //     ipAddressRange: devVMIpAddress
    //     action: 'Allow'
    //   }
    // ]
  }
}

output imageName string = imageName
output name string = app.name
output uri string = app.outputs.fqdn
output id string = app.outputs.resourceId 
