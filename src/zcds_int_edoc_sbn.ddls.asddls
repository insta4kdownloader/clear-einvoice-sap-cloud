@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interface View for Self-Billed e-Invoice'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #L,
    dataClass: #TRANSACTIONAL
}
define view entity ZCDS_INT_EDOC_SBN as select from ztedoc_sbn
  association to parent ZCDS_INT_EDOC_SBH as _Document
    on $projection.Uuid = _Document.Uuid
{
      @EndUserText.label: 'E-Invoice unique document ID'
      /* /StandardBusinessDocument/StandardBusinessDocumentHeader/DocumentIdentification/InstanceIdentifier */
  key uuid as Uuid,
      @EndUserText.label: 'Invoice line ID (BT-126); blank = docume'
      /* /Invoice/cac:InvoiceLine/cbc:ID */
  key line_id as LineId,
      @EndUserText.label: 'Sequence number'
  key seq as Sequence,
      @EndUserText.label: 'Invoice number (BT-1)'
      /* /Invoice/cbc:ID */
      documentnumber as DocumentNumber,
      @EndUserText.label: 'Invoice note subject code (BT-21)'
      subject_code as SubjectCode,
      @EndUserText.label: 'Invoice note (BT-22 / BT-127)'
      /* /Invoice/cbc:Note  |  /Invoice/cac:InvoiceLine/cbc:Note */
      note_text as NoteText,

      _Document
}
