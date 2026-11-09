@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Multi-Stage Exchange Status'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #M,
    dataClass: #TRANSACTIONAL
}
define view entity ZCDS_INT_EINV_DOC_STAT as select from zteinv_sales_st
  association to parent ZCDS_INT_EINV_DOC as _Document
    on  $projection.BillingDocument    = _Document.BillingDocument
    and $projection.AccountingDocument = _Document.AccountingDocument
    and $projection.CompanyCode        = _Document.CompanyCode
    and $projection.FiscalYear         = _Document.FiscalYear
{
  key vbeln              as BillingDocument,
  key belnr              as AccountingDocument,
  key bukrs              as CompanyCode,
  key gjahr              as FiscalYear,

      invid              as ClearDocumentId,
      invoice_num        as EInvoiceNumber,
      invoice_type       as EInvoiceInvoiceType,
      doc_type           as DocumentTypeCode,

      /* Added by the 2026-09-25 drop. fill_sales_status in the HANA base
         class does NOT copy these, so on that path they are currently dead
         columns -- exposed here so the write-back can populate them. */
      zsigned_qrcode     as SignedQrCode,
      zsigned_inv        as SignedInvoice,
      uuid               as PlatformUuid,

      /* Stage 1 - peer-to-peer exchange */
      pa_exchg_stat      as PaExchangeStatus,
      pa_exchg_rescode   as PaExchangeResponseCode,
      pa_exchg_resmsg    as PaExchangeResponseMessage,

      /* Stage 2 - PPF invoice submission */
      ppf_invsub_stat    as PpfInvSubStatus,
      ppf_invsub_rescode as PpfInvSubResponseCode,
      ppf_invsub_resmsg  as PpfInvSubResponseMessage,

      /* Stage 3 - PPF lifecycle submission */
      ppf_lcsub_stat     as PpfLcSubStatus,
      ppf_lcsub_rescode  as PpfLcSubResponseCode,
      ppf_lcsub_resmsg   as PpfLcSubResponseMessage,

      /* Stage 4 - PPF lifecycle rejection */
      ppf_lcrej_stat     as PpfLcRejStatus,
      ppf_lcrej_rescode  as PpfLcRejResponseCode,
      ppf_lcrej_resmsg   as PpfLcRejResponseMessage,

      /* Stage 5 - PPF lifecycle refusal */
      ppf_lcref_stat     as PpfLcRefStatus,
      ppf_lcref_rescode  as PpfLcRefResponseCode,
      ppf_lcref_resmsg   as PpfLcRefResponseMessage,

      /* Stage 6 - PPF payment collection */
      ppf_lcpmnt_stat    as PpfPaymentStatus,
      ppf_lcpmnt_rescode as PpfPaymentResponseCode,
      ppf_lcpmnt_resmsg  as PpfPaymentResponseMessage,

      einv_identifier    as EInvoiceIdentifier,
      einv_type          as EInvoiceType,

      _Document
}
