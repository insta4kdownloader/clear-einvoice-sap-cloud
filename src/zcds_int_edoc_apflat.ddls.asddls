/* =====================================================================
   Inbound e-Invoice (AP) - one flat row per invoice line.

   Header, line and the document-level seller and buyer, joined into a single
   wide row. This is what to read, download or build an analytical query over
   when you want to see the model's contents without walking eight tables.

   What it deliberately does NOT flatten: notes, VAT subtotals, allowances and
   charges, document references and item attributes. Each of those is 0..n per
   document OR per line, so folding them in would multiply the rows and make
   every amount on the row wrong when summed. They are reachable as tabs on the
   object page of ZCDS_CUN_EDOC_APH, and each is a view of its own.

   The join to the parties is on the document-level row (LINE_ID blank) of the
   SELLER and BUYER roles - a line-level party is an item manufacturer.
   ===================================================================== */
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Inbound e-Invoice - one row per line'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #C,
    sizeCategory: #L,
    dataClass: #TRANSACTIONAL
}
define view entity ZCDS_INT_EDOC_APFLAT
  as select from ZCDS_INT_EDOC_APH as h
    inner join      ZCDS_INT_EDOC_API as i  on  h.Uuid = i.Uuid
                                            and h.DocumentNumber = i.DocumentNumber
    left outer join ZCDS_INT_EDOC_APP as sp on  h.Uuid      = sp.Uuid
                                      and h.DocumentNumber = sp.DocumentNumber
                                      and sp.LineId   = ''
                                      and sp.PartyRole = 'SELLER'
    left outer join ZCDS_INT_EDOC_APP as bp on  h.Uuid      = bp.Uuid
                                      and h.DocumentNumber = bp.DocumentNumber
                                      and bp.LineId   = ''
                                      and bp.PartyRole = 'BUYER'
{
  key h.Uuid as Uuid,
  key i.LineId as LineId,

  key h.DocumentNumber as DocumentNumber,
      h.DocumentId as DocumentId,
      h.Status as Status,
      h.ActionType as ActionType,
      h.ReasonCode as ReasonCode,
      h.MatchStatus as MatchStatus,
      h.CommentText as CommentText,
      h.ApiMessage as ApiMessage,
      h.UblVersionId as UblVersionId,
      h.CustomizationId as CustomizationId,
      h.ProfileId as ProfileId,
      h.SbdhDocumentTypeId as SbdhDocumentTypeId,
      h.SbdhProcessId as SbdhProcessId,
      h.SbdhCountry as SbdhCountry,
      h.SbdhSenderId as SbdhSenderId,
      h.SbdhReceiverId as SbdhReceiverId,
      h.SbdhCreatedTimestamp as SbdhCreatedTimestamp,
      h.IssueDate as IssueDate,
      h.IssueTime as IssueTime,
      h.DueDate as DueDate,
      h.InvoiceTypeCode as InvoiceTypeCode,
      h.InvoiceTypeName as InvoiceTypeName,
      h.TaxPointDate as TaxPointDate,
      h.Currency as Currency,
      h.TaxCurrency as TaxCurrency,
      h.AccountingCost as AccountingCost,
      h.BuyerReference as BuyerReference,
      h.PeriodStart as PeriodStart,
      h.PeriodEnd as PeriodEnd,
      h.PeriodDescriptionCode as PeriodDescriptionCode,
      h.TaxExchangeSourceCurrency as TaxExchangeSourceCurrency,
      h.TaxExchangeTargetCurrency as TaxExchangeTargetCurrency,
      h.TaxExchangeRate as TaxExchangeRate,
      h.TaxExchangeDate as TaxExchangeDate,
      @Semantics.amount.currencyCode: 'Currency'
      h.LineExtensionAmount as LineExtensionAmount,
      @Semantics.amount.currencyCode: 'Currency'
      h.AllowanceTotal as AllowanceTotal,
      @Semantics.amount.currencyCode: 'Currency'
      h.ChargeTotal as ChargeTotal,
      @Semantics.amount.currencyCode: 'Currency'
      h.TaxExclusiveAmount as TaxExclusiveAmount,
      @Semantics.amount.currencyCode: 'Currency'
      h.VatTotal as VatTotal,
      @Semantics.amount.currencyCode: 'Currency'
      h.TaxInclusiveAmount as TaxInclusiveAmount,
      @Semantics.amount.currencyCode: 'Currency'
      h.PrepaidAmount as PrepaidAmount,
      @Semantics.amount.currencyCode: 'Currency'
      h.PayableRoundingAmount as PayableRoundingAmount,
      @Semantics.amount.currencyCode: 'Currency'
      h.PayableAmount as PayableAmount,
      @Semantics.amount.currencyCode: 'TaxCurrency'
      h.VatTotalTaxCurrency as VatTotalTaxCurrency,
      h.ActualDeliveryDate as ActualDeliveryDate,
      h.DeliveryLocationId as DeliveryLocationId,
      h.DeliveryLocationIdScheme as DeliveryLocationIdScheme,
      h.DeliveryTermsId as DeliveryTermsId,
      h.PaymentMeansCode as PaymentMeansCode,
      h.PaymentMeansName as PaymentMeansName,
      h.PaymentMeansId as PaymentMeansId,
      h.PaymentInstructionNote as PaymentInstructionNote,
      h.PaymentId as PaymentId,
      h.PayeeAccountId as PayeeAccountId,
      h.PayeeAccountScheme as PayeeAccountScheme,
      h.PayeeAccountName as PayeeAccountName,
      h.PayeeBranchId as PayeeBranchId,
      h.CardAccountId as CardAccountId,
      h.CardNetwork as CardNetwork,
      h.CardHolder as CardHolder,
      h.MandateId as MandateId,
      h.PayerAccountId as PayerAccountId,
      h.PaymentTermsId as PaymentTermsId,
      h.PaymentTermsNote as PaymentTermsNote,
      @Semantics.amount.currencyCode: 'PaymentTermsCurrency'
      h.PaymentTermsAmount as PaymentTermsAmount,
      h.PaymentTermsCurrency as PaymentTermsCurrency,
      h.PaymentTermsDueDate as PaymentTermsDueDate,
      h.PrepaidId as PrepaidId,
      @Semantics.amount.currencyCode: 'PrepaidCurrency'
      h.PrepaidPaidAmount as PrepaidPaidAmount,
      h.PrepaidCurrency as PrepaidCurrency,
      h.PrepaidReceivedDate as PrepaidReceivedDate,
      h.PrepaidInstructionId as PrepaidInstructionId,
      h.LineCount as LineCount,
      h.CreatedOn as CreatedOn,
      h.CreatedAt as CreatedAt,
      h.CreatedBy as CreatedBy,
      h.ChangedOn as ChangedOn,
      h.ChangedAt as ChangedAt,
      h.ChangedBy as ChangedBy,

      @Semantics.quantity.unitOfMeasure: 'UnitSap'
      i.Quantity as Quantity,
      i.UnitIso as UnitIso,
      i.UnitSap as UnitSap,
      i.Currency as LineCurrency,
      @Semantics.amount.currencyCode: 'LineCurrency'
      i.LineNetAmount as LineNetAmount,
      @Semantics.amount.currencyCode: 'LineCurrency'
      i.LineTaxAmount as LineTaxAmount,
      i.LineAccountingCost as LineAccountingCost,
      i.PeriodStart as LinePeriodStart,
      i.PeriodEnd as LinePeriodEnd,
      i.PeriodDescriptionCode as LinePeriodDescriptionCode,
      i.DeliveryDate as DeliveryDate,
      i.DeliveryTermsId as LineDeliveryTermsId,
      i.ItemName as ItemName,
      i.ItemDescription as ItemDescription,
      i.BuyerItemId as BuyerItemId,
      i.SellerItemId as SellerItemId,
      i.StandardItemId as StandardItemId,
      i.StandardItemIdScheme as StandardItemIdScheme,
      i.OriginCountry as OriginCountry,
      @Semantics.quantity.unitOfMeasure: 'PackUnitSap'
      i.PackQuantity as PackQuantity,
      i.PackUnitIso as PackUnitIso,
      i.PackUnitSap as PackUnitSap,
      i.TaxCategory as TaxCategory,
      i.TaxPercent as TaxPercent,
      i.TaxScheme as TaxScheme,
      i.TaxExemptionReasonCode as TaxExemptionReasonCode,
      i.TaxExemptionReason as TaxExemptionReason,
      i.PriceAmount as PriceAmount,
      i.PriceCurrency as PriceCurrency,
      @Semantics.quantity.unitOfMeasure: 'PriceUnitSap'
      i.PriceBaseQuantity as PriceBaseQuantity,
      i.PriceUnitIso as PriceUnitIso,
      i.PriceUnitSap as PriceUnitSap,
      i.PriceAllowanceIndicator as PriceAllowanceIndicator,
      i.PriceAllowanceReasonCode as PriceAllowanceReasonCode,
      i.PriceAllowanceReason as PriceAllowanceReason,
      i.PriceAllowanceAmount as PriceAllowanceAmount,
      i.PriceGrossAmount as PriceGrossAmount,

      @EndUserText.label: 'Seller'
      sp.PartyName        as SellerName,
      @EndUserText.label: 'Seller VAT ID'
      sp.VatId            as SellerVatId,
      @EndUserText.label: 'Seller Endpoint'
      sp.EndpointId       as SellerEndpointId,
      @EndUserText.label: 'Seller Street'
      sp.Street           as SellerStreet,
      @EndUserText.label: 'Seller City'
      sp.City             as SellerCity,
      @EndUserText.label: 'Seller Postal Code'
      sp.PostalZone       as SellerPostalZone,
      @EndUserText.label: 'Seller Country'
      sp.Country          as SellerCountry,
      @EndUserText.label: 'Seller Registered Name'
      sp.RegistrationName as SellerRegistrationName,
      @EndUserText.label: 'Seller Legal ID'
      sp.LegalId          as SellerLegalId,
      @EndUserText.label: 'Seller Contact'
      sp.ContactName      as SellerContactName,
      @EndUserText.label: 'Seller E-Mail'
      sp.ContactMail      as SellerContactMail,

      @EndUserText.label: 'Buyer'
      bp.PartyName        as BuyerName,
      @EndUserText.label: 'Buyer VAT ID'
      bp.VatId            as BuyerVatId,
      @EndUserText.label: 'Buyer Endpoint'
      bp.EndpointId       as BuyerEndpointId,
      @EndUserText.label: 'Buyer Street'
      bp.Street           as BuyerStreet,
      @EndUserText.label: 'Buyer City'
      bp.City             as BuyerCity,
      @EndUserText.label: 'Buyer Postal Code'
      bp.PostalZone       as BuyerPostalZone,
      @EndUserText.label: 'Buyer Country'
      bp.Country          as BuyerCountry,
      @EndUserText.label: 'Buyer Registered Name'
      bp.RegistrationName as BuyerRegistrationName,
      @EndUserText.label: 'Buyer Legal ID'
      bp.LegalId          as BuyerLegalId,
      @EndUserText.label: 'Buyer Contact'
      bp.ContactName      as BuyerContactName,
      @EndUserText.label: 'Buyer E-Mail'
      bp.ContactMail      as BuyerContactMail
}
