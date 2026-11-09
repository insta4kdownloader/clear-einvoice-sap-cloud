@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interface View for Self-Billed e-Invoice'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #L,
    dataClass: #TRANSACTIONAL
}
define view entity ZCDS_INT_EDOC_SBR as select from ztedoc_sbr
  association to parent ZCDS_INT_EDOC_SBH as _Document
    on $projection.Uuid = _Document.Uuid
{
      @EndUserText.label: 'E-Invoice unique document ID'
      /* /StandardBusinessDocument/StandardBusinessDocumentHeader/DocumentIdentification/InstanceIdentifier */
  key uuid as Uuid,
      @EndUserText.label: 'Invoice line ID (BT-126); blank = docume'
      /* /Invoice/cac:InvoiceLine/cbc:ID */
  key line_id as LineId,
      @EndUserText.label: 'Document reference type'
  key ref_type as ReferenceType,
      @EndUserText.label: 'Sequence number'
  key seq as Sequence,
      @EndUserText.label: 'Invoice number (BT-1)'
      /* /Invoice/cbc:ID */
      documentnumber as DocumentNumber,
      @EndUserText.label: 'Referenced document ID'
      /* <ref>/cbc:ID */
      ref_id as ReferenceId,
      @EndUserText.label: 'Identifier scheme ID'
      /* <ref>/cbc:ID/@schemeID */
      ref_id_sch as ReferenceIdScheme,
      @EndUserText.label: 'Referenced line ID'
      /* <ref>/cbc:LineID  |  BillingReferenceLine/cbc:ID */
      ref_line_id as ReferenceLineId,
      @EndUserText.label: 'Sales order reference (BT-14)'
      /* OrderReference/cbc:SalesOrderID */
      so_id as SalesOrderId,
      @EndUserText.label: 'Sales order line reference'
      /* OrderLineReference/cbc:SalesOrderLineID */
      so_line_id as SalesOrderLineId,
      @EndUserText.label: 'Referenced document issue date'
      /* <ref>/cbc:IssueDate */
      ref_date as ReferenceDate,
      @EndUserText.label: 'Referenced document type code'
      /* <ref>/cbc:DocumentTypeCode */
      doc_type_code as DocumentTypeCode,
      @EndUserText.label: 'Referenced document status code'
      /* <ref>/cbc:DocumentStatusCode */
      doc_status_code as DocumentStatusCode,
      @EndUserText.label: 'Referenced document description'
      /* <ref>/cbc:DocumentDescription */
      ref_desc as ReferenceDescription,
      @EndUserText.label: 'Referenced document UUID'
      /* <ref>/cbc:UUID */
      ref_uuid as ReferenceUuid,
      @EndUserText.label: 'Referenced amount'
      /* BillingReferenceLine/cbc:Amount */
      @Semantics.amount.currencyCode: 'ReferenceCurrency'
      ref_amount as ReferenceAmount,
      @EndUserText.label: 'Referenced amount currency'
      /* BillingReferenceLine/cbc:Amount/@currencyID */
      ref_curr as ReferenceCurrency,
      @EndUserText.label: 'Attachment MIME code'
      /* AdditionalDocumentReference/cac:Attachment/cbc:EmbeddedDocumentBinaryObject/@mimeCode */
      att_mime as AttachmentMimeType,
      @EndUserText.label: 'Attachment file name'
      /* .../cbc:EmbeddedDocumentBinaryObject/@filename */
      att_filename as AttachmentFilename,
      @EndUserText.label: 'Attachment content (base64)'
      /* .../cbc:EmbeddedDocumentBinaryObject */
      att_content as AttachmentContent,
      @EndUserText.label: 'External document location'
      /* .../cac:Attachment/cac:ExternalReference/cbc:URI */
      att_uri as AttachmentUri,

      _Document
}
