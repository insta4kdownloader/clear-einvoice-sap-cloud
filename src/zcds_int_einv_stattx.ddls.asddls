@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interface View for e-Invoice Status Text'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #CUSTOMIZING
}
define root view entity ZCDS_INT_EINV_STATTX as select from zteinv_stattx
{
  key status_code as StatusCode,
  status_text as StatusText
}
