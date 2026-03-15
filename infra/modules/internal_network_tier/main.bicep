import {DeployedVirtualNetwork, Network, NetworkPeering} from '../../common/types.bicep'

param networks Network[]
param peerings NetworkPeering[]
@description('Resource IDs of NSGs to be associated with subnets in this module, matched by name. Output from network security group module.')
param nsgResourceIds {
  name: string
  resourceId: string
}[]

module nw 'br/public:avm/res/network/virtual-network:0.7.2' = [for (network, index) in networks: {
  params: {
    name: network.name
    addressPrefixes: network.addressSpace
    // subnets: network.subnets
    // patch the subnet object with the nsg id
    subnets: [for (subnet, subnetIndex) in network.subnets: {
      name: subnet.name
      addressPrefix: subnet.addressPrefix
      networkSecurityGroupResourceId: length(filter(nsgResourceIds, nsg => nsg.name == subnet.name)) > 0
        ? filter(nsgResourceIds, nsg => nsg.name == subnet.name)[0].resourceId
        : subnet.?networkSecurityGroupResourceId
    }]
  }
}]

resource networkPeerings 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2025-05-01' = [for (peering, index) in peerings: {
  name: '${peering.virtualNetworkName}/${peering.name}'
  properties: {
    remoteVirtualNetwork: {
      id: resourceId('Microsoft.Network/virtualNetworks', peering.remoteVirtualNetworkName)
    }
    allowVirtualNetworkAccess: peering.allowVirtualNetworkAccess
    allowForwardedTraffic: peering.allowForwardedTraffic
    allowGatewayTransit: peering.allowGatewayTransit
    useRemoteGateways: peering.useRemoteGateways
  }
  dependsOn: [nw]
}]

var deterministicSubnetResourceIds = [
  for (network, index) in networks: map(network.subnets, subnet =>
    resourceId(
      'Microsoft.Network/virtualNetworks/subnets',
      network.name,
      subnet.name
    )
  )
]

var deterministicFlatSubnetResourceIds = flatten(deterministicSubnetResourceIds)

output virtualNetworks DeployedVirtualNetwork[] = [
  for (network, index) in networks: {
    name: nw[index].outputs.name
    resourceId: nw[index].outputs.resourceId
    subnets: map(network.subnets, subnet => {
      name: subnet.name
      resourceId: resourceId(
        'Microsoft.Network/virtualNetworks/subnets',
        network.name,
        subnet.name
      )
      addressPrefix: subnet.addressPrefix
      networkSecurityGroupResourceId: subnet.?networkSecurityGroupResourceId
    })
  }
]
output subnetResourceIds array = deterministicSubnetResourceIds

output flatSubnetResourceIds array = deterministicFlatSubnetResourceIds

output acrSubnetResourceIds array = [
  for (network, index) in networks: {
    subnetResourceIds: deterministicSubnetResourceIds[index]
  }
]
