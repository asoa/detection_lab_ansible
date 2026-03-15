import {
  VirtualMachineSetConfig
} from '../../common/types.bicep'

@description('Count-based virtual machine configuration to create')
param vmSet VirtualMachineSetConfig
param subnetResourceId string
param existingKeyVaultResourceGroupName string
param existingKeyVaultName string
param role string?

var defaultBootstrapLogDirectory = 'C:\\ProgramData\\OffSec\\EnterpriseBootstrap'
var defaultBootstrapRepositoryDirectory = 'C:\\offsec-ansible'
var bootstrap = vmSet.?bootstrap
var bootstrapEnabled = vmSet.baseConfig.osType == 'Windows' && bootstrap.?enabled == true
var bootstrapCommand = bootstrapEnabled
  ? 'powershell.exe -ExecutionPolicy Bypass -File .\\windows-bootstrap.ps1 -RepositoryUrl "${bootstrap.?repositoryUrl ?? ''}" -BranchOrRef "${bootstrap.?branchOrRef ?? ''}" -PlaybookPath "${bootstrap.?playbookPath ?? ''}" -WslDistribution "${bootstrap.?wslDistribution ?? ''}" -ServiceRole "${bootstrap.?serviceRole ?? ''}" -RepositoryDirectory "${bootstrap.?repositoryDirectory ?? defaultBootstrapRepositoryDirectory}" -LogDirectory "${bootstrap.?logDirectory ?? defaultBootstrapLogDirectory}"${!empty(bootstrap.?domainName ?? '') ? ' -DomainName "${bootstrap.?domainName ?? ''}"' : ''}${!empty(bootstrap.?shareName ?? '') ? ' -ShareName "${bootstrap.?shareName ?? ''}"' : ''}'
  : null
var bootstrapProtectedSettings = bootstrapEnabled
  ? union(
      {
        fileUris: bootstrap.?bootstrapScriptFileUris ?? []
      },
      !empty(bootstrap.?managedIdentityResourceId ?? '')
        ? {
            managedIdentityResourceId: bootstrap.?managedIdentityResourceId
          }
        : {}
    )
  : null

var vms = [for index in range(0, vmSet.count): {
  name: '${vmSet.namePrefix}${padLeft(string(index + 1), 2, '0')}'
  availabilityZone: vmSet.baseConfig.availabilityZone
  nicConfigurations: vmSet.baseConfig.?nicConfigurations
  osDisk: vmSet.baseConfig.?osDisk
  osType: vmSet.baseConfig.osType
  vmSize: vmSet.baseConfig.vmSize
  adminUsername: vmSet.baseConfig.adminUsername
  image: vmSet.baseConfig.image
  bootstrap: bootstrap
  bootstrapCommand: bootstrapCommand
  bootstrapProtectedSettings: bootstrapProtectedSettings
}]

resource keyVault 'Microsoft.KeyVault/vaults@2025-05-01' existing = {
  scope: resourceGroup(existingKeyVaultResourceGroupName)
  name: existingKeyVaultName

  resource secret 'secrets' existing = {
    name: 'adminPassword'
  }
}

module vm 'br/public:avm/res/compute/virtual-machine:0.21.0' = [for (vm, index) in vms: {
  params: {
    name: vm.name
    adminUsername: vm.adminUsername
    adminPassword: keyVault.getSecret('adminPassword')
    imageReference: {
      offer: vm.image.offer
      publisher: vm.image.publisher
      sku: vm.image.sku
      version: vm.image.version
    }
    osDisk: {
      caching: 'ReadWrite'
      diskSizeGB: vm.?osDisk.?diskSizeGB ?? 128
      managedDisk:{
        storageAccountType: 'StandardSSD_LRS'
      }
    }
    availabilityZone: vm.availabilityZone
    nicConfigurations: [
      {
        ipConfigurations: [
          {
            name: 'ipconfig${padLeft(string(index + 1), 2, '0')}'
            subnetResourceId: subnetResourceId
            privateIPAllocationMethod: 'Dynamic'
          }
        ]
      }
    ]
    osType: vm.osType
    vmSize: vm.vmSize
    customData: (vm.osType == 'Linux' && role == 'kali') ? loadFileAsBase64('kali-init.yaml') : null
    extensionCustomScriptConfig: (vm.osType == 'Windows' && vm.?bootstrap.?enabled == true) ? {
      forceUpdateTag: vm.?bootstrap.?forceUpdateTag ?? 'enterprise-bootstrap-${vm.name}'
      protectedSettings: vm.?bootstrapProtectedSettings
      settings: {
        commandToExecute: vm.?bootstrapCommand ?? ''
      }
    } : null
    // : (vm.osType == 'Linux' && role == 'elk') ? loadFileAsBase64('elk-init.yaml')
    // : (vm.osType == 'Linux' && role == 'onion') ? loadFileAsBase64('onion-init.yaml')
  }
}]
