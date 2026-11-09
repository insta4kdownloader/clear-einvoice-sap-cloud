@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'e-Invoice API Error Details'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #M,
    dataClass: #TRANSACTIONAL
}
define view entity ZCDS_INT_EINV_DOC_ERR as select from zteinv_err
  association to parent ZCDS_INT_EINV_DOC as _Document
    on  $projection.BillingDocument    = _Document.BillingDocument
    and $projection.AccountingDocument = _Document.AccountingDocument
    and $projection.CompanyCode        = _Document.CompanyCode
    and $projection.FiscalYear         = _Document.FiscalYear
{
  key vbeln        as BillingDocument,
  key belnr        as AccountingDocument,
  key bukrs        as CompanyCode,
  key gjahr        as FiscalYear,
  key invno        as EInvoiceNumber,
  key errorno      as ErrorNumber,

      errordate    as ErrorDate,
      errortime    as ErrorTime,
      errorcode    as ErrorCode,
      errorsource  as ErrorSource,
      errormessage as ErrorMessage,

      _Document
}
