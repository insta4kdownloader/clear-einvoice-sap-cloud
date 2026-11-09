@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Sales e-Invoice Document'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #L,
    dataClass: #TRANSACTIONAL
}
define root view entity ZCDS_INT_EINV_DOC as select from zteinv_doc
  composition [0..*] of ZCDS_INT_EINV_DOC_ERR  as _Error
  /* The extract archive kept for the DATA_ZIP diagnostic. A composition
     because its key IS the document key and it has no life of its own -
     same reasoning as _Exchange. [0..1]: one archive per document, the
     latest submission replacing the previous. */
  composition [0..1] of ZCDS_INT_EINV_ZIP      as _Archive
  composition [0..1] of ZCDS_INT_EINV_DOC_STAT as _Exchange
  /* The government reporting history. [0..*], unlike _Exchange: the
     Status API returns an array of reporting entries and each may carry
     several status reasons, and save_ppf_details keeps all of them.
     Section 81. */
  composition [0..*] of ZCDS_INT_EINV_PPF      as _Ppf

  /* Everything derived - the effective status and the enrichment from the
     released document views - lives in ZCDS_INT_EINV_DOC_ENR and is reached
     through this association. It must not be calculated here: a managed
     business object maps every element of its root view onto a column of
     ZTEINV_DOC, and a calculated element has none, so the behaviour
     definition would not activate. */
  association [1..1] to ZCDS_INT_EINV_DOC_ENR  as _Enrich on  $projection.BillingDocument    = _Enrich.BillingDocument
                                                          and $projection.AccountingDocument = _Enrich.AccountingDocument
                                                          and $projection.CompanyCode        = _Enrich.CompanyCode
                                                          and $projection.FiscalYear         = _Enrich.FiscalYear
{
  key vbeln                 as BillingDocument,
  key belnr                 as AccountingDocument,
  key bukrs                 as CompanyCode,
  key gjahr                 as FiscalYear,

      invno                 as EInvoiceNumber,
      invdt                 as EInvoiceDate,
      doc_type              as DocumentTypeCode,
      invid                 as ClearDocumentId,
      invtype               as EInvoiceInvoiceType,
      status                as SyncStatus,
      error                 as ErrorText,
      b2c                   as IsB2C,
      b2g                   as IsB2G,
      sent                  as IsSent,
      b2c_status            as B2CStatus,

      /* The government (PPF) answer, from the Status API's
         GovtReportingDetails block. GOVT_STATUS is the status of the
         latest reported entry; the PPF pair keeps the same value and the
         action it belonged to, as /CLR/ZT_EINV does. Section 81. */
      govt_status           as GovernmentStatus,
      govt_ppf_status       as PpfStatus,
      govt_ppf_action       as PpfAction,
      einv_identifier       as EInvoiceIdentifier,
      einv_type             as EInvoiceType,
      command_id            as CommandId,

      /* 2026-09-25 HANA drop. /CLR/ZT_EINV and /CLR/ZT_SALES_ST both gained
         these three. Note: nothing in the HANA export WRITES them -- the
         producer is the Clear platform's ingestion write-back, which reaches
         this table through ZCL_ELT~insert_table. They are read-only here. */
      zsigned_qrcode        as SignedQrCode,
      zsigned_inv           as SignedInvoice,
      uuid                  as PlatformUuid,

      crdat                 as CreatedOn,
      crtime                as CreatedAt,
      cruser                as CreatedBy,

      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,

      _Error,
      _Exchange,
      _Ppf,
      _Archive,
      _Enrich
}
