@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Cunsumption View for Instrumentation con'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
@Metadata.allowExtensions: true 
define view entity ZCDS_CUN_INS_CONFIG as select from ZCDS_INT_INS_CONFIG
association to parent ZCDS_CUN_COMP_DETAILS as  _COMPANY_DETAILS on 
                               $projection.Projectid = _COMPANY_DETAILS.Projectid
    
{
key ZCDS_INT_INS_CONFIG.Projectid,
key ZCDS_INT_INS_CONFIG.Sysid,
key ZCDS_INT_INS_CONFIG.Labeltype,
key ZCDS_INT_INS_CONFIG.Sequence,
ZCDS_INT_INS_CONFIG.Low,
ZCDS_INT_INS_CONFIG.High,
    _COMPANY_DETAILS // Make association public
}
