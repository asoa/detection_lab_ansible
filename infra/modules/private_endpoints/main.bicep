param pepResourceObjects array
@description('array of virtual networks from networking module')
param virtualNetworks array
@description('The name of the virtual network to create the private endpoint in')
param virtualNetworkName string
@description('The cloud environment to deploy to, e.g., "public", "usgov"')
param cloudEnv string
// @description('Optional map of private endpoint group keys to existing Private DNS Zone resource IDs. When provided, DNS zones are reused instead of created.')
// param existingPrivateDnsZoneResourceIds object = {}
@description('Optional existing resource group to look for existing private dns zones. If not provided, the deployment resource group will be used.')
param existingResourceGroup string

var subnetResourceId = filter(
  filter(virtualNetworks, nw => nw.name == virtualNetworkName)[0].subnets,
  subnet => subnet.name == 'PrivateEndpointSubnet'
)[0].resourceId
var virtualNetworkResourceId = filter(virtualNetworks, (nw) => nw.name == virtualNetworkName)[0].resourceId
// mapping of type of private endpoint to private dns zone
var privateDnsGroupZoneMap = {
  kv: 'privatelink.vaultcore.usgovcloudapi.net'
  storage: 'privatelink.blob.core.usgovcloudapi.net'
  web: 'privatelink.azurewebsites.us'
  search: 'privatelink.search.azure.us'
  OpenAI: 'privatelink.openai.azure.us'
  FormRecognizer: 'privatelink.cognitiveservices.azure.us'
  CognitiveServices: 'privatelink.cognitiveservices.azure.us'
  acr: 'privatelink.azurecr.us'
  hub: 'privatelink.api.ml.azure.us'
  cosmos: 'privatelink.documents.azure.us'
  cae: 'privatelink.azurecontainerapps.us'
  bot: 'privatelink.directline.botframework.azure.us'
  azuremonitor: 'privatelink.monitor.azure.us'
}

var publicPrivateDnsGroupZoneMap = {
  kv: 'privatelink.vaultcore.azure.net'
  storage: 'privatelink.blob.core.windows.net'
  web: 'privatelink.azurewebsites.net'
  search: 'privatelink.search.windows.net'
  OpenAI: 'privatelink.openai.azure.com'
  FormRecognizer: 'privatelink.cognitiveservices.azure.com'
  CognitiveServices: 'privatelink.cognitiveservices.azure.com'
  acr: 'privatelink.azurecr.io'
  hub: 'privatelink.api.azureml.ms'
  cosmos: 'privatelink.documents.azure.com'
  cae: 'privatelink.azurecontainerapps.io'
  bot: 'privatelink.directline.botframework.com'
  azuremonitor: 'privatelink.monitor.azure.com'
}

var usgovPrivateDnsZones = [for item in items(privateDnsGroupZoneMap): item.value]
var publicPrivateDnsZones = [for item in items(publicPrivateDnsGroupZoneMap): item.value]
var privateDnsZones = (cloudEnv == 'usgov') ? usgovPrivateDnsZones : publicPrivateDnsZones
var privateDnsGroupZoneNameMap = (cloudEnv == 'usgov') ? privateDnsGroupZoneMap : publicPrivateDnsGroupZoneMap

// conditionally create private DNS zones if existing resource group is not provided. If it is provided, we assume the zones already exist and skip creating them.
module dnszone 'br/public:avm/ptn/network/private-link-private-dns-zones:0.7.2' = if (empty(existingResourceGroup)) {
  name: 'dnszone'
  params: {
    privateLinkPrivateDnsZones: privateDnsZones
    virtualNetworkResourceIdsToLinkTo: [
      virtualNetworkResourceId
    ]
  }
}

@batchSize(5)
module pep 'br/public:avm/res/network/private-endpoint:0.11.1' = [for (obj, index) in pepResourceObjects: {
  name: 'pep-${obj.name}-${uniqueString(obj.id)}'
  dependsOn: empty(existingResourceGroup) ? [
    dnszone
  ] : []
  params: {
    name: 'pep-${obj.name}-${uniqueString(obj.id)}'
    subnetResourceId: subnetResourceId
    privateLinkServiceConnections: [
      {
        name: 'pep-${obj.name}-${uniqueString(obj.id)}'
        properties: {
          privateLinkServiceId: obj.id
          groupIds: [obj.groupId]
        }
      }
    ]
    privateDnsZoneGroup: {
      privateDnsZoneGroupConfigs: [
        {
          privateDnsZoneResourceId: !empty(existingResourceGroup)
            // If an existing resource group is provided, we assume the private DNS zones already exist and we can reference them by resource ID. 
            ? '${subscription().id}/resourceGroups/${existingResourceGroup}/providers/Microsoft.Network/privateDnsZones/${privateDnsGroupZoneNameMap[obj.name]}'
            // Otherwise, we reference the zones created in this deployment by their full resource ID using the current subscription and resource group.
            : '${subscription().id}/resourceGroups/${resourceGroup().name}/providers/Microsoft.Network/privateDnsZones/${privateDnsGroupZoneNameMap[obj.name]}'
        }
      ]
    }
  }
}]

output privateEndpointFqdns array = [for (obj, index) in pepResourceObjects: {
  name: obj.name
  fqdn: pep[index].outputs.customDnsConfigs // returns an array of fqdns {'fqdn', ['ip']}
}]
