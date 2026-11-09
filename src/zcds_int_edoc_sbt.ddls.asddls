@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interface View for Self-Billed e-Invoice'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #L,
    dataClass: #TRANSACTIONAL
}
define view entity ZCDS_INT_EDOC_SBT as select from ztedoc_sbt
  association to parent ZCDS_INT_EDOC_SBH as _Document
    on $projection.Uuid = _Document.Uuid
{
      @EndUserText.label: 'E-Invoice unique document ID'
      /* /StandardBusinessDocument/StandardBusinessDocumentHeader/DocumentIdentification/InstanceIdentifier */
  key uuid as Uuid,
      @EndUserText.label: 'Sequence number'
  key seq as Sequence,
      @EndUserText.label: 'Invoice number (BT-1)'
      /* /Invoice/cbc:ID */
      documentnumber as DocumentNumber,
      @EndUserText.label: 'VAT category taxable amount (BT-116)'
      /* /Invoice/cac:TaxTotal/cac:TaxSubtotal/cbc:TaxableAmount */
      @Semantics.amount.currencyCode: 'Currency'
      taxable_amt as TaxableAmount,
      @EndUserText.label: 'VAT category tax amount (BT-117)'
      /* /Invoice/cac:TaxTotal/cac:TaxSubtotal/cbc:TaxAmount */
      @Semantics.amount.currencyCode: 'Currency'
      tax_amt as TaxAmount,
      @EndUserText.label: 'Currency'
      /* /Invoice/cac:TaxTotal/cac:TaxSubtotal/cbc:TaxAmount/@currencyID */
      currency as Currency,
      @EndUserText.label: 'VAT category code'
      /* /Invoice/cac:TaxTotal/cac:TaxSubtotal/cac:TaxCategory/cbc:ID */
      tax_cat as TaxCategory,
      @EndUserText.label: 'VAT rate'
      /* /Invoice/cac:TaxTotal/cac:TaxSubtotal/cac:TaxCategory/cbc:Percent */
      tax_percent as TaxPercent,
      @EndUserText.label: 'Tax scheme ID'
      /* /Invoice/cac:TaxTotal/cac:TaxSubtotal/cac:TaxCategory/cac:TaxScheme/cbc:ID */
      tax_scheme as TaxScheme,
      @EndUserText.label: 'VAT exemption reason code'
      /* /Invoice/cac:TaxTotal/cac:TaxSubtotal/cac:TaxCategory/cbc:TaxExemptionReasonCode */
      tax_exe_rsn_code as TaxExemptionReasonCode,
      @EndUserText.label: 'VAT exemption reason text'
      /* /Invoice/cac:TaxTotal/cac:TaxSubtotal/cac:TaxCategory/cbc:TaxExemptionReason */
      tax_exe_rsn as TaxExemptionReason,

      _Document
}
