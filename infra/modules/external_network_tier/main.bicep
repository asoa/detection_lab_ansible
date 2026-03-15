import {FirewallPolicyRuleCollectionGroup} from '../../common/types.bicep'

param ruleCollectionGroups FirewallPolicyRuleCollectionGroup[]
param environmentName string
param resourceToken string
@description('Resource ID of the virtual network where Azure Firewall will be deployed. From internal_network_tier module output.')
param virtualNetworkResourceId string

module policies 'br/public:avm/res/network/firewall-policy:0.3.4' = {
  params: {
    name: 'policy-${environmentName}-${resourceToken}'
    ruleCollectionGroups: ruleCollectionGroups
  }
}

module firewall 'br/public:avm/res/network/azure-firewall:0.10.0' = {
  params:{
    name: 'firewall-${environmentName}-${resourceToken}'
    azureSkuTier: 'Standard'
    publicIPResourceID: null // if empty, module will create a new public IP. Otherwise, it will use the provided public IP resource.
    firewallPolicyId: policies.outputs.resourceId
    enableManagementNic: false
    virtualNetworkResourceId: virtualNetworkResourceId
  }
}

output firewallPrivateIp string = firewall.outputs.privateIp


