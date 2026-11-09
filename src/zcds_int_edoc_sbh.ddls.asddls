@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interface View for Self-Billed e-Invoice'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #L,
    dataClass: #TRANSACTIONAL
}
define root view entity ZCDS_INT_EDOC_SBH as select from ztedoc_sbh
  composition [0..*] of ZCDS_INT_EDOC_SBI as _Line
  composition [0..*] of ZCDS_INT_EDOC_SBP as _Party
  composition [0..*] of ZCDS_INT_EDOC_SBT as _TaxSubtotal
  composition [0..*] of ZCDS_INT_EDOC_SBA as _Allowance
  composition [0..*] of ZCDS_INT_EDOC_SBN as _Note
  composition [0..*] of ZCDS_INT_EDOC_SBR as _Reference
  composition [0..*] of ZCDS_INT_EDOC_SBX as _ItemAttr
  association [0..1] to ZCDS_INT_EDOC_SBP as _SellerParty on  $projection.Uuid = _SellerParty.Uuid
                                                     and _SellerParty.LineId    = ' '
                                                     and _SellerParty.PartyRole = 'SELLER'
  association [0..1] to ZCDS_INT_EDOC_SBP as _BuyerParty on  $projection.Uuid = _BuyerParty.Uuid
                                                     and _BuyerParty.LineId    = ' '
                                                     and _BuyerParty.PartyRole = 'BUYER'
  association [1..1] to ZCDS_INT_EDOC_SBENR as _Enrich
                                   on $projection.Uuid = _Enrich.Uuid
{
      @EndUserText.label: 'E-Invoice unique document ID'
      /* /StandardBusinessDocument/StandardBusinessDocumentHeader/DocumentIdentification/InstanceIdentifier */
  key uuid as Uuid,
      @EndUserText.label: 'Invoice number (BT-1)'
      /* /Invoice/cbc:ID */
      documentnumber as DocumentNumber,
      @EndUserText.label: 'Clear document ID'
      documentid as DocumentId,
      @EndUserText.label: 'Processing status'
      status as Status,
      @EndUserText.label: 'Action type'
      action_type as ActionType,
      @EndUserText.label: 'Action reason code'
      reason_code as ReasonCode,
      @EndUserText.label: 'PO / GR match status'
      match_status as MatchStatus,
      @EndUserText.label: 'Comment'
      comment_txt as CommentText,
      @EndUserText.label: 'API message'
      api_message as ApiMessage,
      @EndUserText.label: 'UBL version ID'
      /* /Invoice/cbc:UBLVersionID */
      ubl_version as UblVersionId,
      @EndUserText.label: 'Specification identifier (BT-24)'
      /* /Invoice/cbc:CustomizationID */
      customization_id as CustomizationId,
      @EndUserText.label: 'Business process type (BT-23)'
      /* /Invoice/cbc:ProfileID */
      profile_id as ProfileId,
      @EndUserText.label: 'SBDH document type identifier'
      /* SBDH/BusinessScope/Scope[Type=DOCUMENTID]/InstanceIdentifier */
      sbdh_doc_type_id as SbdhDocumentTypeId,
      @EndUserText.label: 'SBDH process identifier'
      /* SBDH/BusinessScope/Scope[Type=PROCESSID]/InstanceIdentifier */
      sbdh_process_id as SbdhProcessId,
      @EndUserText.label: 'Country C1 (SBDH)'
      /* SBDH/BusinessScope/Scope[Type=COUNTRY_C1]/InstanceIdentifier */
      sbdh_country as SbdhCountry,
      @EndUserText.label: 'SBDH sender identifier'
      /* SBDH/Sender/Identifier */
      sbdh_sender_id as SbdhSenderId,
      @EndUserText.label: 'SBDH receiver identifier'
      /* SBDH/Receiver/Identifier */
      sbdh_receiver_id as SbdhReceiverId,
      @EndUserText.label: 'SBDH creation timestamp (UTC)'
      /* SBDH/DocumentIdentification/CreationDateAndTime */
      sbdh_created_ts as SbdhCreatedTimestamp,
      @EndUserText.label: 'Invoice issue date (BT-2)'
      /* /Invoice/cbc:IssueDate */
      issue_date as IssueDate,
      @EndUserText.label: 'Invoice issue time'
      /* /Invoice/cbc:IssueTime */
      issue_time as IssueTime,
      @EndUserText.label: 'Payment due date (BT-9)'
      /* /Invoice/cbc:DueDate */
      due_date as DueDate,
      @EndUserText.label: 'Invoice type code (BT-3)'
      /* /Invoice/cbc:InvoiceTypeCode */
      inv_type_code as InvoiceTypeCode,
      @EndUserText.label: 'Invoice type name'
      /* /Invoice/cbc:InvoiceTypeCode/@name */
      inv_type_name as InvoiceTypeName,
      @EndUserText.label: 'VAT point date (BT-7)'
      /* /Invoice/cbc:TaxPointDate */
      tax_point_date as TaxPointDate,
      @EndUserText.label: 'Invoice currency (BT-5)'
      /* /Invoice/cbc:DocumentCurrencyCode */
      currency as Currency,
      @EndUserText.label: 'VAT accounting currency (BT-6)'
      /* /Invoice/cbc:TaxCurrencyCode */
      tax_currency as TaxCurrency,
      @EndUserText.label: 'Buyer accounting reference (BT-19)'
      /* /Invoice/cbc:AccountingCost */
      acc_cost as AccountingCost,
      @EndUserText.label: 'Buyer reference (BT-10)'
      /* /Invoice/cbc:BuyerReference */
      buyer_ref as BuyerReference,
      @EndUserText.label: 'Invoicing period start date'
      /* /Invoice/cac:InvoicePeriod/cbc:StartDate */
      period_start as PeriodStart,
      @EndUserText.label: 'Invoicing period end date'
      /* /Invoice/cac:InvoicePeriod/cbc:EndDate */
      period_end as PeriodEnd,
      @EndUserText.label: 'Invoicing period description code'
      /* /Invoice/cac:InvoicePeriod/cbc:DescriptionCode */
      period_desc_code as PeriodDescriptionCode,
      @EndUserText.label: 'Exchange rate source currency'
      /* /Invoice/cac:TaxExchangeRate/cbc:SourceCurrencyCode */
      tax_exc_src_curr as TaxExchangeSourceCurrency,
      @EndUserText.label: 'Exchange rate target currency'
      /* /Invoice/cac:TaxExchangeRate/cbc:TargetCurrencyCode */
      tax_exc_tgt_curr as TaxExchangeTargetCurrency,
      @EndUserText.label: 'Tax exchange rate'
      /* /Invoice/cac:TaxExchangeRate/cbc:CalculationRate */
      tax_exc_rate as TaxExchangeRate,
      @EndUserText.label: 'Tax exchange rate date'
      /* /Invoice/cac:TaxExchangeRate/cbc:Date */
      tax_exc_date as TaxExchangeDate,
      @EndUserText.label: 'Sum of invoice line net amounts (BT-106)'
      /* /Invoice/cac:LegalMonetaryTotal/cbc:LineExtensionAmount */
      @Semantics.amount.currencyCode: 'Currency'
      line_ext_amt as LineExtensionAmount,
      @EndUserText.label: 'Sum of document allowances (BT-107)'
      /* /Invoice/cac:LegalMonetaryTotal/cbc:AllowanceTotalAmount */
      @Semantics.amount.currencyCode: 'Currency'
      allowance_total as AllowanceTotal,
      @EndUserText.label: 'Sum of document charges (BT-108)'
      /* /Invoice/cac:LegalMonetaryTotal/cbc:ChargeTotalAmount */
      @Semantics.amount.currencyCode: 'Currency'
      charge_total as ChargeTotal,
      @EndUserText.label: 'Invoice total without VAT (BT-109)'
      /* /Invoice/cac:LegalMonetaryTotal/cbc:TaxExclusiveAmount */
      @Semantics.amount.currencyCode: 'Currency'
      tax_excl_amt as TaxExclusiveAmount,
      @EndUserText.label: 'Invoice total VAT amount (BT-110)'
      /* /Invoice/cac:TaxTotal[TaxAmount/@currencyID=DocumentCurrencyCode]/cbc:TaxAmount */
      @Semantics.amount.currencyCode: 'Currency'
      vat_total as VatTotal,
      @EndUserText.label: 'Invoice total with VAT (BT-112)'
      /* /Invoice/cac:LegalMonetaryTotal/cbc:TaxInclusiveAmount */
      @Semantics.amount.currencyCode: 'Currency'
      tax_incl_amt as TaxInclusiveAmount,
      @EndUserText.label: 'Paid amount (BT-113)'
      /* /Invoice/cac:LegalMonetaryTotal/cbc:PrepaidAmount */
      @Semantics.amount.currencyCode: 'Currency'
      prepaid_amt as PrepaidAmount,
      @EndUserText.label: 'Rounding amount (BT-114)'
      /* /Invoice/cac:LegalMonetaryTotal/cbc:PayableRoundingAmount */
      @Semantics.amount.currencyCode: 'Currency'
      payable_rnd_amt as PayableRoundingAmount,
      @EndUserText.label: 'Amount due for payment (BT-115)'
      /* /Invoice/cac:LegalMonetaryTotal/cbc:PayableAmount */
      @Semantics.amount.currencyCode: 'Currency'
      payable_amt as PayableAmount,
      @EndUserText.label: 'Invoice total VAT in accounting (BT-111)'
      /* /Invoice/cac:TaxTotal[TaxAmount/@currencyID=TaxCurrencyCode]/cbc:TaxAmount */
      @Semantics.amount.currencyCode: 'TaxCurrency'
      vat_total_taxcur as VatTotalTaxCurrency,
      @EndUserText.label: 'Actual delivery date (BT-72)'
      /* /Invoice/cac:Delivery/cbc:ActualDeliveryDate */
      actual_del_date as ActualDeliveryDate,
      @EndUserText.label: 'Deliver-to location identifier (BT-71)'
      /* /Invoice/cac:Delivery/cac:DeliveryLocation/cbc:ID */
      del_loc_id as DeliveryLocationId,
      @EndUserText.label: 'Deliver-to location identifier scheme'
      /* /Invoice/cac:Delivery/cac:DeliveryLocation/cbc:ID/@schemeID */
      del_loc_id_sch as DeliveryLocationIdScheme,
      @EndUserText.label: 'Delivery terms (Incoterms)'
      /* /Invoice/cac:DeliveryTerms/cbc:ID */
      del_terms_id as DeliveryTermsId,
      @EndUserText.label: 'Payment means type code (BT-81)'
      /* /Invoice/cac:PaymentMeans/cbc:PaymentMeansCode */
      pay_means_code as PaymentMeansCode,
      @EndUserText.label: 'Payment means text (BT-82)'
      /* /Invoice/cac:PaymentMeans/cbc:PaymentMeansCode/@name */
      pay_means_name as PaymentMeansName,
      @EndUserText.label: 'Payment means ID'
      /* /Invoice/cac:PaymentMeans/cbc:ID */
      pay_means_id as PaymentMeansId,
      @EndUserText.label: 'Payment instruction note'
      /* /Invoice/cac:PaymentMeans/cbc:InstructionNote */
      pay_instr_note as PaymentInstructionNote,
      @EndUserText.label: 'Remittance information (BT-83)'
      /* /Invoice/cac:PaymentMeans/cbc:PaymentID */
      pay_id as PaymentId,
      @EndUserText.label: 'Payment account identifier / IBA (BT-84)'
      /* /Invoice/cac:PaymentMeans/cac:PayeeFinancialAccount/cbc:ID */
      payee_acc_id as PayeeAccountId,
      @EndUserText.label: 'Payment account identifier scheme'
      /* /Invoice/cac:PaymentMeans/cac:PayeeFinancialAccount/cbc:ID/@schemeID */
      payee_acc_sch as PayeeAccountScheme,
      @EndUserText.label: 'Payment account name (BT-85)'
      /* /Invoice/cac:PaymentMeans/cac:PayeeFinancialAccount/cbc:Name */
      payee_acc_name as PayeeAccountName,
      @EndUserText.label: 'Payment service provider ID / BI (BT-86)'
      /* /Invoice/cac:PaymentMeans/cac:PayeeFinancialAccount/cac:FinancialInstitutionBranch/cbc:ID */
      payee_branch_id as PayeeBranchId,
      @EndUserText.label: 'Payment card primary account num (BT-87)'
      /* /Invoice/cac:PaymentMeans/cac:CardAccount/cbc:PrimaryAccountNumberID */
      card_acc_id as CardAccountId,
      @EndUserText.label: 'Payment card network ID'
      /* /Invoice/cac:PaymentMeans/cac:CardAccount/cbc:NetworkID */
      card_network as CardNetwork,
      @EndUserText.label: 'Payment card holder name (BT-88)'
      /* /Invoice/cac:PaymentMeans/cac:CardAccount/cbc:HolderName */
      card_holder as CardHolder,
      @EndUserText.label: 'Direct debit mandate reference (BT-89)'
      /* /Invoice/cac:PaymentMeans/cac:PaymentMandate/cbc:ID */
      mandate_id as MandateId,
      @EndUserText.label: 'Debited account identifier (BT-91)'
      /* /Invoice/cac:PaymentMeans/cac:PaymentMandate/cac:PayerFinancialAccount/cbc:ID */
      payer_acc_id as PayerAccountId,
      @EndUserText.label: 'Payment terms ID'
      /* /Invoice/cac:PaymentTerms/cbc:ID */
      pay_terms_id as PaymentTermsId,
      @EndUserText.label: 'Payment terms (BT-20)'
      /* /Invoice/cac:PaymentTerms/cbc:Note */
      pay_terms_note as PaymentTermsNote,
      @EndUserText.label: 'Payment terms amount'
      /* /Invoice/cac:PaymentTerms/cbc:Amount */
      @Semantics.amount.currencyCode: 'PaymentTermsCurrency'
      pay_terms_amt as PaymentTermsAmount,
      @EndUserText.label: 'Payment terms amount currency'
      /* /Invoice/cac:PaymentTerms/cbc:Amount/@currencyID */
      pay_terms_curr as PaymentTermsCurrency,
      @EndUserText.label: 'Payment terms installment due date'
      /* /Invoice/cac:PaymentTerms/cbc:InstallmentDueDate */
      pay_terms_due as PaymentTermsDueDate,
      @EndUserText.label: 'Prepaid payment ID'
      /* /Invoice/cac:PrepaidPayment/cbc:ID */
      prepaid_id as PrepaidId,
      @EndUserText.label: 'Prepaid payment amount'
      /* /Invoice/cac:PrepaidPayment/cbc:PaidAmount */
      @Semantics.amount.currencyCode: 'PrepaidCurrency'
      prepaid_paid_amt as PrepaidPaidAmount,
      @EndUserText.label: 'Prepaid payment currency'
      /* /Invoice/cac:PrepaidPayment/cbc:PaidAmount/@currencyID */
      prepaid_curr as PrepaidCurrency,
      @EndUserText.label: 'Prepaid payment received date'
      /* /Invoice/cac:PrepaidPayment/cbc:ReceivedDate */
      prepaid_rcvd_date as PrepaidReceivedDate,
      @EndUserText.label: 'Prepaid payment instruction ID'
      /* /Invoice/cac:PrepaidPayment/cbc:InstructionID */
      prepaid_instr_id as PrepaidInstructionId,
      @EndUserText.label: 'Number of invoice lines'
      /* count(/Invoice/cac:InvoiceLine) */
      line_count as LineCount,
      @EndUserText.label: 'Raw JSON payload'
      json_payload as JsonPayload,
      @EndUserText.label: 'Created on'
      created_on as CreatedOn,
      @EndUserText.label: 'Created at'
      created_at as CreatedAt,
      @EndUserText.label: 'Created by'
      created_by as CreatedBy,
      @EndUserText.label: 'Changed on'
      changed_on as ChangedOn,
      @EndUserText.label: 'Changed at'
      changed_at as ChangedAt,
      @EndUserText.label: 'Changed by'
      changed_by as ChangedBy,

      _Line,
      _Party,
      _TaxSubtotal,
      _Allowance,
      _Note,
      _Reference,
      _ItemAttr,
      _SellerParty,
      _BuyerParty,
      _Enrich
}
