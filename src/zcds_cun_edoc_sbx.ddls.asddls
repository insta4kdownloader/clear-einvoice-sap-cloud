@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Self-Billed e-Invoice Item attribute'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #L,
    dataClass: #TRANSACTIONAL
}
@Metadata.allowExtensions: true
define view entity ZCDS_CUN_EDOC_SBX
  as projection on ZCDS_INT_EDOC_SBX
{
  key Uuid,
  key LineId,
  key AttributeType,
  key Sequence,
      DocumentNumber,
      AttributeName,
      AttributeNameCode,
      AttributeValue,
      AttributeScheme,
      AttributeListId,
      AttributeListVersion,

      _Document : redirected to parent ZCDS_CUN_EDOC_SBH
}
