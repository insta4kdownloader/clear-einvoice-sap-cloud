@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interface View for e-Invoice Country / C'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #CUSTOMIZING
}
define root view entity ZCDS_INT_EINV_CNTRY as select from zteinv_cntry
{
  key projectid as ProjectId,
  key sysid as SystemId,
  key land1 as Country,
  key bukrs as CompanyCode,
  key sequence as Sequence,
  vat as VatRegistrationNumber,
  land1_desc as CountryDescription,
  auto_einv_generate as AutoGenerate,
  auto_einv_cancel as AutoCancel,
  handler_class as HandlerClass
}
