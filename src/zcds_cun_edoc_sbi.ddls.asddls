@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Self-Billed e-Invoice Invoice line'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #L,
    dataClass: #TRANSACTIONAL
}
@Metadata.allowExtensions: true
define view entity ZCDS_CUN_EDOC_SBI
  as projection on ZCDS_INT_EDOC_SBI
{
  key Uuid,
  key LineId,
      DocumentNumber,
      @Semantics.quantity.unitOfMeasure: 'UnitSap'
      Quantity,
      UnitIso,
      UnitSap,
      Currency,
      @Semantics.amount.currencyCode: 'Currency'
      LineNetAmount,
      @Semantics.amount.currencyCode: 'Currency'
      LineTaxAmount,
      LineAccountingCost,
      PeriodStart,
      PeriodEnd,
      PeriodDescriptionCode,
      DeliveryDate,
      DeliveryTermsId,
      ItemName,
      ItemDescription,
      BuyerItemId,
      SellerItemId,
      StandardItemId,
      StandardItemIdScheme,
      OriginCountry,
      @Semantics.quantity.unitOfMeasure: 'PackUnitSap'
      PackQuantity,
      PackUnitIso,
      PackUnitSap,
      TaxCategory,
      TaxPercent,
      TaxScheme,
      TaxExemptionReasonCode,
      TaxExemptionReason,
      PriceAmount,
      PriceCurrency,
      @Semantics.quantity.unitOfMeasure: 'PriceUnitSap'
      PriceBaseQuantity,
      PriceUnitIso,
      PriceUnitSap,
      PriceAllowanceIndicator,
      PriceAllowanceReasonCode,
      PriceAllowanceReason,
      PriceAllowanceAmount,
      PriceGrossAmount,

      _Document : redirected to parent ZCDS_CUN_EDOC_SBH
}
