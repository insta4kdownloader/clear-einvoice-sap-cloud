@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'e-Invoice Extract Archive'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
/* Consumption projection of the extract archive. No `provider contract
   transactional_query`: it is declared once on the root projection and
   inherited, and declaring it on a view that also carries `redirected to
   parent` is rejected. Section 55 is where that was learned. */
define view entity ZCDS_CUN_EINV_ZIP
  as projection on ZCDS_INT_EINV_ZIP
{
  key BillingDocument,
  key AccountingDocument,
  key CompanyCode,
  key FiscalYear,

      @EndUserText.label: 'Command ID'
      CommandId,
      @EndUserText.label: 'MIME Type'
      MimeType,
      @EndUserText.label: 'File Name'
      FileName,
      @EndUserText.label: 'Archive'
      Content,
      @EndUserText.label: 'Created On'
      CreatedOn,
      @EndUserText.label: 'Created At'
      CreatedAt,

      _Document: redirected to parent ZCDS_CUN_EINV_DOC
}
