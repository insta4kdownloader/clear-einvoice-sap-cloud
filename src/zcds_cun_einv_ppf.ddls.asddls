@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'e-Invoice Government Reporting'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
/* No `provider contract transactional_query` here: the contract is
   declared once on the root projection and inherited. Declaring it on a
   view that also carries `redirected to parent` is rejected. */
define view entity ZCDS_CUN_EINV_PPF
  as projection on ZCDS_INT_EINV_PPF
{
  key BillingDocument,
  key AccountingDocument,
  key CompanyCode,
  key FiscalYear,
      @EndUserText.label: 'Entry'
  key SequenceNumber,
      @EndUserText.label: 'Reason'
  key ReasonNumber,

      @EndUserText.label: 'PPF Status'
      PpfStatus,
      @EndUserText.label: 'PPF Action'
      PpfAction,
      @EndUserText.label: 'Action Type'
      PpfActionType,
      @EndUserText.label: 'Transaction ID'
      TransactionId,

      @EndUserText.label: 'Received On (UTC)'
      ReceivedDate,
      @EndUserText.label: 'Received At (UTC)'
      ReceivedTime,
      @EndUserText.label: 'Milliseconds'
      ReceivedMilliseconds,

      @EndUserText.label: 'Reason Code'
      ReasonCode,
      @EndUserText.label: 'Reason'
      ReasonText,

      @EndUserText.label: 'Clear Document ID'
      ClearDocumentId,
      @EndUserText.label: 'Recorded On'
      CreatedOn,
      @EndUserText.label: 'Recorded At'
      CreatedAt,
      @EndUserText.label: 'Recorded By'
      CreatedBy,

      PpfCriticality,

      _Document: redirected to parent ZCDS_CUN_EINV_DOC
}
