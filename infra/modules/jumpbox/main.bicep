@description('os type of the vm')
param osType string
param virtualNetworks array
param vmVnetName string
param vmSubnetName string
param keyVaultName string

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName

  resource secret 'secrets' existing = {
    name: 'adminPassword'
  }
}
  
module vm 'br/public:avm/res/compute/virtual-machine:0.12.2' = {
  name: 'virtualMachineDeployment'
  params:{
    name: take('${osType}-jumpbox-${uniqueString(resourceGroup().id)}', 15)
    adminUsername: 'adminuser'
    adminPassword: keyVault.getSecret('adminPassword')
    imageReference: osType == 'Linux' ? {
      offer: '0001-com-ubuntu-server-jammy'
      publisher: 'Canonical'
      sku: '22_04-lts-gen2'
      version: 'latest'
    } : {
      offer: 'windows-11'
      publisher: 'MicrosoftWindowsDesktop'
      sku: 'win11-23h2-pro'
      version: 'latest'
    }
    nicConfigurations: [
      {
        ipConfigurations: [
          {
            name: 'ipconfig01'
            subnetResourceId: filter(
              filter(virtualNetworks, nw => nw.name == vmVnetName)[0].subnets,
              subnet => subnet.name == vmSubnetName
            )[0].resourceId
          }
        ]
      }
    ]
    osDisk: {
      caching: 'ReadWrite'
      diskSizeGB: 128
      managedDisk: {
        storageAccountType: 'Premium_LRS'
      }
    }
    encryptionAtHost: false
    osType: osType
    vmSize: 'Standard_D2s_v3'
    zone: 0
  }
}
