@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'e-Invoice PPF Reporting History'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #M,
    dataClass: #TRANSACTIONAL
}

/* =====================================================================
   /CLR/ZT_EINV_PPF - the government (PPF) reporting history of one
   document, written by save_ppf_details from the Status API's
   GovtReportingDetails block.

   TWO LEVELS FLATTENED INTO ONE TABLE. The payload nests
   StatusReasons[] inside GovtReportingDetails[], and HANA flattens the
   cross product: SEQNO is the index of the reporting entry, RSNNO the
   index of the reason within it. An entry with no reasons still produces
   one row, with RSNNO = 000 - so the entry itself is never lost just
   because the authority gave no reason for it. Both key components are
   kept exactly as HANA numbers them.

   RECV_DATE / RECV_TIME / RECV_MSEC are the authority's own timestamp,
   in UTC, split out of the ISO 8601 string. They are NOT the time this
   system received anything; CRDAT / CRTIME / CRUSER are that.

   Section 81.
   ===================================================================== */
define view entity ZCDS_INT_EINV_PPF as select from zteinv_ppf
  association to parent ZCDS_INT_EINV_DOC as _Document
    on  $projection.BillingDocument    = _Document.BillingDocument
    and $projection.AccountingDocument = _Document.AccountingDocument
    and $projection.CompanyCode        = _Document.CompanyCode
    and $projection.FiscalYear         = _Document.FiscalYear
{
  key vbeln       as BillingDocument,
  key belnr       as AccountingDocument,
  key bukrs       as CompanyCode,
  key gjahr       as FiscalYear,
      @EndUserText.label: 'Reporting Entry'
  key seqno       as SequenceNumber,
      @EndUserText.label: 'Reason'
  key rsnno       as ReasonNumber,

      invid       as ClearDocumentId,
      trans_id    as TransactionId,
      ppf_action  as PpfAction,
      ppf_acttyp  as PpfActionType,
      ppf_status  as PpfStatus,

      recv_date   as ReceivedDate,
      recv_time   as ReceivedTime,
      recv_msec   as ReceivedMilliseconds,

      reason_code as ReasonCode,
      reason_text as ReasonText,

      crdat       as CreatedOn,
      crtime      as CreatedAt,
      cruser      as CreatedBy,

      /* Same mapping as the document's StatusCriticality, applied to the
         PPF status. Unknown and blank fall to 0 rather than green. */
      case upper( ppf_status )
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
      end         as PpfCriticality,

      _Document
}
