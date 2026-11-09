@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'e-Invoice Candidates Without Acct Doc'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #C,
    sizeCategory: #L,
    dataClass: #TRANSACTIONAL
}

/* =====================================================================
   Billing documents flagged NO_ACC in ZTEINV_INVMAP.

   The HANA cockpit added these after the BKPF loop, from the mapping rows
   whose NO_ACC = 'X'. They carry no accounting document at all, so
   BELNR and GJAHR stay empty - which is exactly what add_final_entry
   produced when it was called with is_vbrk alone and is_bkpf initial.

   FIELD NAMES VERIFIED against the tenant on 07/10/2026 (data preview
   of I_BillingDocument in F3Y): BillingDocument, BillingDocumentType,
   BillingDocumentDate, CreationDate and CompanyCode all exist under
   these names.

   VBRK-FKSTO has no released counterpart (see ZCDS_INT_EINV_DOC_ENR), so
   a cancelled billing document cannot be recognised here. Rows reach the
   worklist and the IsCancelled rule in ZCDS_INT_EINV_LIVE is driven by
   the FI side only.
   ===================================================================== */
define view entity ZCDS_INT_EINV_REL_BILL
  as select from I_BillingDocument as bil
    inner join   zteinv_invmap     as map
      on  bil.BillingDocumentType = map.fkart
      and bil.CompanyCode         = map.bukrs
{
  key bil.CompanyCode                            as CompanyCode,
      /* No accounting document by definition. The casts give the union in
         ZCDS_INT_EINV_LIVE the same types the FI branch produces. */
  key cast( '' as abap.char( 10 ) )              as AccountingDocument,
  key cast( '0000' as abap.numc( 4 ) )           as FiscalYear,
  key bil.BillingDocument                        as BillingDocument,
  key map.projectid                              as ProjectId,
  key map.sysid                                  as SystemId,
  key map.land1                                  as Country,
  key map.doc_type                               as DocumentTypeCode,

      bil.BillingDocumentType                    as BillingDocumentType,
      cast( '' as abap.char( 2 ) )               as AccountingDocumentType,
      bil.BillingDocumentDate                    as DocumentDate,
      bil.BillingDocumentDate                    as PostingDate,
      bil.CreationDate                           as CreationDate,
      cast( '' as abap.char( 1 ) )               as IsReversed,
      cast( '' as abap.char( 1 ) )               as IsReversal,

      map.b2c                                    as IsB2C,
      map.purchase                               as IsPurchase
}
where
      map.einvoice = 'X'
  and map.no_acc   = 'X'
