@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Consumption View for e-Invoice Reason Co'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #CUSTOMIZING
}
@Metadata.allowExtensions: true
define root view entity ZCDS_CUN_EINV_REASON
  provider contract transactional_query
  as projection on ZCDS_INT_EINV_REASON
{
      @EndUserText.label: 'Action Type'
      @UI.selectionField: [ { position: 10 } ]
      @Consumption.valueHelpDefinition: [ { entity: { name: 'ZVH_EINV_ACTIONTYPE', element: 'ActionType' } } ]
      key ActionType,
      @EndUserText.label: 'Reason Code'
      @UI.selectionField: [ { position: 20 } ]
      key ReasonCode,
      @EndUserText.label: 'Reason Text'
      ReasonText
}
