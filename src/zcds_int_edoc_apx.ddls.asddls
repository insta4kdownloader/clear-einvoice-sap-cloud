@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interface View for Inbound e-Invoice Ite'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #L,
    dataClass: #TRANSACTIONAL
}
define view entity ZCDS_INT_EDOC_APX as select from ztedoc_apx
  /* Both key fields, not just Uuid. A to-parent association has to
     determine exactly one parent row, and the parent's key is now
     UUID + DOCUMENTNUMBER - naming only half of it is rejected. */
  association to parent ZCDS_INT_EDOC_APH as _Document
    on  $projection.Uuid           = _Document.Uuid
    and $projection.DocumentNumber = _Document.DocumentNumber
{
      @EndUserText.label: 'E-Invoice unique document ID'
      /* /StandardBusinessDocument/StandardBusinessDocumentHeader/DocumentIdentification/InstanceIdentifier */
  key uuid as Uuid,
      @EndUserText.label: 'Invoice line ID (BT-126); blank = docume'
      /* /Invoice/cac:InvoiceLine/cbc:ID */
  key line_id as LineId,
      @EndUserText.label: 'Item attribute type'
  key attr_type as AttributeType,
      @EndUserText.label: 'Sequence number'
  key seq as Sequence,
      @EndUserText.label: 'Invoice number (BT-1)'
      /* /Invoice/cbc:ID */
  key documentnumber as DocumentNumber,
      @EndUserText.label: 'Item attribute name (BT-160)'
      /* AdditionalItemProperty/cbc:Name */
      attr_name as AttributeName,
      @EndUserText.label: 'Item attribute name code'
      /* AdditionalItemProperty/cbc:NameCode */
      attr_name_code as AttributeNameCode,
      @EndUserText.label: 'Item attribute value / identifier / code'
      /* AdditionalItemIdentification/cbc:ID | CommodityClassification/cbc:ItemClassificationCode | AdditionalItemPrope */
      attr_value as AttributeValue,
      @EndUserText.label: 'Identifier scheme ID'
      /* AdditionalItemIdentification/cbc:ID/@schemeID */
      attr_scheme as AttributeScheme,
      @EndUserText.label: 'Classification list ID'
      /* CommodityClassification/cbc:ItemClassificationCode/@listID */
      attr_list_id as AttributeListId,
      @EndUserText.label: 'Classification list version ID'
      /* CommodityClassification/cbc:ItemClassificationCode/@listVersionID */
      attr_list_ver as AttributeListVersion,

      _Document
}
