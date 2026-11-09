/* =====================================================================
   Sales e-Invoice enrichment.

   Everything that is derived rather than stored lives here, deliberately
   OUTSIDE the business object's root view.

   A managed RAP business object maps every element of its root view onto a
   column of the persistent table - elements that are not listed in the
   `mapping for` block are mapped implicitly by name. A calculated element
   in the root view therefore has no column to map to and the behaviour
   definition does not activate. Keeping the calculation in a separate view
   and reaching it through a [1..1] association solves that: the projection
   exposes it as a plain path expression (filterable, sortable, and
   read-only by construction) and the behaviour definition never sees it.

   Contents:

   1. Status precedence, taken over 1:1 from /CLR/ZCL_EINV_BASE:
        fill_sales_status  (exchange / MLS)  overrides
        fill_async_status  (asynchronous)    overrides
        fill_einv_status   (synchronous)
      In the HANA cockpit this was three sequential overlay methods on
      GT_FINAL; here it is one deterministic COALESCE, so the effective
      status is a queryable, sortable, filterable field.

   2. Enrichment from the released document views, replacing the
      BSEG / VBRK / KNA1 / LFA1 reads of select_partner_data and the
      XREVERS* checks of submit_data_batch.

      The billing-side half of that check is deliberately absent:
      I_BillingDocument carries no CancellationStatus element in this
      release (the 2026-10-01 activation said so), and a cancelled billing
      document posts an FI reversal anyway, which _Journal.IsReversed
      already reports. If you want the billing flag as well, confirm the
      element name in ADT - BillingDocumentIsCancelled is the likely one -
      and add:
          association [0..1] to I_BillingDocument as _Billing
            on $projection.BillingDocument = _Billing.BillingDocument
      with the column beside IsReversal below.
   ===================================================================== */
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Sales e-Invoice Derived Status'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #C,
    sizeCategory: #L,
    dataClass: #TRANSACTIONAL
}
define view entity ZCDS_INT_EINV_DOC_ENR as select from zteinv_doc
  association [0..1] to ZCDS_INT_EINV_DOC_STAT as _Exchange on  $projection.BillingDocument    = _Exchange.BillingDocument
                                                            and $projection.AccountingDocument = _Exchange.AccountingDocument
                                                            and $projection.CompanyCode        = _Exchange.CompanyCode
                                                            and $projection.FiscalYear         = _Exchange.FiscalYear
  association [0..1] to ZCDS_INT_EINV_DOC_ASY  as _Async    on  $projection.BillingDocument    = _Async.BillingDocument
                                                            and $projection.AccountingDocument = _Async.AccountingDocument
                                                            and $projection.CompanyCode        = _Async.CompanyCode
                                                            and $projection.FiscalYear         = _Async.FiscalYear
  association [0..1] to I_JournalEntry         as _Journal  on  $projection.CompanyCode        = _Journal.CompanyCode
                                                            and $projection.AccountingDocument = _Journal.AccountingDocument
                                                            and $projection.FiscalYear         = _Journal.FiscalYear
{
  key vbeln as BillingDocument,
  key belnr as AccountingDocument,
  key bukrs as CompanyCode,
  key gjahr as FiscalYear,

      coalesce( _Exchange.PaExchangeStatus,
                coalesce( _Async.SyncStatus, status ) ) as EffectiveStatus,

      coalesce( _Exchange.PaExchangeResponseMessage,
                coalesce( _Async.ErrorText, error ) )   as EffectiveMessage,

      _Journal.TransactionCurrency as TransactionCurrency,
      _Journal.IsReversed          as IsReversed,
      _Journal.IsReversal          as IsReversal,

      /* ---------------------------------------------------------------
         Status criticality, replacing /CLR/EINV_STATUS-COLOR_CODE and the
         icon SWITCH of call_seller_action (@5B@ green / @5C@ red / @01@ /
         @BZ@). It was a virtual element until the 2026-10-01 activation
         reported @ObjectModel.virtualElement as not released for ABAP
         Cloud; as a CASE here it is filterable and sortable as well, which
         a virtual element never was.

         THIS IS THE ONLY MAPPING. ZTEINV_STATUS is not consulted, here or
         anywhere else: its reader chain ends at ZCL_EINV_VE_CRITICALITY,
         a virtual-element class that no view references because
         @ObjectModel.virtualElement is not released for ABAP Cloud. The
         table was maintained and ignored. Retired on the owner's decision
         rather than wired up - section 87.

         So the status list below IS the configuration, and extending it
         is a transport. Keep it identical in all four places it appears
         (here, both expressions in ZCDS_INT_EINV_LIVE, and
         ZCDS_INT_EINV_PPF); checker rule 67 enforces that.
         --------------------------------------------------------------- */
      case upper( coalesce( _Exchange.PaExchangeStatus,
                            coalesce( _Async.SyncStatus, status ) ) )
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
      end                          as StatusCriticality
}
