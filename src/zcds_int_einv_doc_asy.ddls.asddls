@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Async e-Invoice Status'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #L,
    dataClass: #TRANSACTIONAL
}
define view entity ZCDS_INT_EINV_DOC_ASY as select from zteinv_doc_asy
{
  key vbeln      as BillingDocument,
  key belnr      as AccountingDocument,
  key bukrs      as CompanyCode,
  key gjahr      as FiscalYear,

      invno      as EInvoiceNumber,
      invdt      as EInvoiceDate,
      doc_type   as DocumentTypeCode,
      invid      as ClearDocumentId,
      invtype    as EInvoiceInvoiceType,
      status     as SyncStatus,
      error      as ErrorText,
      b2c        as IsB2C,
      b2g        as IsB2G,
      sent       as IsSent,
      b2c_status as B2CStatus,
      crdat      as CreatedOn,
      crtime     as CreatedAt,
      cruser     as CreatedBy
}
