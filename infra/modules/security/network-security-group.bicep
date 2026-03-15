import {NsgConfig} from '../../common/types.bicep'

param nsgs NsgConfig[]

module nsg 'br/public:avm/res/network/network-security-group:0.5.2' = [for nsgConfig in nsgs: {
  params: {
    name: nsgConfig.name
    securityRules: nsgConfig.securityRules
  }
}]

output nsgResourceIds array = [for (nsgConfig, index) in nsgs: {
  name: nsgConfig.name
  resourceId: nsg[index].outputs.resourceId
}]

/*
{
  hr-subnet
  hr-subnet-resourceId
}
*/
