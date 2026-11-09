@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interface View for Self-Billed e-Invoice'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #L,
    dataClass: #TRANSACTIONAL
}
define view entity ZCDS_INT_EDOC_SBA as select from ztedoc_sba
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
      @EndUserText.label: 'Charge indicator'
      /* <scope>/cac:AllowanceCharge/cbc:ChargeIndicator */
      charge_ind as ChargeIndicator,
      @EndUserText.label: 'Allowance / charge reason code'
      /* <scope>/cac:AllowanceCharge/cbc:AllowanceChargeReasonCode */
      ac_rsn_code as AllowanceChargeReasonCode,
      @EndUserText.label: 'Allowance / charge reason'
      /* <scope>/cac:AllowanceCharge/cbc:AllowanceChargeReason */
      ac_rsn_text as AllowanceChargeReasonText,
      @EndUserText.label: 'Allowance / charge percentage'
      /* <scope>/cac:AllowanceCharge/cbc:MultiplierFactorNumeric */
      multiplier as Multiplier,
      @EndUserText.label: 'Allowance / charge amount'
      /* <scope>/cac:AllowanceCharge/cbc:Amount */
      @Semantics.amount.currencyCode: 'Currency'
      amount as Amount,
      @EndUserText.label: 'Allowance / charge base amount'
      /* <scope>/cac:AllowanceCharge/cbc:BaseAmount */
      @Semantics.amount.currencyCode: 'Currency'
      base_amt as BaseAmount,
      @EndUserText.label: 'Currency'
      /* <scope>/cac:AllowanceCharge/cbc:Amount/@currencyID */
      currency as Currency,
      @EndUserText.label: 'VAT category code'
      /* <scope>/cac:AllowanceCharge/cac:TaxCategory/cbc:ID */
      tax_cat as TaxCategory,
      @EndUserText.label: 'VAT rate'
      /* <scope>/cac:AllowanceCharge/cac:TaxCategory/cbc:Percent */
      tax_percent as TaxPercent,
      @EndUserText.label: 'Tax scheme ID'
      /* <scope>/cac:AllowanceCharge/cac:TaxCategory/cac:TaxScheme/cbc:ID */
      tax_scheme as TaxScheme,
      @EndUserText.label: 'VAT exemption reason code'
      /* <scope>/cac:AllowanceCharge/cac:TaxCategory/cbc:TaxExemptionReasonCode */
      tax_exe_rsn_code as TaxExemptionReasonCode,
      @EndUserText.label: 'VAT exemption reason text'
      /* <scope>/cac:AllowanceCharge/cac:TaxCategory/cbc:TaxExemptionReason */
      tax_exe_rsn as TaxExemptionReason,

      _Document
}
