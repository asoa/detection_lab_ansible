// adapted from project: https://github.com/Azure-Samples/azure-search-openai-demo.git
metadata description = 'Creates or updates an existing Azure Container App.'
@description('The number of CPU cores allocated to a single container instance, e.g., 0.5')
param containerCpuCoreCount int
@description('The maximum number of replicas to run. Must be at least 1.')
@minValue(1)
param containerMaxReplicas int = 10
@description('The amount of memory allocated to a single container instance, e.g., 1Gi')
param containerMemory string
@description('The minimum number of replicas to run. Must be at least 1 for non-consumption workloads.')
param containerMinReplicas int = 1
@description('The name of the container')
param containerName string = 'main'
@allowed(['http', 'grpc'])
@description('The protocol used by Dapr to connect to the app, e.g., HTTP or gRPC')
param daprAppProtocol string = 'http'
@description('Enable or disable Dapr for the container app')
param daprEnabled bool = false
@description('The Dapr app ID')
param daprAppId string = containerName
@description('Specifies if the resource already exists')
param exists bool = false
@description('The name of the container image')
param imageName string
@description('The environment variables for the container in key value pairs')
param env object = {}
@description('The environment variables with secret references')
param envSecrets array = []
@description('The target port for the container')
param targetPort int
param allowedOrigins array = []
param environmentResourceId string
param registries array = []
param userAssignedResourceIds array = []
param tags object = {}
param deployPrivateEndpoints bool = false
param devVMIpAddress string = ''
@description('The list of apps to create or update')
param apps object[]
param environmentName string
param resourceToken string

var envAsArray = [
  for key in objectKeys(env): {
    name: key
    value: '${env[key]}'
  }
]

var abbrs = loadJsonContent('../../abbreviations.json')


module app 'container-app.bicep' = [for (_app, index) in apps: {
  name: '${deployment().name}-${_app.name}-update'
  params: {
    name: '${abbrs.appContainerApps}${environmentName}${_app.name}${resourceToken}'
    environmentResourceId: environmentResourceId
    containerName: containerName
    containerMinReplicas: containerMinReplicas
    containerMaxReplicas: containerMaxReplicas
    daprEnabled: daprEnabled
    daprAppId: daprAppId
    daprAppProtocol: daprAppProtocol
    env: concat(envAsArray, envSecrets)
    imageName: !empty(_app.name) ? _app.name : 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
    ingressTargetPort: targetPort
    allowedOrigins: allowedOrigins
    registries: registries
    userAssignedResourceIds: userAssignedResourceIds
    tags: {
      ...tags
      'azd-service-name': _app.name
    }
    containerCpuCoreCount: containerCpuCoreCount
    containerMemory: containerMemory
    devVMIpAddress: devVMIpAddress
    deployPrivateEndpoints: deployPrivateEndpoints
  }
}]

// output imageName string = app.outputs.imageName
// output name string = app.outputs.name
// output uri string = app.outputs.uri
// output id string = app.outputs.id

output xoAgentUrl string = app[0].outputs.uri
