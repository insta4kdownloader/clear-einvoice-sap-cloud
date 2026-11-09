@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interface View for e-Invoice API Endpoin'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #CUSTOMIZING
}
define root view entity ZCDS_INT_EINV_API as select from zteinv_api
{
  key projectid as ProjectId,
  key sysid as SystemId,
  key land1 as Country,
  key bukrs as CompanyCode,
  key functionality as Functionality,
  key sequence as Sequence,
  url as EndpointUrl,
  param_name as ParameterName,
  param_value as ParameterValue
}
