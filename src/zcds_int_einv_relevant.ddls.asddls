/* =====================================================================
   e-Invoice worklist candidates.

   Combines ZCDS_INT_EINV_REL_JRNL (the FI/relevance driver) with the
   released billing document view, reproducing the BKPF-AWKEY/AWTYP ->
   VBRK-VBELN resolution that /CLR/ZCL_EINV_BASE did in
   consolidate_data:

       IF <lfs_bkpf>-awtyp = 'VBRK'.
         READ TABLE gt_vbrk ... WITH KEY vbeln = <lfs_bkpf>-awkey+0(10).

   The billing type is checked against the same /CLR/EINV_INVMAP row, so
   the FKART + BLART pair must match - identical to the HANA behaviour
   where consolidate_data dropped the document when no INVMAP row existed
   for the exact combination.

   Cancelled / reversed documents are NOT filtered here: the pick-up
   logic in ZCL_EINV_WORKLIST decides, so that a document reversed
   after submission still stays visible with its status - the HANA
   version deleted those rows (cancel = 'X') and lost the audit trail.

   FIELD NAMES VERIFIED against the tenant on 07/10/2026 (data preview
   of I_BillingDocument in F3Y):
       I_BillingDocument-BillingDocument         <- VBRK-VBELN   confirmed
       I_BillingDocument-BillingDocumentType     <- VBRK-FKART   confirmed
       I_BillingDocument-BillingDocumentDate     <- VBRK-FKDAT   confirmed
       I_BillingDocument-CreationDate            <- VBRK-ERDAT   confirmed
       I_BillingDocument-CompanyCode             <- VBRK-BUKRS   confirmed
   Still open: VBRK-FKSTO has no released counterpart under the name
   CancellationStatus - see ZCDS_INT_EINV_DOC_ENR.
   ===================================================================== */
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'e-Invoice Worklist Candidates'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #C,
    sizeCategory: #L,
    dataClass: #TRANSACTIONAL
}
define view entity ZCDS_INT_EINV_RELEVANT
  as select from ZCDS_INT_EINV_REL_JRNL as rel
    left outer join I_BillingDocument   as bil
      on  rel.ReferenceDocumentType = 'VBRK'
      and rel.OriginalReferenceDocument = bil.BillingDocument
      and rel.BillingDocumentType       = bil.BillingDocumentType
{
  /* The key carries the mapping columns as well as the journal key: one
     journal entry can match several /CLR/EINV_INVMAP rows (see the note in
     ZCDS_INT_EINV_REL_JRNL). The billing-type condition of the join below
     narrows that for documents that have a billing document; for pure FI
     documents it does not, so the view is genuinely one row per journal
     entry AND mapping, and says so. ZCL_EINV_WORKLIST~select_relevant is
     what reduces it to one row per document before the worklist is built. */
  key rel.CompanyCode                                     as CompanyCode,
  key rel.AccountingDocument                              as AccountingDocument,
  key rel.FiscalYear                                      as FiscalYear,
  key rel.ProjectId                                       as ProjectId,
  key rel.SystemId                                        as SystemId,
  key rel.Country                                         as Country,
  key rel.BillingDocumentType                             as BillingDocumentType,
  key rel.DocumentTypeCode                                as DocumentTypeCode,

      cast( coalesce( bil.BillingDocument, '' ) as abap.char( 10 ) ) as BillingDocument,

      rel.AccountingDocumentType                          as AccountingDocumentType,
      rel.DocumentDate                                    as DocumentDate,
      rel.PostingDate                                     as PostingDate,
      rel.CreationDate                                    as CreationDate,
      rel.IsReversed                                      as IsReversed,
      rel.IsReversal                                      as IsReversal,

      rel.IsB2C                                           as IsB2C,
      rel.IsPurchase                                      as IsPurchase
}
