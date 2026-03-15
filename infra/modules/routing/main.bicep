import {DeployedVirtualNetwork} from '../../common/types.bicep'

param virtualNetworks DeployedVirtualNetwork[]
param firewallPrivateIp string
param environmentName string
param resourceToken string
param hubNetworkName string = 'hub'

var reservedSubnetNames = [
  'AzureFirewallSubnet'
  'AzureFirewallManagementSubnet'
]

var routedSubnets = flatten(map(
  filter(range(0, length(virtualNetworks)), networkIndex => virtualNetworks[networkIndex].name != hubNetworkName),
  networkIndex => map(
    filter(virtualNetworks[networkIndex].subnets, subnet => !contains(reservedSubnetNames, subnet.name)),
    subnet => {
      virtualNetworkIndex: networkIndex
      name: subnet.name
      addressPrefix: subnet.addressPrefix
      networkSecurityGroupResourceId: subnet.?networkSecurityGroupResourceId ?? ''
    }
  )
))

resource routeTable 'Microsoft.Network/routeTables@2025-05-01' = {
  name: 'rt-${environmentName}-${resourceToken}'
  location: resourceGroup().location
  properties: {
    routes: [
      {
        name: 'default-route'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: firewallPrivateIp
        }
      }
    ]
  }
}

resource vnets 'Microsoft.Network/virtualNetworks@2025-05-01' existing = [for virtualNetwork in virtualNetworks: {
  name: virtualNetwork.name
}]

resource subnets 'Microsoft.Network/virtualNetworks/subnets@2025-05-01' = [for subnet in routedSubnets: {
  name: subnet.name
  parent: vnets[subnet.virtualNetworkIndex]
  properties: union({
    addressPrefix: subnet.addressPrefix
    routeTable: {
      id: routeTable.id
    }
  }, !empty(subnet.networkSecurityGroupResourceId) ? {
    networkSecurityGroup: {
      id: subnet.networkSecurityGroupResourceId
    }
  } : {})
}]

output routeTableId string = routeTable.id
