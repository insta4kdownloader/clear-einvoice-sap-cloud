@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Sales e-Invoice Live Worklist'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #C,
    sizeCategory: #L,
    dataClass: #TRANSACTIONAL
}

/* =====================================================================
   The cockpit's spine, anchored the way /CLR/ELT_EINVOICE_COCKPIT
   anchored it: candidates first, status second.

       get_data           -> ZCDS_INT_EINV_CAND
       fill_einv_status   -> _Doc      (zteinv_doc)
       fill_async_status  -> _Async    (ZCDS_INT_EINV_DOC_ASY)
       fill_sales_status  -> _Exchange (ZCDS_INT_EINV_DOC_STAT)

   Every association is [0..1] and LEFT, so a document that has never been
   picked up still appears - with EffectiveStatus empty. That blank is the
   worklist's "to be processed" state and is the whole point of the view.

   The status precedence (exchange, then async, then sync) is the same
   COALESCE chain ZCDS_INT_EINV_DOC_ENR uses; it is repeated here rather
   than reused because that view is anchored on zteinv_doc and therefore
   cannot see an unprocessed document.

   KEY WIDTH. ZTEINV_INVMAP is keyed on seven fields and the candidate
   views join it on BUKRS + BLART (FI) or BUKRS + FKART (billing), so one
   document matches every mapping row configured for that combination. The
   key below carries the mapping columns for that reason - the same
   fan-out /CLR/ZCL_EINV_BASE had, which it collapsed in ABAP with
   SELECT DISTINCT. With one mapping row per document type, as configured
   today, no fan-out occurs.
   ===================================================================== */
define view entity ZCDS_INT_EINV_LIVE
  as select from ZCDS_INT_EINV_CAND as cand

  association [0..1] to zteinv_doc             as _Doc      on  $projection.BillingDocument    = _Doc.vbeln
                                                             and $projection.AccountingDocument = _Doc.belnr
                                                             and $projection.CompanyCode        = _Doc.bukrs
                                                             and $projection.FiscalYear         = _Doc.gjahr
  association [0..1] to ZCDS_INT_EINV_DOC_ASY  as _Async    on  $projection.BillingDocument    = _Async.BillingDocument
                                                             and $projection.AccountingDocument = _Async.AccountingDocument
                                                             and $projection.CompanyCode        = _Async.CompanyCode
                                                             and $projection.FiscalYear         = _Async.FiscalYear
  association [0..1] to ZCDS_INT_EINV_DOC_STAT as _Exchange on  $projection.BillingDocument    = _Exchange.BillingDocument
                                                             and $projection.AccountingDocument = _Exchange.AccountingDocument
                                                             and $projection.CompanyCode        = _Exchange.CompanyCode
                                                             and $projection.FiscalYear         = _Exchange.FiscalYear
{
  key cand.CompanyCode                    as CompanyCode,
  key cand.AccountingDocument             as AccountingDocument,
  key cand.FiscalYear                     as FiscalYear,
  key cand.BillingDocument                as BillingDocument,
  key cand.ProjectId                      as ProjectId,
  key cand.SystemId                       as SystemId,
  key cand.Country                        as Country,
  key cand.DocumentTypeCode               as DocumentTypeCode,

      cand.BillingDocumentType            as BillingDocumentType,
      cand.AccountingDocumentType         as AccountingDocumentType,
      cand.DocumentDate                   as DocumentDate,
      cand.PostingDate                    as PostingDate,
      cand.CreationDate                   as CreationDate,
      cand.IsReversed                     as IsReversed,
      cand.IsReversal                     as IsReversal,
      cand.IsB2C                          as IsB2C,
      cand.IsPurchase                     as IsPurchase,

      /* ---- fill_einv_status / fill_async_status / fill_sales_status --- */
      _Doc.invno                          as EInvoiceNumber,
      _Doc.invid                          as EInvoiceDocumentId,
      _Doc.command_id                     as CommandId,
      _Doc.uuid                           as Uuid,
      _Doc.zsigned_qrcode                 as SignedQrCode,
      _Doc.zsigned_inv                    as SignedInvoice,
      _Doc.crdat                          as EInvoiceCreatedOn,
      _Doc.cruser                         as EInvoiceCreatedBy,
      _Doc.sent                           as IsSent,

      coalesce( _Exchange.PaExchangeStatus,
                coalesce( _Async.SyncStatus, _Doc.status ) )
                                          as EffectiveStatus,

      coalesce( _Exchange.PaExchangeResponseMessage,
                coalesce( _Async.ErrorText, _Doc.error ) )
                                          as EffectiveMessage,

      /* ---- the government stage, on its own --------------------------
         Stage 1 of ZTEINV_SALES_ST, written by the IRN write-back of the
         DATA_POSTING job. These three already reach the worklist, but only
         folded into EffectiveStatus/EffectiveMessage by the COALESCE
         above, where they are indistinguishable from the sync status of
         ZTEINV_DOC - a document can show COMPLETED because the submission
         succeeded while the tax authority has said nothing yet.

         Exposed separately so the dashboard can show what the authority
         actually answered. Blank until the posting job runs; that blank is
         "not yet reported", not an error. Section 79. */
      /* TWO SOURCES, ONE COLUMN. The PPF status comes from the Status
         API, written onto the document by RefreshStatus; PA_EXCHG_STAT
         comes from the IRN write-back of the posting job. They are both
         "what the authority said", arriving by different routes, so they
         coalesce rather than compete - PPF first because it is the
         pull: a refresh is an explicit question asked just now, where
         the exchange row is whatever the last posting run left behind.
         Section 81. */
      coalesce( _Doc.govt_ppf_status, _Exchange.PaExchangeStatus )
                                          as GovernmentStatus,
      _Doc.govt_ppf_action                as GovernmentAction,
      _Exchange.PaExchangeResponseCode    as GovernmentResponseCode,
      _Exchange.PaExchangeResponseMessage as GovernmentMessage,

      /* Same mapping as StatusCriticality, applied to the government
         stage alone. 0 (neutral) covers both "blank" and any status the
         platform adds later - an unknown value must not be coloured
         green. */
      case upper( coalesce( _Doc.govt_ppf_status, _Exchange.PaExchangeStatus ) )
        when 'VALID'                      then 3
        when 'SUCCESS'                    then 3
        when 'COMPLETED'                  then 3
        when 'COLLECTED'                  then 3
        when 'ACCEPTED'                   then 3
        when 'DELIVERED TO BUYER'         then 3
        when 'SUBMITTED'                  then 2
        when 'PENDING'                    then 2
        when 'RECEIVED'                   then 2
        when 'DELIVERED TO BUYER NETWORK' then 2
        when 'ERROR'                      then 1
        when 'FAILURE'                    then 1
        when 'INVALID'                    then 1
        when 'REJECTED'                   then 1
        when 'CANCELLED'                  then 1
        else 0
      end                                 as GovernmentCriticality,

      /* Has this candidate been materialised in ZTEINV_DOC at all?
         'X' means the object page and its five actions are reachable;
         blank means the row exists only in this view. */
      case when _Doc.bukrs is not null then 'X' else '' end
                                          as IsProcessed,

      /* DELETE gt_final WHERE cancel = 'X'. fill_einv_status set CANCEL
         only when the document had no ID yet AND the FI document was
         reversed or reversing. A document that already reached the portal
         keeps its INVID and therefore stays visible. The NO_ACC branch
         carries no reversal indicator (VBRK-FKSTO has no released
         counterpart), so those rows are never hidden by this rule. */
      case when _Doc.invid is null
            and ( cand.IsReversed = 'X' or cand.IsReversal = 'X' )
           then 'X' else '' end           as IsCancelled,

      case upper( coalesce( _Exchange.PaExchangeStatus,
                            coalesce( _Async.SyncStatus, _Doc.status ) ) )
        when 'VALID'                      then 3
        when 'SUCCESS'                    then 3
        when 'COMPLETED'                  then 3
        when 'COLLECTED'                  then 3
        when 'ACCEPTED'                   then 3
        when 'DELIVERED TO BUYER'         then 3
        when 'SUBMITTED'                  then 2
        when 'PENDING'                    then 2
        when 'RECEIVED'                   then 2
        when 'DELIVERED TO BUYER NETWORK' then 2
        when 'ERROR'                      then 1
        when 'FAILURE'                    then 1
        when 'INVALID'                    then 1
        when 'REJECTED'                   then 1
        when 'CANCELLED'                  then 1
        else 0
      end                                 as StatusCriticality,

      _Doc,
      _Async,
      _Exchange
}
