@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Self-Billed e-Invoice Allowance / charge'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #L,
    dataClass: #TRANSACTIONAL
}
@Metadata.allowExtensions: true
define view entity ZCDS_CUN_EDOC_SBA
  as projection on ZCDS_INT_EDOC_SBA
{
  key Uuid,
  key LineId,
  key Sequence,
      DocumentNumber,
      ChargeIndicator,
      AllowanceChargeReasonCode,
      AllowanceChargeReasonText,
      Multiplier,
      @Semantics.amount.currencyCode: 'Currency'
      Amount,
      @Semantics.amount.currencyCode: 'Currency'
      BaseAmount,
      Currency,
      TaxCategory,
      TaxPercent,
      TaxScheme,
      TaxExemptionReasonCode,
      TaxExemptionReason,

      _Document : redirected to parent ZCDS_CUN_EDOC_SBH
}
