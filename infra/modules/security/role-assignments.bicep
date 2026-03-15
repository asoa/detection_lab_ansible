param resourceGroupName string
param PrincipalObjectId string
@allowed(['Device', 'ForeignGroup', 'Group', 'ServicePrincipal', 'User'])
param principalType string
param roleIdMap object

// get existing resource group 
resource resourceGroup 'Microsoft.Resources/resourceGroups@2025-04-01' existing = {
  scope: subscription()
  name: resourceGroupName
}

module roleAssignment 'br/public:avm/res/authorization/role-assignment/rg-scope:0.1.1' = [for role in items(roleIdMap): {
  name: guid(subscription().id, resourceGroup.id, PrincipalObjectId, role.value)
  scope: az.resourceGroup(resourceGroupName)
  params: {
    principalId: PrincipalObjectId
    principalType: principalType
    roleDefinitionIdOrName: role.value
  }
}]

// resource role 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for role in items(roleIdMap): {
//   name: guid(subscription().id, resourceGroup.id, PrincipalObjectId, role.value)
//     properties: {
//     principalId: PrincipalObjectId
//     principalType: principalType
//     roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', role.value)
//   }
// }]

output principalId string = PrincipalObjectId
