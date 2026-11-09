@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interface View for e-Invoice Document Ty'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #CUSTOMIZING
}
define root view entity ZCDS_INT_EINV_DOCTYP as select from zteinv_doctyp
{
  key projectid as ProjectId,
  key sysid as SystemId,
  key land1 as Country,
  key bukrs as CompanyCode,
  key transact_type as TransactionType,
  key doc_type_code as DocumentTypeCode,
  doc_type_descr as DocumentTypeDescription
}
