@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'e-Invoice Exchange Status'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
/* No `provider contract transactional_query` here: the contract is
   declared once on the root projection and inherited. Declaring it on a
   view that also carries `redirected to parent` is rejected. */
define view entity ZCDS_CUN_EINV_DOC_STAT
  as projection on ZCDS_INT_EINV_DOC_STAT
{
  key BillingDocument,
  key AccountingDocument,
  key CompanyCode,
  key FiscalYear,

      ClearDocumentId,
      EInvoiceNumber,
      EInvoiceInvoiceType,
      DocumentTypeCode,

      @EndUserText.label: 'Signed Invoice QR Code'
      SignedQrCode,
      @EndUserText.label: 'Signed Invoice'
      SignedInvoice,
      @EndUserText.label: 'Platform UUID'
      PlatformUuid,

      @EndUserText.label: 'Exchange Status'
      PaExchangeStatus,
      @EndUserText.label: 'Exchange Response Code'
      PaExchangeResponseCode,
      @EndUserText.label: 'Exchange Message'
      PaExchangeResponseMessage,

      @EndUserText.label: 'Invoice Submission Status'
      PpfInvSubStatus,
      PpfInvSubResponseCode,
      PpfInvSubResponseMessage,

      @EndUserText.label: 'Lifecycle Submission Status'
      PpfLcSubStatus,
      PpfLcSubResponseCode,
      PpfLcSubResponseMessage,

      @EndUserText.label: 'Lifecycle Rejection Status'
      PpfLcRejStatus,
      PpfLcRejResponseCode,
      PpfLcRejResponseMessage,

      @EndUserText.label: 'Lifecycle Refusal Status'
      PpfLcRefStatus,
      PpfLcRefResponseCode,
      PpfLcRefResponseMessage,

      @EndUserText.label: 'Payment Collection Status'
      PpfPaymentStatus,
      PpfPaymentResponseCode,
      PpfPaymentResponseMessage,

      EInvoiceIdentifier,
      EInvoiceType,

      _Document: redirected to parent ZCDS_CUN_EINV_DOC
}
