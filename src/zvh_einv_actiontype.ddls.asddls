@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Value Help for e-Invoice Action Type'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.dataCategory: #VALUE_HELP
@ObjectModel.usageType.dataClass: #CUSTOMIZING
@ObjectModel.usageType.serviceQuality: #A
@ObjectModel.usageType.sizeCategory: #S
@ObjectModel.supportedCapabilities: [#CDS_MODELING_ASSOCIATION_TARGET,
                                     #CDS_MODELING_DATA_SOURCE,
                                     #SQL_DATA_SOURCE,
                                     #VALUE_HELP_PROVIDER,
                                     #SEARCHABLE_ENTITY]
@ObjectModel.resultSet.sizeCategory: #XS

define view entity ZVH_EINV_ACTIONTYPE as select from ZCDS_INT_EINV_ACTION
{
  key ActionType
}
group by
  ActionType
