@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Document Type (config tab)'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #CUSTOMIZING
}

/* =====================================================================
   Document Type as a tab of the ELT Config Details object page.

   Second consumption view over ZCDS_INT_EINV_DOCTYP; the standalone
   e-Invoice Document Types app keeps its own. Same pattern as
   ZCDS_CUN_ELT_CONFIG and the three added in section 89 - parent
   association on PROJECTID alone, [0..*]. Section 90.
   ===================================================================== */
define view entity ZCDS_CUN_COMP_DOCTYP as select from ZCDS_INT_EINV_DOCTYP
  association to parent ZCDS_CUN_COMP_DETAILS as _COMPANY_DETAILS
    on $projection.ProjectId = _COMPANY_DETAILS.Projectid
{
  key ZCDS_INT_EINV_DOCTYP.ProjectId,
  key ZCDS_INT_EINV_DOCTYP.SystemId,
  key ZCDS_INT_EINV_DOCTYP.Country,
  key ZCDS_INT_EINV_DOCTYP.CompanyCode,
  key ZCDS_INT_EINV_DOCTYP.TransactionType,
  key ZCDS_INT_EINV_DOCTYP.DocumentTypeCode,
      ZCDS_INT_EINV_DOCTYP.DocumentTypeDescription,
      _COMPANY_DETAILS
}
