@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Self-Billed e-Invoice Document reference'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #L,
    dataClass: #TRANSACTIONAL
}
@Metadata.allowExtensions: true
define view entity ZCDS_CUN_EDOC_SBR
  as projection on ZCDS_INT_EDOC_SBR
{
  key Uuid,
  key LineId,
  key ReferenceType,
  key Sequence,
      DocumentNumber,
      ReferenceId,
      ReferenceIdScheme,
      ReferenceLineId,
      SalesOrderId,
      SalesOrderLineId,
      ReferenceDate,
      DocumentTypeCode,
      DocumentStatusCode,
      ReferenceDescription,
      ReferenceUuid,
      @Semantics.amount.currencyCode: 'ReferenceCurrency'
      ReferenceAmount,
      ReferenceCurrency,
      AttachmentMimeType,
      AttachmentFilename,
      AttachmentContent,
      AttachmentUri,

      _Document : redirected to parent ZCDS_CUN_EDOC_SBH
}
