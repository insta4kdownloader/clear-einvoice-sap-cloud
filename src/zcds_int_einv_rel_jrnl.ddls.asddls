/* =====================================================================
   e-Invoice relevance - FI side.

   Replaces  /CLR/ZCL_EINV_BASE~get_accounting_docs, which read BKPF
   directly and INNER JOINed /CLR/EINV_INVMAP on BLART + BUKRS:

       SELECT DISTINCT a~bukrs, a~belnr, ... a~awkey, a~awtyp, ...
         FROM bkpf AS a
         INNER JOIN /clr/einv_invmap AS c
           ON  a~blart = c~blart
           AND a~bukrs = c~bukrs
           AND c~einvoice = @abap_true

   BKPF is not released for ABAP Cloud, so the source is the released
   view I_JournalEntry.

   >>> FIELD NAMES TO VERIFY IN ADT AGAINST YOUR RELEASE <<<
   The following I_JournalEntry elements carry the BKPF semantics this
   logic depends on. Confirm them once in ADT (F2 on the view) and
   adjust here if your release names them differently:
       AccountingDocumentType     <- BKPF-BLART
       ReferenceDocumentType      <- BKPF-AWTYP   ('VBRK' for billing)
       OriginalReferenceDocument  <- BKPF-AWKEY
   BKPF-USNAM has no counterpart here: the 2026-10-01 activation rejected
   CreatedByUser on I_JournalEntry, and nothing consumes it - get_data took
   ir_user as a selection parameter that the pick-up action does not offer.
   If you want it, confirm the element name in ADT first.
       IsReversed / IsReversal    <- BKPF-XREVERSED / XREVERSAL
       AccountingDocumentCreationDate <- BKPF-CPUDT
   ===================================================================== */
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'e-Invoice Relevant Journal Entries'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #C,
    sizeCategory: #L,
    dataClass: #TRANSACTIONAL
}
define view entity ZCDS_INT_EINV_REL_JRNL
  as select from I_JournalEntry as je
    inner join   zteinv_invmap  as map
      on  je.AccountingDocumentType = map.blart
      and je.CompanyCode            = map.bukrs
{
  /* The join is on BLART + BUKRS only, as in the HANA SELECT, while
     ZTEINV_INVMAP is keyed on seven fields (the on-premise /CLR/EINV_INVMAP
     had eight - SUP_TYPE was dropped in the conversion, nothing read it).
     One journal entry therefore
     matches every mapping row configured for that company code and document
     type, so the journal key alone is NOT unique here - the mapping columns
     are part of the key and the consumer resolves the fan-out
     (ZCDS_INT_EINV_RELEVANT narrows it by billing type,
     ZCL_EINV_WORKLIST~select_relevant removes what is left). Declaring the
     key honestly is what keeps the ORDER BY and the DISTINCT correct. */
  key je.CompanyCode                    as CompanyCode,
  key je.AccountingDocument             as AccountingDocument,
  key je.FiscalYear                     as FiscalYear,
  key map.projectid                     as ProjectId,
  key map.sysid                         as SystemId,
  key map.land1                         as Country,
  key map.fkart                         as BillingDocumentType,
  key map.doc_type                      as DocumentTypeCode,

      je.AccountingDocumentType         as AccountingDocumentType,
      je.DocumentDate                   as DocumentDate,
      je.PostingDate                    as PostingDate,
      je.AccountingDocumentCreationDate as CreationDate,
      je.ReferenceDocumentType          as ReferenceDocumentType,
      je.OriginalReferenceDocument      as OriginalReferenceDocument,
      je.IsReversed                     as IsReversed,
      je.IsReversal                     as IsReversal,

      map.b2c                           as IsB2C,
      map.purchase                      as IsPurchase
}
where
  map.einvoice = 'X'
