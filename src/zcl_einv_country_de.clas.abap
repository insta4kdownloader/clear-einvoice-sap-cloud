"! <p class="shorttext synchronized">e-Invoice country handler: Germany</p>
"!
"! Registers Germany as a supported country.
"!
"! `/CLR/ZCL_EINV_DE` was added in the 2026-09-25 drop and is EMPTY - 15
"! lines, no overrides, byte-identical to `/CLR/ZCL_EINV_AE`, `_FR`, `_OM`
"! and `_JO`. All five exist purely so that the HANA factory's dynamic
"! `CREATE OBJECT ro_instance TYPE ('/CLR/ZCL_EINV_' && land1)` finds a
"! class instead of returning an unbound reference.
"!
"! The real per-country differentiation added in that drop is NOT in these
"! classes: it is the new IV_COUNTRY parameter threaded from
"! `submit_data` -> `submit_data_retrieval` ->
"! `/CLR/EINV_EWAY_TRIGGER_ELT` -> `/CLR/ZCL_ELT`, plus the configuration
"! tables. Country behaviour moved OUT of the subclass hierarchy and INTO
"! the ELT command layer.
"!
"! This class is therefore a deliberate no-op that inherits everything from
"! ZCL_EINV_COUNTRY_DEFAULT. It exists so that setting
"! ZTEINV_CNTRY-HANDLER_CLASS = 'ZCL_EINV_COUNTRY_DE' works, and so there
"! is an obvious place to put German specifics (XRechnung / Peppol BIS
"! profile rules, Leitweg-ID validation) when they are actually specified.
CLASS zcl_einv_country_de DEFINITION
  PUBLIC
  INHERITING FROM zcl_einv_country_default
  CREATE PUBLIC.

  PUBLIC SECTION.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_einv_country_de IMPLEMENTATION.
ENDCLASS.
