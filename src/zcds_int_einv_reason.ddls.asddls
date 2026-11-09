@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interface View for e-Invoice Reason Code'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #CUSTOMIZING
}
define root view entity ZCDS_INT_EINV_REASON as select from zteinv_reason
{
  key action_type as ActionType,
  key reason_code as ReasonCode,
  reason_text as ReasonText
}
