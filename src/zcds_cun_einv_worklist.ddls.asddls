@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Sales e-Invoice Worklist'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
@ObjectModel.usageType:{
    serviceQuality: #C,
    sizeCategory: #L,
    dataClass: #TRANSACTIONAL
}
/* =====================================================================
   What the cockpit list reads. Read-only by design: a candidate that has
   not been picked up has no row to update, exactly as the HANA ALV had no
   database row behind an unprocessed line.

   MANDATORY POSTING DATE. /CLR/ELT_EINVOICE_COCKPIT refused to run with
   both date ranges empty - AT SELECTION-SCREEN raised e015, and get_data
   returned immediately as a second guard. A Fiori list report has no such
   gate and would otherwise scan I_JournalEntry unfiltered, so the filter
   is declared mandatory here.

   CANCELLED DOCUMENTS are filtered out, restoring
   DELETE gt_final WHERE cancel = 'X'. Note this is a deliberate reversal
   of the earlier conversion decision, which kept them for the audit
   trail: a document that reached the portal still has its INVID and is
   therefore NOT cancelled by this rule, so only never-submitted reversals
   disappear.
   ===================================================================== */
/* `root`, not a plain view entity: a behaviour definition can only be
   written for the root of a composition hierarchy, even when that
   hierarchy has exactly one node and no children. Without it the
   activation fails with "not a root entity or is not released for
   BEHAVIOR implementations", and the behaviour pool fails alongside it
   with "not part of a composition hierarchy of CDS entities". Declaring
   it root costs nothing - it adds no composition and changes no SQL. */
define root view entity ZCDS_CUN_EINV_WORKLIST
  as select from ZCDS_INT_EINV_LIVE
{
      @EndUserText.label: 'Company Code'
      @UI.selectionField: [ { position: 10 } ]
      @Consumption.filter: { mandatory: true, selectionType: #SINGLE }
      @Consumption.valueHelpDefinition: [ { entity: { name: 'ZVH_EINV_COMPANYCODE', element: 'CompanyCode' } } ]
  key CompanyCode,
      @EndUserText.label: 'Accounting Document'
  key AccountingDocument,
      @EndUserText.label: 'Fiscal Year'
      @UI.selectionField: [ { position: 40 } ]
  key FiscalYear,
      @EndUserText.label: 'Billing Document'
  key BillingDocument,
      @EndUserText.label: 'Project ID'
      @UI.selectionField: [ { position: 50 } ]
  key ProjectId,
      @EndUserText.label: 'System ID'
  key SystemId,
      @EndUserText.label: 'Country'
  key Country,
      @EndUserText.label: 'Document Type Code'
  key DocumentTypeCode,

      @EndUserText.label: 'Billing Type'
      BillingDocumentType,
      @EndUserText.label: 'Accounting Doc. Type'
      AccountingDocumentType,
      @EndUserText.label: 'Document Date'
      DocumentDate,
      @EndUserText.label: 'Posting Date'
      @UI.selectionField: [ { position: 20 } ]
      @Consumption.filter: { mandatory: true, selectionType: #INTERVAL }
      PostingDate,
      @EndUserText.label: 'Creation Date'
      @UI.selectionField: [ { position: 30 } ]
      CreationDate,

      @EndUserText.label: 'e-Invoice Number'
      EInvoiceNumber,
      @EndUserText.label: 'Document ID'
      EInvoiceDocumentId,
      @EndUserText.label: 'Command ID'
      CommandId,
      @EndUserText.label: 'UUID'
      Uuid,
      @EndUserText.label: 'Signed QR Code'
      SignedQrCode,
      @EndUserText.label: 'Signed Invoice'
      SignedInvoice,
      @EndUserText.label: 'Created On'
      EInvoiceCreatedOn,
      @EndUserText.label: 'Created By'
      EInvoiceCreatedBy,
      @EndUserText.label: 'Sent'
      IsSent,

      @EndUserText.label: 'Status'
      @UI.selectionField: [ { position: 60 } ]
      EffectiveStatus,
      @EndUserText.label: 'Message'
      EffectiveMessage,

      /* The tax authority's own answer, from ZTEINV_SALES_ST stage 1.
         Filterable: "show me everything the authority has rejected" is
         the question this dashboard could not previously be asked. */
      @EndUserText.label: 'Government Status'
      @UI.selectionField: [ { position: 80 } ]
      GovernmentStatus,
      @EndUserText.label: 'Government Action'
      GovernmentAction,
      @EndUserText.label: 'Government Resp. Code'
      GovernmentResponseCode,
      @EndUserText.label: 'Government Message'
      GovernmentMessage,
      GovernmentCriticality,
      @EndUserText.label: 'Processed'
      @UI.selectionField: [ { position: 70 } ]
      IsProcessed,
      @EndUserText.label: 'B2C'
      IsB2C,
      @EndUserText.label: 'Reversed'
      IsReversed,

      StatusCriticality
}
where
  IsCancelled = ''
