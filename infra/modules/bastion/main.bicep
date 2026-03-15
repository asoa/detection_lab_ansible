param virtualNetworks array
param bastionVnetName string
param enableZones bool = false

var zones = enableZones ? [ 1,2,3 ] : []

module pip 'br/public:avm/res/network/public-ip-address:0.12.0' = {
  name: 'bastion-ip'
  params: {
    name: take('pip-bastion${uniqueString(resourceGroup().id)}', 20)
    availabilityZones: enableZones ? zones : []
  }
}

module bastion 'br/public:avm/res/network/bastion-host:0.8.2' = {
  name: 'bastion'
  params: {
    name: take('bastion-${uniqueString(resourceGroup().id)}', 15)
    bastionSubnetPublicIpResourceId: pip.outputs.resourceId
    skuName: 'Standard'
    virtualNetworkResourceId: filter(virtualNetworks, (nw) => nw.name == bastionVnetName)[0].resourceId
    enableFileCopy: true
  }
}
