@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interface View for e-Invoice Status Mapp'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #CUSTOMIZING
}
define root view entity ZCDS_INT_EINV_STATUS as select from zteinv_status
{
  key projectid as ProjectId,
  key sysid as SystemId,
  key land1 as Country,
  key bukrs as CompanyCode,
  key sequence as Sequence,
  key proc_mode as ProcessingMode,
  status as Status,
  status_to_be as TargetStatus,
  status_desc as StatusDescription,
  criticality as Criticality
}
