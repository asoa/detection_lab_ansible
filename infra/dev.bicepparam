using 'dev.bicep'

param environmentName =  'dev'
param location =  'eastus2'
param projectName =  'lab'
var devIpAddresses = '46.110.145.110'
param existingKeyVaultResourceGroupName = 'rg-offsec-core'
param existingKeyVaultName = 'kv-offsec-core'

param hrWorkstations = {
  namePrefix: 'hr-user-'
  count: 3
  baseConfig: {
    availabilityZone: -1
    adminUsername: 'labadmin'
    vmSize: 'Standard_D2ls_v6'
    osDisk: {
      diskSizeGB: 128
    }
    osType: 'Windows'
    image: {
      publisher: 'MicrosoftWindowsDesktop'
      offer: 'windows-11'
      sku: 'win11-25h2-pro'
      version: 'latest'
    }
  }
}

param engineeringWorkstations = {
  namePrefix: 'eng-user-'
  count: 3
  baseConfig: {
    availabilityZone: -1
    adminUsername: 'labadmin'
    vmSize: 'Standard_D2ls_v6'
    osDisk: {
      diskSizeGB: 128
    }
    osType: 'Windows'
    image: {
      publisher: 'MicrosoftWindowsDesktop'
      offer: 'windows-11'
      sku: 'win11-25h2-pro'
      version: 'latest'
    }
  }
}

param domainControllers = {
  namePrefix: 'DC'
  count: 1
  baseConfig: {
    availabilityZone: -1
    adminUsername: 'labadmin'
    vmSize: 'Standard_D4s_v5'
    osDisk: {
      diskSizeGB: 128
    }
    osType: 'Windows'
    image: {
      publisher: 'MicrosoftWindowsServer'
      offer: 'WindowsServer'
      sku: '2025-datacenter-g2'
      version: 'latest'
    }
  }
  bootstrap: {
    enabled: true
    repositoryUrl: 'https://github.com/<owner>/<ansible-repo>.git'
    branchOrRef: '<branch-or-tag>'
    playbookPath: 'playbooks/domain-controller.yml'
    wslDistribution: 'Ubuntu-24.04'
    serviceRole: 'domain-controller'
    bootstrapScriptFileUris: [
      'https://raw.githubusercontent.com/<owner>/<repo>/<ref>/infra/modules/vm_host/windows-bootstrap.ps1'
    ]
    forceUpdateTag: '2026-03-15-dc01-bootstrap'
    repositoryDirectory: 'C:\\offsec-ansible'
    logDirectory: 'C:\\ProgramData\\OffSec\\EnterpriseBootstrap'
    domainName: 'corp.offsec.local'
  }
}

param fileShares = {
  namePrefix: 'FS'
  count: 1
  baseConfig: {
    availabilityZone: -1
    adminUsername: 'labadmin'
    vmSize: 'Standard_D4s_v5'
    osDisk: {
      diskSizeGB: 128
    }
    osType: 'Windows'
    image: {
      publisher: 'MicrosoftWindowsServer'
      offer: 'WindowsServer'
      sku: '2025-datacenter-g2'
      version: 'latest'
    }
  }
  bootstrap: {
    enabled: true
    repositoryUrl: 'https://github.com/<owner>/<ansible-repo>.git'
    branchOrRef: '<branch-or-tag>'
    playbookPath: 'playbooks/file-share.yml'
    wslDistribution: 'Ubuntu-24.04'
    serviceRole: 'file-share'
    bootstrapScriptFileUris: [
      'https://raw.githubusercontent.com/<owner>/<repo>/<ref>/infra/modules/vm_host/windows-bootstrap.ps1'
    ]
    forceUpdateTag: '2026-03-15-fs01-bootstrap'
    repositoryDirectory: 'C:\\offsec-ansible'
    logDirectory: 'C:\\ProgramData\\OffSec\\EnterpriseBootstrap'
    shareName: 'Engineering'
  }
}

param networks = [
  {
    name: 'hub'
    addressSpace: ['10.0.0.0/16']
    subnets: [
      {
        name: 'AzureFirewallSubnet'
        addressPrefix: '10.0.0.0/24'
      }
      {
        name: 'AzureFirewallManagementSubnet'
        addressPrefix: '10.0.1.0/26'
      }
    ]
  }
  {
    name: 'hr'
    addressSpace: ['10.1.0.0/16']
    subnets: [
      {
        name: 'hr-subnet'
        addressPrefix: '10.1.0.0/24'
      }
    ]
  }
  {
    name: 'engineering'
    addressSpace: ['10.2.0.0/16']
    subnets: [
      {
        name: 'engineering-subnet'
        addressPrefix: '10.2.0.0/24'
      }
      {
        name: 'servers-subnet'
        addressPrefix: '10.2.1.0/24'
      }
    ]
  }
  {
    name: 'security'
    addressSpace: ['10.3.0.0/16']
    subnets: [
      {
        name: 'security-subnet'
        addressPrefix: '10.3.0.0/24'
      }
    ]
  }
]


param nsgs = [
  {
    name: 'servers-subnet' // associate NSG with servers subnet in engineering VNet
    securityRules: [
      {
        name: 'allow-corp-to-domain-services'
        properties: {
          access: 'Allow'
          direction: 'Inbound'
          priority: 100
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefixes: [
            '10.1.0.0/24'
            '10.2.0.0/24'
            '10.2.1.0/24'
          ]
          destinationPortRanges: [
            '53'
            '88'
            '135'
            '389'
            '445'
            '464'
            '636'
            '3268'
            '3269'
          ]
          destinationAddressPrefix: '10.2.1.0/24'
        }
      }
      {
        name: 'allow-engineering-to-file-shares'
        properties: {
          access: 'Allow'
          direction: 'Inbound'
          priority: 110
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefixes: [
            '10.2.0.0/24'
          ]
          destinationPortRanges: [
            '445'
          ]
          destinationAddressPrefix: '10.2.1.0/24'
        }
      }
      {
        name: 'allow-hr-admin-to-enterprise-servers'
        properties: {
          access: 'Allow'
          direction: 'Inbound'
          priority: 120
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefixes: [
            '10.1.0.4/32' // HR Admin 1
          ]
          destinationPortRanges: [
            '3389'
            '5985'
            '5986'
          ]
          destinationAddressPrefix: '10.2.1.0/24'
        }
      }
    ]
  }
]

param networkPeerings = [
  {
    name: 'hub-to-hr'
    virtualNetworkName: 'hub'
    remoteVirtualNetworkName: 'hr'
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
  }
  {
    name: 'hr-to-hub'
    virtualNetworkName: 'hr'
    remoteVirtualNetworkName: 'hub'
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
  }
  {
    name: 'hub-to-engineering'
    virtualNetworkName: 'hub'
    remoteVirtualNetworkName: 'engineering'
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
  }
  {
    name: 'engineering-to-hub'
    virtualNetworkName: 'engineering'
    remoteVirtualNetworkName: 'hub'
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
  }
  {
    name: 'hub-to-security'
    virtualNetworkName: 'hub'
    remoteVirtualNetworkName: 'security'
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
  }
  {
    name: 'security-to-hub'
    virtualNetworkName: 'security'
    remoteVirtualNetworkName: 'hub'
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
  }
]

param ruleCollectionGroups = [
  {
    name: 'defaultRuleCollectionGroup'
    priority: 100
    ruleCollections:[
      {
        action: {
          type: 'Allow'
        }
        name: 'InboundRuleCollection'
        priority: 110
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        rules: [
          {
            name: 'allow-dev-to-all' // local dev machine access to all resources in the hub VNet
            ruleType: 'NetworkRule'
            destinationAddresses: ['*']
            destinationPorts: ['*']
            ipProtocols: ['TCP', 'UDP']
            sourceAddresses: [devIpAddresses]
          }
          {
            name: 'allow-corp-to-domain-services'
            ruleType: 'NetworkRule'
            destinationAddresses: ['10.2.1.0/24']
            destinationPorts: ['53', '88', '135', '389', '445', '464', '636', '3268', '3269']
            ipProtocols: ['TCP']
            sourceAddresses: ['10.1.0.0/24', '10.2.0.0/24', '10.2.1.0/24']
          }
          {
            name: 'allow-engineering-to-file-shares'
            ruleType: 'NetworkRule'
            destinationAddresses: ['10.2.1.0/24']
            destinationPorts: ['445']
            ipProtocols: ['TCP']
            sourceAddresses: ['10.2.0.0/24']
          }
          {
            name: 'allow-hr-admin-to-enterprise-servers'
            ruleType: 'NetworkRule'
            destinationAddresses: ['10.2.1.0/24']
            destinationPorts: ['3389', '5985', '5986']
            ipProtocols: ['TCP']
            sourceAddresses: ['10.1.0.4/32'] // HR Admin
          }
          {
            name: 'allow security-to-servers'
            ruleType: 'NetworkRule'
            destinationAddresses: ['10.2.1.0/24']
            destinationPorts: ['*']
            ipProtocols: ['TCP', 'UDP']
            sourceAddresses: ['10.3.0.0/24'] // security team subnet
          }
        ]
      }
    ]
  }
]
