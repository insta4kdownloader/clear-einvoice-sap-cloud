@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Inbound e-Invoice (AP)'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #L,
    dataClass: #TRANSACTIONAL
}
@Metadata.allowExtensions: true
@Search.searchable: true
define root view entity ZCDS_CUN_EDOC_APH
  provider contract transactional_query
  as projection on ZCDS_INT_EDOC_APH
{
      @Search.defaultSearchElement: true
  key Uuid,
      @EndUserText.label: 'Invoice Number'
      @UI.selectionField: [ { position: 10 } ]
      @Search.defaultSearchElement: true
  key DocumentNumber,
      @Search.defaultSearchElement: true
      DocumentId,
      @EndUserText.label: 'Status'
      @UI.selectionField: [ { position: 20 } ]
      Status,
      @Consumption.valueHelpDefinition: [ { entity: { name: 'ZVH_EINV_ACTTYPE_AP', element: 'ActionType' } } ]
      ActionType,
      @Consumption.valueHelpDefinition: [ { entity: { name: 'ZVH_EINV_REASONCODE', element: 'ReasonCode' }, additionalBinding: [ { localElement: 'ActionType', element: 'ActionType', usage: #FILTER_AND_RESULT } ] } ]
      ReasonCode,
      @EndUserText.label: 'Match Status'
      @UI.selectionField: [ { position: 30 } ]
      MatchStatus,
      CommentText,
      ApiMessage,
      UblVersionId,
      CustomizationId,
      ProfileId,
      SbdhDocumentTypeId,
      SbdhProcessId,
      SbdhCountry,
      SbdhSenderId,
      SbdhReceiverId,
      SbdhCreatedTimestamp,
      @EndUserText.label: 'Issue Date'
      @UI.selectionField: [ { position: 40 } ]
      IssueDate,
      IssueTime,
      DueDate,
      @EndUserText.label: 'Invoice Type'
      @UI.selectionField: [ { position: 50 } ]
      InvoiceTypeCode,
      InvoiceTypeName,
      TaxPointDate,
      Currency,
      TaxCurrency,
      AccountingCost,
      BuyerReference,
      PeriodStart,
      PeriodEnd,
      PeriodDescriptionCode,
      TaxExchangeSourceCurrency,
      TaxExchangeTargetCurrency,
      TaxExchangeRate,
      TaxExchangeDate,
      @Semantics.amount.currencyCode: 'Currency'
      LineExtensionAmount,
      @Semantics.amount.currencyCode: 'Currency'
      AllowanceTotal,
      @Semantics.amount.currencyCode: 'Currency'
      ChargeTotal,
      @Semantics.amount.currencyCode: 'Currency'
      TaxExclusiveAmount,
      @Semantics.amount.currencyCode: 'Currency'
      VatTotal,
      @Semantics.amount.currencyCode: 'Currency'
      TaxInclusiveAmount,
      @Semantics.amount.currencyCode: 'Currency'
      PrepaidAmount,
      @Semantics.amount.currencyCode: 'Currency'
      PayableRoundingAmount,
      @Semantics.amount.currencyCode: 'Currency'
      PayableAmount,
      @Semantics.amount.currencyCode: 'TaxCurrency'
      VatTotalTaxCurrency,
      ActualDeliveryDate,
      DeliveryLocationId,
      DeliveryLocationIdScheme,
      DeliveryTermsId,
      PaymentMeansCode,
      PaymentMeansName,
      PaymentMeansId,
      PaymentInstructionNote,
      PaymentId,
      PayeeAccountId,
      PayeeAccountScheme,
      PayeeAccountName,
      PayeeBranchId,
      CardAccountId,
      CardNetwork,
      CardHolder,
      MandateId,
      PayerAccountId,
      PaymentTermsId,
      PaymentTermsNote,
      @Semantics.amount.currencyCode: 'PaymentTermsCurrency'
      PaymentTermsAmount,
      PaymentTermsCurrency,
      PaymentTermsDueDate,
      PrepaidId,
      @Semantics.amount.currencyCode: 'PrepaidCurrency'
      PrepaidPaidAmount,
      PrepaidCurrency,
      PrepaidReceivedDate,
      PrepaidInstructionId,
      LineCount,
      JsonPayload,
      CreatedOn,
      CreatedAt,
      CreatedBy,
      ChangedOn,
      ChangedAt,
      ChangedBy,

      @EndUserText.label: 'Seller'
      @UI.selectionField: [ { position: 60 } ]
      _SellerParty.PartyName as SellerName,
      @EndUserText.label: 'Seller VAT ID'
      _SellerParty.VatId     as SellerVatId,
      @EndUserText.label: 'Seller Country'
      _SellerParty.Country   as SellerCountry,
      @EndUserText.label: 'Buyer'
      @UI.selectionField: [ { position: 70 } ]
      _BuyerParty.PartyName  as BuyerName,
      @EndUserText.label: 'Buyer VAT ID'
      _BuyerParty.VatId      as BuyerVatId,

      @EndUserText.label: 'Criticality'
      _Enrich.StatusCriticality as StatusCriticality,

      _Line : redirected to composition child ZCDS_CUN_EDOC_API,
      _Party : redirected to composition child ZCDS_CUN_EDOC_APP,
      _TaxSubtotal : redirected to composition child ZCDS_CUN_EDOC_APT,
      _Allowance : redirected to composition child ZCDS_CUN_EDOC_APA,
      _Note : redirected to composition child ZCDS_CUN_EDOC_APN,
      _Reference : redirected to composition child ZCDS_CUN_EDOC_APR,
      _ItemAttr : redirected to composition child ZCDS_CUN_EDOC_APX
}
