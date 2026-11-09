@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'e-Invoice API Error Details'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
/* No `provider contract transactional_query` here: the contract is
   declared once on the root projection and inherited. Declaring it on a
   view that also carries `redirected to parent` is rejected. */
define view entity ZCDS_CUN_EINV_DOC_ERR
  as projection on ZCDS_INT_EINV_DOC_ERR
{
      @EndUserText.label: 'Billing Document'
  key BillingDocument,
      @EndUserText.label: 'Accounting Document'
  key AccountingDocument,
      @EndUserText.label: 'Company Code'
  key CompanyCode,
      @EndUserText.label: 'Fiscal Year'
  key FiscalYear,
      @EndUserText.label: 'e-Invoice Number'
  key EInvoiceNumber,
      @EndUserText.label: 'Error No.'
  key ErrorNumber,

      @EndUserText.label: 'Error Date'
      ErrorDate,
      @EndUserText.label: 'Error Time'
      ErrorTime,
      @EndUserText.label: 'Error Code'
      ErrorCode,
      @EndUserText.label: 'Error Source'
      ErrorSource,
      @EndUserText.label: 'Error Message'
      ErrorMessage,

      _Document: redirected to parent ZCDS_CUN_EINV_DOC
}
