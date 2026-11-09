@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Self-Billed e-Invoice Note'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #L,
    dataClass: #TRANSACTIONAL
}
@Metadata.allowExtensions: true
define view entity ZCDS_CUN_EDOC_SBN
  as projection on ZCDS_INT_EDOC_SBN
{
  key Uuid,
  key LineId,
  key Sequence,
      DocumentNumber,
      SubjectCode,
      NoteText,

      _Document : redirected to parent ZCDS_CUN_EDOC_SBH
}
