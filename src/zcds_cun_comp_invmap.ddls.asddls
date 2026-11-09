@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Relevance Mapping (config tab)'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #CUSTOMIZING
}

/* =====================================================================
   Relevance Mapping as a tab of the ELT Config Details object page.

   Second consumption view over ZCDS_INT_EINV_INVMAP; the standalone
   e-Invoice Relevance Mappings app keeps its own. Same pattern as
   ZCDS_CUN_ELT_CONFIG and the three added in section 89 - parent
   association on PROJECTID alone, [0..*]. Section 90.
   ===================================================================== */
define view entity ZCDS_CUN_COMP_INVMAP as select from ZCDS_INT_EINV_INVMAP
  association to parent ZCDS_CUN_COMP_DETAILS as _COMPANY_DETAILS
    on $projection.ProjectId = _COMPANY_DETAILS.Projectid
{
  key ZCDS_INT_EINV_INVMAP.ProjectId,
  key ZCDS_INT_EINV_INVMAP.SystemId,
  key ZCDS_INT_EINV_INVMAP.Country,
  key ZCDS_INT_EINV_INVMAP.CompanyCode,
  key ZCDS_INT_EINV_INVMAP.BillingDocumentType,
  key ZCDS_INT_EINV_INVMAP.AccountingDocumentType,
  key ZCDS_INT_EINV_INVMAP.DocumentTypeCode,
      ZCDS_INT_EINV_INVMAP.IsEInvoiceRelevant,
      ZCDS_INT_EINV_INVMAP.IsEWayBillRelevant,
      ZCDS_INT_EINV_INVMAP.IsNonIrn,
      ZCDS_INT_EINV_INVMAP.HasNoAccountingDoc,
      ZCDS_INT_EINV_INVMAP.IsB2C,
      ZCDS_INT_EINV_INVMAP.IsPurchase,
      _COMPANY_DETAILS
}
