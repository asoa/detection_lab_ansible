@export()
@description('Virtual networks, subnets, and peerings')
type NetworkSubnet = {
  name: string
  addressPrefix: string
  routeTableResourceId: string?
  networkSecurityGroupResourceId: string?
}

@export()
@description('Input shape for a virtual network and its subnet configuration')
type Network = {
  name: string
  addressSpace: string[]
  subnets: NetworkSubnet[]
}

@export()
@description('Deployed subnet metadata for downstream modules')
type DeployedSubnet = {
  name: string
  resourceId: string
  addressPrefix: string
  networkSecurityGroupResourceId: string?
}

@export()
@description('Deployed virtual network metadata for downstream modules')
type DeployedVirtualNetwork = {
  name: string
  resourceId: string
  subnets: DeployedSubnet[]
}

@export()
@description('Network peering configuration')
type NetworkPeering = {
  name: string
  virtualNetworkName: string
  remoteVirtualNetworkName: string
  allowVirtualNetworkAccess: bool
  allowForwardedTraffic: bool
  allowGatewayTransit: bool
  useRemoteGateways: bool
}


@export()
@description('Firewall Policy Rule Collection Group')
type FirewallPolicyRuleCollectionGroup = {
  name: string
  priority: int
  ruleCollections: [
    {
      action: {
        type: string
      }
      name: string
      priority: int
      ruleCollectionType: 'FirewallPolicyFilterRuleCollection' | 'FirewallPolicyNatRuleCollection'
      rules: {
          name: string
          ruleType: 'ApplicationRule' | 'NetworkRule' | 'NatRule'
          destinationAddresses: string[]
          destinationFqdns: string[]?
          destinationIpGroups: string[]?
          destinationPorts: string[]
          ipProtocols: string[]
          sourceAddresses: string[]
          sourceIpGroups: string[]?
      }[]
    }
  ]
}

@export()
type NsgRule = {
  name: string
  properties: {
    access: 'Allow' | 'Deny'
    direction: 'Inbound' | 'Outbound'
    priority: int
    protocol: '*' | 'Tcp' | 'Udp' | 'Icmp' | 'Ah' | 'Esp'
    description: string?
    sourceAddressPrefix: string?
    sourceAddressPrefixes: string[]?
    sourceApplicationSecurityGroupResourceIds: string[]?
    sourcePortRange: string
    sourcePortRanges: string[]?
    destinationAddressPrefix: string?
    destinationAddressPrefixes: string[]?
    destinationApplicationSecurityGroupResourceIds: string[]?
    destinationPortRange: string?
    destinationPortRanges: string[]?
  }
}

@export()
@description('Network Security Group configuration')
type NsgConfig = {
  name: string
  securityRules: NsgRule[]
}

@export()
@description('Marketplace image reference for a virtual machine deployment')
type VirtualMachineImageReference = {
  publisher: string
  offer: string
  sku: string
  version: string
}

@export()
@description('Supported enterprise service roles for Windows bootstrap')
type EnterpriseServiceRole = 'domain-controller' | 'file-share'

@export()
@description('Typed Windows bootstrap configuration for enterprise server provisioning')
type WindowsBootstrapConfig = {
  enabled: bool
  repositoryUrl: string
  branchOrRef: string
  playbookPath: string
  wslDistribution: string
  serviceRole: EnterpriseServiceRole
  bootstrapScriptFileUris: string[]
  managedIdentityResourceId: string?
  forceUpdateTag: string?
  repositoryDirectory: string?
  logDirectory: string?
  domainName: string?
  shareName: string?
}

@export()
@description('Reusable virtual machine properties shared across repeated VM instances')
type VirtualMachineBaseConfig = {
  availabilityZone: -1 | 1 | 2 | 3
  nicConfigurations: {
    ipConfigurations: {
      subnetResourceId: string
      privateIPAllocationMethod: 'Static' | 'Dynamic'
      name: string?
      privateIPAddress: string?
      pipConfiguration: {}?
    }[]?
  }[]?
  osDisk: {
    caching: 'ReadOnly' | 'ReadWrite' | 'None'?
    createOption: 'Attach' | 'FromImage' | 'Empty'?
    diskSizeGB: int?
    managedDisk: {
      storageAccountType: [
        'Premium_LRS'
        'Premium_ZRS'
        'PremiumV2_LRS'
        'Standard_LRS'
        'StandardSSD_LRS'
        'StandardSSD_ZRS'
        'UltraSSD_LRS'
      ]
    }?
  }
  osType: 'Windows' | 'Linux'
  vmSize: string
  adminUsername: string
  image: VirtualMachineImageReference
}

@export()
@description('Virtual machine configuration used by the vm_host module')
type VirtualMachineConfig = {
  name: string
  availabilityZone: -1 | 1 | 2 | 3
  nicConfigurations: {
    ipConfigurations: {
      subnetResourceId: string
      privateIPAllocationMethod: 'Static' | 'Dynamic'
      name: string?
      privateIPAddress: string?
      pipConfiguration: {}?
    }[]?
  }[]?
  osDisk: {
    caching: 'ReadOnly' | 'ReadWrite' | 'None'?
    createOption: 'Attach' | 'FromImage' | 'Empty'?
    diskSizeGB: int?
    managedDisk: {
      storageAccountType: [
        'Premium_LRS'
        'Premium_ZRS'
        'PremiumV2_LRS'
        'Standard_LRS'
        'StandardSSD_LRS'
        'StandardSSD_ZRS'
        'UltraSSD_LRS'
      ]
    }?
  }
  osType: 'Windows' | 'Linux'
  vmSize: string
  adminUsername: string
  image: VirtualMachineImageReference
}

@export()
@description('Count-based configuration for repeated VM deployments')
type VirtualMachineSetConfig = {
  namePrefix: string
  count: int
  baseConfig: VirtualMachineBaseConfig
  bootstrap: WindowsBootstrapConfig?
}

@export()
@description('Count-based configuration for enterprise server deployments with required Windows bootstrap')
type EnterpriseServerSetConfig = {
  namePrefix: string
  count: int
  baseConfig: VirtualMachineBaseConfig
  bootstrap: WindowsBootstrapConfig
}
