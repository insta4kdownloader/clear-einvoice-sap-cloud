@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Inbound e-Invoice Item attribute'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #L,
    dataClass: #TRANSACTIONAL
}
@Metadata.allowExtensions: true
define view entity ZCDS_CUN_EDOC_APX
  as projection on ZCDS_INT_EDOC_APX
{
  key Uuid,
  key LineId,
  key AttributeType,
  key Sequence,
  key DocumentNumber,
      AttributeName,
      AttributeNameCode,
      AttributeValue,
      AttributeScheme,
      AttributeListId,
      AttributeListVersion,

      _Document : redirected to parent ZCDS_CUN_EDOC_APH
}
