@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interface View for e-Invoice Document Re'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #CUSTOMIZING
}
define root view entity ZCDS_INT_EINV_INVMAP as select from zteinv_invmap
{
  key projectid as ProjectId,
  key sysid as SystemId,
  key land1 as Country,
  key bukrs as CompanyCode,
  key fkart as BillingDocumentType,
  key blart as AccountingDocumentType,
  key doc_type as DocumentTypeCode,
  einvoice as IsEInvoiceRelevant,
  ewaybill as IsEWayBillRelevant,
  nonirn as IsNonIrn,
  no_acc as HasNoAccountingDoc,
  b2c as IsB2C,
  purchase as IsPurchase
}
