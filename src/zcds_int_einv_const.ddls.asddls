@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interface View for e-Invoice Generic Con'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #CUSTOMIZING
}
define root view entity ZCDS_INT_EINV_CONST as select from zteinv_const
{
  key projectid as ProjectId,
  key sysid as SystemId,
  key product as Product,
  key land1 as Country,
  key bukrs as CompanyCode,
  key zlabel as LabelCode,
  key sequence as Sequence,
  low as LowValue,
  high as HighValue
}
