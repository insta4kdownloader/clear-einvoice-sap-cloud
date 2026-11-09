@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'e-Invoice Worklist Candidates (All)'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #C,
    sizeCategory: #L,
    dataClass: #TRANSACTIONAL
}

/* =====================================================================
   /CLR/ZCL_EINV_BASE~get_data, both halves of it:

     ZCDS_INT_EINV_RELEVANT  - the BKPF driven candidates
     ZCDS_INT_EINV_REL_BILL  - the NO_ACC billing documents that
                               consolidate_data appended afterwards

   No status here. This view answers only "which documents are in scope",
   which is exactly what get_data answered before consolidate_data ran.
   ===================================================================== */
define view entity ZCDS_INT_EINV_CAND
  as select from ZCDS_INT_EINV_RELEVANT
{
  key CompanyCode,
  key AccountingDocument,
  key FiscalYear,
  key BillingDocument,
  key ProjectId,
  key SystemId,
  key Country,
  key DocumentTypeCode,
      BillingDocumentType,
      AccountingDocumentType,
      DocumentDate,
      PostingDate,
      CreationDate,
      IsReversed,
      IsReversal,
      IsB2C,
      IsPurchase
}

union all

select from ZCDS_INT_EINV_REL_BILL
{
  key CompanyCode,
  key AccountingDocument,
  key FiscalYear,
  key BillingDocument,
  key ProjectId,
  key SystemId,
  key Country,
  key DocumentTypeCode,
      BillingDocumentType,
      AccountingDocumentType,
      DocumentDate,
      PostingDate,
      CreationDate,
      IsReversed,
      IsReversal,
      IsB2C,
      IsPurchase
}
