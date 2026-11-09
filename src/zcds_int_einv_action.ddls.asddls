@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interface View for e-Invoice Action Type'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #CUSTOMIZING
}
define root view entity ZCDS_INT_EINV_ACTION as select from zteinv_action
{
  key einv_type as EInvoiceType,
  key action_type as ActionType,
  action_description as ActionDescription
}
