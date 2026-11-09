@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Inbound e-Invoice Note'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #L,
    dataClass: #TRANSACTIONAL
}
@Metadata.allowExtensions: true
define view entity ZCDS_CUN_EDOC_APN
  as projection on ZCDS_INT_EDOC_APN
{
  key Uuid,
  key LineId,
  key Sequence,
  key DocumentNumber,
      SubjectCode,
      NoteText,

      _Document : redirected to parent ZCDS_CUN_EDOC_APH
}
