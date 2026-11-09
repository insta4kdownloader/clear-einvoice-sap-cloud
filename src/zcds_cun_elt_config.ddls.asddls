@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Cunsumption View for ELT Config Details'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
@Metadata.allowExtensions: true
define view entity ZCDS_CUN_ELT_CONFIG as select from ZCDS_INT_ELT_CONFIG
association to parent ZCDS_CUN_COMP_DETAILS as  _COMPANY_DETAILS on 
                               $projection.Projectid = _COMPANY_DETAILS.Projectid
{
key ZCDS_INT_ELT_CONFIG.Projectid,
key ZCDS_INT_ELT_CONFIG.Sysid,
key ZCDS_INT_ELT_CONFIG.Labeltype,
key ZCDS_INT_ELT_CONFIG.Sequence,
ZCDS_INT_ELT_CONFIG.Low,
ZCDS_INT_ELT_CONFIG.High,
  _COMPANY_DETAILS
}
