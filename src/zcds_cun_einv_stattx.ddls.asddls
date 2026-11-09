@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Consumption View for e-Invoice Status Te'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #CUSTOMIZING
}
@Metadata.allowExtensions: true
define root view entity ZCDS_CUN_EINV_STATTX
  provider contract transactional_query
  as projection on ZCDS_INT_EINV_STATTX
{
      @EndUserText.label: 'Status Code'
      @UI.selectionField: [ { position: 10 } ]
      key StatusCode,
      @EndUserText.label: 'Status Text'
      StatusText
}
