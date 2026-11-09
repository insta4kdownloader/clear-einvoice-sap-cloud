@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interface View for Inbound e-Invoice Inv'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #L,
    dataClass: #TRANSACTIONAL
}
define view entity ZCDS_INT_EDOC_API as select from ztedoc_api
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
      @EndUserText.label: 'Invoice number (BT-1)'
      /* /Invoice/cbc:ID */
  key documentnumber as DocumentNumber,
      @EndUserText.label: 'Invoiced quantity (BT-129)'
      /* /Invoice/cac:InvoiceLine/cbc:InvoicedQuantity */
      @Semantics.quantity.unitOfMeasure: 'UnitSap'
      quantity as Quantity,
      @EndUserText.label: 'Unit of measure, UN/ECE Rec.20 code'
      /* /Invoice/cac:InvoiceLine/cbc:InvoicedQuantity/@unitCode */
      unit_iso as UnitIso,
      @EndUserText.label: 'Unit of measure (SAP internal)'
      unit_sap as UnitSap,
      @EndUserText.label: 'Line currency'
      /* /Invoice/cac:InvoiceLine/cbc:LineExtensionAmount/@currencyID */
      currency as Currency,
      @EndUserText.label: 'Invoice line net amount (BT-131)'
      /* /Invoice/cac:InvoiceLine/cbc:LineExtensionAmount */
      @Semantics.amount.currencyCode: 'Currency'
      line_net_amt as LineNetAmount,
      @EndUserText.label: 'Invoice line VAT amount'
      /* /Invoice/cac:InvoiceLine/cac:TaxTotal/cbc:TaxAmount */
      @Semantics.amount.currencyCode: 'Currency'
      line_tax_amt as LineTaxAmount,
      @EndUserText.label: 'Buyer accounting reference (BT-19)'
      /* /Invoice/cac:InvoiceLine/cbc:AccountingCost */
      line_acc_cost as LineAccountingCost,
      @EndUserText.label: 'Invoicing period start date'
      /* /Invoice/cac:InvoiceLine/cac:InvoicePeriod/cbc:StartDate */
      period_start as PeriodStart,
      @EndUserText.label: 'Invoicing period end date'
      /* /Invoice/cac:InvoiceLine/cac:InvoicePeriod/cbc:EndDate */
      period_end as PeriodEnd,
      @EndUserText.label: 'Invoicing period description code'
      /* /Invoice/cac:InvoiceLine/cac:InvoicePeriod/cbc:DescriptionCode */
      period_desc_code as PeriodDescriptionCode,
      @EndUserText.label: 'Actual delivery date (BT-72)'
      /* /Invoice/cac:InvoiceLine/cac:Delivery/cbc:ActualDeliveryDate */
      del_date as DeliveryDate,
      @EndUserText.label: 'Delivery terms (Incoterms)'
      /* /Invoice/cac:InvoiceLine/cac:DeliveryTerms/cbc:ID */
      del_terms_id as DeliveryTermsId,
      @EndUserText.label: 'Item name (BT-153)'
      /* /Invoice/cac:InvoiceLine/cac:Item/cbc:Name */
      item_name as ItemName,
      @EndUserText.label: 'Item description (BT-154)'
      /* /Invoice/cac:InvoiceLine/cac:Item/cbc:Description */
      item_desc as ItemDescription,
      @EndUserText.label: 'Item buyers identifier (BT-156)'
      /* /Invoice/cac:InvoiceLine/cac:Item/cac:BuyersItemIdentification/cbc:ID */
      buyer_item_id as BuyerItemId,
      @EndUserText.label: 'Item sellers identifier (BT-155)'
      /* /Invoice/cac:InvoiceLine/cac:Item/cac:SellersItemIdentification/cbc:ID */
      seller_item_id as SellerItemId,
      @EndUserText.label: 'Item standard identifier (BT-157)'
      /* /Invoice/cac:InvoiceLine/cac:Item/cac:StandardItemIdentification/cbc:ID */
      std_item_id as StandardItemId,
      @EndUserText.label: 'Identifier scheme ID'
      /* /Invoice/cac:InvoiceLine/cac:Item/cac:StandardItemIdentification/cbc:ID/@schemeID */
      std_item_id_sch as StandardItemIdScheme,
      @EndUserText.label: 'Item country of origin (BT-159)'
      /* /Invoice/cac:InvoiceLine/cac:Item/cac:OriginCountry/cbc:IdentificationCode */
      origin_country as OriginCountry,
      @EndUserText.label: 'Pack quantity'
      /* /Invoice/cac:InvoiceLine/cac:Item/cbc:PackQuantity */
      @Semantics.quantity.unitOfMeasure: 'PackUnitSap'
      pack_qty as PackQuantity,
      @EndUserText.label: 'Unit of measure, UN/ECE Rec.20 code'
      /* /Invoice/cac:InvoiceLine/cac:Item/cbc:PackQuantity/@unitCode */
      pack_unit_iso as PackUnitIso,
      @EndUserText.label: 'Pack unit (SAP internal)'
      pack_unit_sap as PackUnitSap,
      @EndUserText.label: 'VAT category code'
      /* /Invoice/cac:InvoiceLine/cac:Item/cac:ClassifiedTaxCategory/cbc:ID */
      tax_cat as TaxCategory,
      @EndUserText.label: 'VAT rate'
      /* /Invoice/cac:InvoiceLine/cac:Item/cac:ClassifiedTaxCategory/cbc:Percent */
      tax_percent as TaxPercent,
      @EndUserText.label: 'Tax scheme ID'
      /* /Invoice/cac:InvoiceLine/cac:Item/cac:ClassifiedTaxCategory/cac:TaxScheme/cbc:ID */
      tax_scheme as TaxScheme,
      @EndUserText.label: 'VAT exemption reason code'
      /* /Invoice/cac:InvoiceLine/cac:Item/cac:ClassifiedTaxCategory/cbc:TaxExemptionReasonCode */
      tax_exe_rsn_code as TaxExemptionReasonCode,
      @EndUserText.label: 'VAT exemption reason text'
      /* /Invoice/cac:InvoiceLine/cac:Item/cac:ClassifiedTaxCategory/cbc:TaxExemptionReason */
      tax_exe_rsn as TaxExemptionReason,
      @EndUserText.label: 'Item net price (BT-146)'
      /* /Invoice/cac:InvoiceLine/cac:Price/cbc:PriceAmount */
      price_amt as PriceAmount,
      @EndUserText.label: 'Price currency'
      /* /Invoice/cac:InvoiceLine/cac:Price/cbc:PriceAmount/@currencyID */
      price_curr as PriceCurrency,
      @EndUserText.label: 'Item price base quantity (BT-149)'
      /* /Invoice/cac:InvoiceLine/cac:Price/cbc:BaseQuantity */
      @Semantics.quantity.unitOfMeasure: 'PriceUnitSap'
      price_base_qty as PriceBaseQuantity,
      @EndUserText.label: 'Unit of measure, UN/ECE Rec.20 code'
      /* /Invoice/cac:InvoiceLine/cac:Price/cbc:BaseQuantity/@unitCode */
      price_unit_iso as PriceUnitIso,
      @EndUserText.label: 'Price base unit (SAP internal)'
      price_unit_sap as PriceUnitSap,
      @EndUserText.label: 'Charge indicator'
      /* /Invoice/cac:InvoiceLine/cac:Price/cac:AllowanceCharge/cbc:ChargeIndicator */
      price_allow_ind as PriceAllowanceIndicator,
      @EndUserText.label: 'Allowance / charge reason code'
      /* /Invoice/cac:InvoiceLine/cac:Price/cac:AllowanceCharge/cbc:AllowanceChargeReasonCode */
      price_allow_rsn_code as PriceAllowanceReasonCode,
      @EndUserText.label: 'Allowance / charge reason'
      /* /Invoice/cac:InvoiceLine/cac:Price/cac:AllowanceCharge/cbc:AllowanceChargeReason */
      price_allow_rsn as PriceAllowanceReason,
      @EndUserText.label: 'Item price discount (BT-147)'
      /* /Invoice/cac:InvoiceLine/cac:Price/cac:AllowanceCharge/cbc:Amount */
      price_allow_amt as PriceAllowanceAmount,
      @EndUserText.label: 'Item gross price (BT-148)'
      /* /Invoice/cac:InvoiceLine/cac:Price/cac:AllowanceCharge/cbc:BaseAmount */
      price_gross_amt as PriceGrossAmount,

      _Document
}
