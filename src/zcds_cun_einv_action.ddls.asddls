@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Consumption View for e-Invoice Action Ty'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #CUSTOMIZING
}
@Metadata.allowExtensions: true
define root view entity ZCDS_CUN_EINV_ACTION
  provider contract transactional_query
  as projection on ZCDS_INT_EINV_ACTION
{
      @EndUserText.label: 'e-Invoice Type'
      @UI.selectionField: [ { position: 10 } ]
      key EInvoiceType,
      @EndUserText.label: 'Action Type'
      @UI.selectionField: [ { position: 20 } ]
      key ActionType,
      @EndUserText.label: 'Description'
      ActionDescription
}
