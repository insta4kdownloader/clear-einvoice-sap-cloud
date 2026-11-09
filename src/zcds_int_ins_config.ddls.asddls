@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interface View for Instrumentation confi'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define root view entity ZCDS_INT_INS_CONFIG as select from ztins_config
{
key projectid as Projectid,
key sysid as Sysid,
key labeltype as Labeltype,
key sequence as Sequence,
low as Low,
high as High
}
