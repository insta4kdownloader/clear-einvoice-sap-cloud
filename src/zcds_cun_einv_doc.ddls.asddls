@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Sales e-Invoice Cockpit'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #L,
    dataClass: #TRANSACTIONAL
}
@Search.searchable: true
define root view entity ZCDS_CUN_EINV_DOC
  provider contract transactional_query
  as projection on ZCDS_INT_EINV_DOC
{
      @EndUserText.label: 'Billing Document'
      @UI.selectionField: [ { position: 20 } ]
      @Consumption.semanticObject: 'BillingDocument'
      @Search.defaultSearchElement: true
  key BillingDocument,

      @EndUserText.label: 'Accounting Document'
      @UI.selectionField: [ { position: 30 } ]
      @Consumption.semanticObject: 'AccountingDocument'
      @Search.defaultSearchElement: true
  key AccountingDocument,

      @EndUserText.label: 'Company Code'
      @UI.selectionField: [ { position: 10 } ]
      @Consumption.valueHelpDefinition: [ { entity: { name: 'ZVH_EINV_COMPANYCODE', element: 'CompanyCode' } } ]
  key CompanyCode,

      @EndUserText.label: 'Fiscal Year'
      @UI.selectionField: [ { position: 40 } ]
  key FiscalYear,

      /* ---- effective status (see COALESCE in the interface view) ---- */
      @EndUserText.label: 'Status'
      @UI.selectionField: [ { position: 50 } ]
      @Consumption.valueHelpDefinition: [ { entity: { name: 'ZVH_EINV_STATUS', element: 'StatusCode' } } ]
      _Enrich.EffectiveStatus  as EffectiveStatus,

      @EndUserText.label: 'Message'
      _Enrich.EffectiveMessage as EffectiveMessage,

      /* -----------------------------------------------------------------
         Criticality replaces /CLR/EINV_STATUS-COLOR_CODE + SYNC_ICON and
         the lvc_t_scol cell-colour table that set_status_colors filled.

         It is a CASE in ZCDS_INT_EINV_DOC_ENR reached through _Enrich, not
         a virtual element: @ObjectModel.virtualElement is not released for
         ABAP Cloud. A path expression is also filterable and sortable,
         which a virtual element is not.
         ----------------------------------------------------------------- */
      @EndUserText.label: 'Criticality'
      _Enrich.StatusCriticality as StatusCriticality,

      @EndUserText.label: 'e-Invoice Number'
      EInvoiceNumber,

      @EndUserText.label: 'e-Invoice Date'
      EInvoiceDate,

      @EndUserText.label: 'Clear Document ID'
      @Search.defaultSearchElement: true
      ClearDocumentId,

      @EndUserText.label: 'Document Type Code'
      DocumentTypeCode,

      @EndUserText.label: 'Invoice Type'
      EInvoiceInvoiceType,

      @EndUserText.label: 'Sync. Status'
      SyncStatus,

      @EndUserText.label: 'B2C'
      IsB2C,

      @EndUserText.label: 'B2G'
      IsB2G,

      @EndUserText.label: 'Sent'
      IsSent,

      @EndUserText.label: 'B2C Status'
      B2CStatus,

      /* The latest government reporting entry, as RefreshStatus left it.
         The full history is the _Ppf child. Section 81. */
      @EndUserText.label: 'Government Status'
      GovernmentStatus,
      @EndUserText.label: 'PPF Status'
      PpfStatus,
      @EndUserText.label: 'PPF Action'
      PpfAction,

      @EndUserText.label: 'e-Invoice Identifier'
      EInvoiceIdentifier,

      @EndUserText.label: 'e-Invoice Type'
      EInvoiceType,

      @EndUserText.label: 'Command ID'
      CommandId,

      /* The QR code and the signed payload are large and are never filtered
         on, so they are kept off the list report (@UI.hidden in the metadata
         extension) and shown only on the object page. */
      @EndUserText.label: 'Signed Invoice QR Code'
      SignedQrCode,

      @EndUserText.label: 'Signed Invoice'
      SignedInvoice,

      @EndUserText.label: 'Platform UUID'
      @Search.defaultSearchElement: true
      PlatformUuid,

      @EndUserText.label: 'Created On'
      @UI.selectionField: [ { position: 60 } ]
      CreatedOn,

      @EndUserText.label: 'Created At'
      CreatedAt,

      @EndUserText.label: 'Created By'
      CreatedBy,

      LocalLastChangedAt,

      /* ---- enrichment that fill_partner_data used to read from BSEG /
             KNA1 / LFA1; now taken from the released document views ---- */
      /* NOTE: the HANA cockpit showed BSEG-WRBTR (fill_partner_data).
         I_JournalEntry carries no header total, so if the amount column
         is required, add an aggregating view over I_JournalEntryItem and
         expose it through an association here - do not guess a field
         name on I_JournalEntry.
         These six are path expressions over _Enrich rather than elements of
         ZCDS_INT_EINV_DOC: the root view of a managed business object has to
         stay 1:1 with ZTEINV_DOC. Path expressions over a to-one association
         stay filterable and sortable - which a virtual element would not be,
         and EffectiveStatus above is a @UI.selectionField. */
      @EndUserText.label: 'Currency'
      _Enrich.TransactionCurrency       as TransactionCurrency,

      @EndUserText.label: 'Reversed'
      _Enrich.IsReversed                as IsReversed,

      @EndUserText.label: 'Reversal'
      _Enrich.IsReversal                as IsReversal,

      /* ---- children ---- */
      _Error   : redirected to composition child ZCDS_CUN_EINV_DOC_ERR,
      _Exchange: redirected to composition child ZCDS_CUN_EINV_DOC_STAT,
      _Ppf     : redirected to composition child ZCDS_CUN_EINV_PPF,
      _Archive : redirected to composition child ZCDS_CUN_EINV_ZIP
}
