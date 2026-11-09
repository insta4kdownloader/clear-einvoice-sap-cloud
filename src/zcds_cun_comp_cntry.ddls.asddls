@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Country Registration (config tab)'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #CUSTOMIZING
}

/* =====================================================================
   Country Registration as a tab of the ELT Config Details object page.

   A SECOND consumption view over ZCDS_INT_EINV_CNTRY, not a replacement.
   The standalone e-Invoice Country Registrations app keeps its own consumption
   view and service; this one exists only to hang the same rows off
   ZCDS_CUN_COMP_DETAILS as a composition child, the way
   ZCDS_CUN_ELT_CONFIG does for ZTELT_CONFIG.

   PROJECTID is the leading key of the table, so the parent association
   joins on it alone and the cardinality is [0..*]: one project owns
   every row maintained for it, across country, company code and
   sequence. Section 89.
   ===================================================================== */
define view entity ZCDS_CUN_COMP_CNTRY as select from ZCDS_INT_EINV_CNTRY
  association to parent ZCDS_CUN_COMP_DETAILS as _COMPANY_DETAILS
    on $projection.ProjectId = _COMPANY_DETAILS.Projectid
{
  key ZCDS_INT_EINV_CNTRY.ProjectId,
  key ZCDS_INT_EINV_CNTRY.SystemId,
  key ZCDS_INT_EINV_CNTRY.Country,
  key ZCDS_INT_EINV_CNTRY.CompanyCode,
  key ZCDS_INT_EINV_CNTRY.Sequence,
      ZCDS_INT_EINV_CNTRY.VatRegistrationNumber,
      ZCDS_INT_EINV_CNTRY.CountryDescription,
      ZCDS_INT_EINV_CNTRY.AutoGenerate,
      ZCDS_INT_EINV_CNTRY.AutoCancel,
      ZCDS_INT_EINV_CNTRY.HandlerClass,
      _COMPANY_DETAILS
}
