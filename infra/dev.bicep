targetScope = 'subscription'

import {
  Network
  NetworkPeering
  FirewallPolicyRuleCollectionGroup
  NsgConfig
  EnterpriseServerSetConfig
  VirtualMachineSetConfig
} from './common/types.bicep'

param projectName string
param ruleCollectionGroups FirewallPolicyRuleCollectionGroup[]
param environmentName string
param location string
param existingKeyVaultName string
param existingKeyVaultResourceGroupName string
param networks Network[]
param networkPeerings NetworkPeering[]
param nsgs NsgConfig[]
param hrWorkstations VirtualMachineSetConfig
param engineeringWorkstations VirtualMachineSetConfig
param domainControllers EnterpriseServerSetConfig
param fileShares EnterpriseServerSetConfig

var abbrs = loadJsonContent('abbreviations.json')
var resourceToken = take(toLower(uniqueString(subscription().id, environmentName, location)),6)

resource rg 'Microsoft.Resources/resourceGroups@2025-04-01' = {
  name: '${abbrs.resourcesResourceGroups}${environmentName}${projectName}${resourceToken}'
  location: location
}

module newtworkSecurityGroups 'modules/security/network-security-group.bicep' = {
  name: 'nsgs'
  scope: rg
  params: {
    nsgs: nsgs
  }
}

module nw 'modules/internal_network_tier/main.bicep' = {
  name: 'network'
  scope: rg
  params: {
    networks: networks
    peerings: networkPeerings
    nsgResourceIds: newtworkSecurityGroups.outputs.nsgResourceIds
  }
}

module fw 'modules/external_network_tier/main.bicep' = {
  name: 'externalNetworkTier'
  scope: rg
  params: {
    ruleCollectionGroups: ruleCollectionGroups
    environmentName: environmentName
    resourceToken: resourceToken
    // filter the virtual network output from internal network tier module to get the resource ID of the hub virtual network
    virtualNetworkResourceId: filter(nw.outputs.virtualNetworks, nw => nw.name == 'hub')[0].resourceId
  }
}

module routing 'modules/routing/main.bicep' = {
  name: 'routing'
  scope: rg
  params: {
    virtualNetworks: nw.outputs.virtualNetworks
    firewallPrivateIp: fw.outputs.firewallPrivateIp
    environmentName: environmentName
    resourceToken: resourceToken
  }
}

module hrWorkstationsDeployment 'modules/vm_host/main.bicep' = {
  name: 'hrWorkstations'
  scope: rg
  params: {
    existingKeyVaultResourceGroupName: existingKeyVaultResourceGroupName
    existingKeyVaultName: existingKeyVaultName
    subnetResourceId: filter(nw.outputs.flatSubnetResourceIds, subnetId => contains(subnetId, '/subnets/hr-subnet'))[0]
    vmSet: hrWorkstations
  }
}

module engineeringWorkstationsDeployment 'modules/vm_host/main.bicep' = {
  name: 'engineeringWorkstations'
  scope: rg
  params: {
    existingKeyVaultResourceGroupName: existingKeyVaultResourceGroupName
    existingKeyVaultName: existingKeyVaultName
    subnetResourceId: filter(nw.outputs.flatSubnetResourceIds, subnetId => contains(subnetId, 'engineering-subnet'))[0]
    vmSet: engineeringWorkstations
  }
}

module domainControllersDeployment 'modules/vm_host/main.bicep' = {
  name: 'domainControllers'
  scope: rg
  params: {
    existingKeyVaultResourceGroupName: existingKeyVaultResourceGroupName
    existingKeyVaultName: existingKeyVaultName
    subnetResourceId: filter(nw.outputs.flatSubnetResourceIds, subnetId => contains(subnetId, 'servers-subnet'))[0]
    vmSet: domainControllers
    role: domainControllers.bootstrap.serviceRole
  }
}

module fileSharesDeployment 'modules/vm_host/main.bicep' = {
  name: 'fileShares'
  scope: rg
  params: {
    existingKeyVaultResourceGroupName: existingKeyVaultResourceGroupName
    existingKeyVaultName: existingKeyVaultName
    subnetResourceId: filter(nw.outputs.flatSubnetResourceIds, subnetId => contains(subnetId, 'servers-subnet'))[0]
    vmSet: fileShares
    role: fileShares.bootstrap.serviceRole
  }
}
