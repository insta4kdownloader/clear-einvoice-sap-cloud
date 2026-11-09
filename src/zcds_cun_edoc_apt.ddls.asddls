@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Inbound e-Invoice VAT breakdown'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #L,
    dataClass: #TRANSACTIONAL
}
@Metadata.allowExtensions: true
define view entity ZCDS_CUN_EDOC_APT
  as projection on ZCDS_INT_EDOC_APT
{
  key Uuid,
  key Sequence,
  key DocumentNumber,
      @Semantics.amount.currencyCode: 'Currency'
      TaxableAmount,
      @Semantics.amount.currencyCode: 'Currency'
      TaxAmount,
      Currency,
      TaxCategory,
      TaxPercent,
      TaxScheme,
      TaxExemptionReasonCode,
      TaxExemptionReason,

      _Document : redirected to parent ZCDS_CUN_EDOC_APH
}
