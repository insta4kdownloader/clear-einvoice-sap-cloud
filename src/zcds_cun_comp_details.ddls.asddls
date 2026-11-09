@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Cunsumption View for company Details'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
@Metadata.allowExtensions: true
define root view entity ZCDS_CUN_COMP_DETAILS
  as select from ZCDS_INT_COMP_DETAILS
  composition [0..*] of ZCDS_CUN_ELT_CONFIG as _ELT_CONFIG_DETAILS
  composition [0..*] of ZCDS_CUN_INS_CONFIG as _INS_CONFIG_DETAILS
  /* The three e-invoice customizing tables, as further tabs. All keyed on
     PROJECTID first, so the same parent association works. Section 89. */
  composition [0..*] of ZCDS_CUN_COMP_CNTRY  as _CNTRY_DETAILS
  composition [0..*] of ZCDS_CUN_COMP_VAT    as _VAT_DETAILS
  composition [0..*] of ZCDS_CUN_COMP_API    as _API_DETAILS
  /* Relevance Mapping and Document Types, section 90. */
  composition [0..*] of ZCDS_CUN_COMP_INVMAP as _INVMAP_DETAILS
  composition [0..*] of ZCDS_CUN_COMP_DOCTYP as _DOCTYP_DETAILS
{
key ZCDS_INT_COMP_DETAILS.Projectid,
ZCDS_INT_COMP_DETAILS.Compname,
      _ELT_CONFIG_DETAILS,
      _INS_CONFIG_DETAILS,
      _CNTRY_DETAILS,
      _VAT_DETAILS,
      _API_DETAILS,
      _INVMAP_DETAILS,
      _DOCTYP_DETAILS
}
