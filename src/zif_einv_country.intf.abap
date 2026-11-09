"! <p class="shorttext synchronized">e-Invoice: country-specific behaviour</p>
"!
"! Replaces the dynamic-class factory of /CLR/ZCL_EINV_FACTORY:
"!
"!   lv_classname = '/CLR/ZCL_EINV_' && to_upper( land1 ).
"!   CONDENSE lv_classname NO-GAPS.
"!   CREATE OBJECT ro_instance TYPE (lv_classname).
"!
"! That built a class name out of a country code, so adding a country
"! meant creating a class with exactly the right name and nothing
"! declared the contract. Here the contract is this interface, and the
"! implementing class is configured per company code in
"! ZTEINV_CNTRY-HANDLER_CLASS, so it is data, not a naming convention.
"!
"! Note for the port: /CLR/ZCL_EINV_AE, _FR and _OM were all EMPTY -
"! every hook (cancel, call_cancel, edit_row, exclude_doc) inherited an
"! empty body from the base class. There is therefore no country logic
"! to migrate; ZCL_EINV_COUNTRY_DEFAULT carries the sane default
"! behaviour, and a real country handler only needs to override what
"! genuinely differs.
INTERFACE zif_einv_country
  PUBLIC.

  "! Document-level exclusion.
  "!
  "! Replaces /CLR/ZCL_EINV_BASE~exclude_doc, which was an empty method
  "! returning a blank RV_ELIGLIBLE. Because consolidate_data treated
  "! blank as "not eligible", maintaining the EXCLUDE_DOC constant in
  "! /CLR/EINV_CONST silently suppressed EVERY document. The polarity is
  "! inverted here so that the safe default is "do not exclude".
  "!
  "! @parameter iv_bukrs   | Company code
  "! @parameter iv_belnr   | Accounting document
  "! @parameter iv_gjahr   | Fiscal year
  "! @parameter iv_vbeln   | Billing document
  "! @parameter iv_blart   | Accounting document type
  "! @parameter iv_fkart   | Billing document type
  "! @parameter rv_excluded | abap_true when the document must be skipped
  METHODS is_document_excluded
    IMPORTING iv_bukrs           TYPE zde_einv_bukrs
              iv_belnr           TYPE zde_einv_accdoc OPTIONAL
              iv_gjahr           TYPE zde_einv_gjahr OPTIONAL
              iv_vbeln           TYPE zde_einv_billdoc OPTIONAL
              iv_blart           TYPE zde_einv_blart OPTIONAL
              iv_fkart           TYPE zde_einv_fkart OPTIONAL
    RETURNING VALUE(rv_excluded) TYPE abap_boolean.

  "! Cancellation eligibility.
  "!
  "! /CLR/ZCL_EINV_BASE~cancel and ~call_cancel were empty, so the rules
  "! survive only as message texts in /CLR/ZME_EINV (074 not authorized,
  "! 075 cancel the document first, 089 cannot be cancelled after 72
  "! hours). Returns an empty string when cancellation is allowed, or
  "! the reason why it is not.
  "! IV_BUKRS is what scopes the CANCEL_WINDOW_H constant. Without it the
  "! implementation has to look the constant up with a blank company code,
  "! which resolves to a blank country and therefore matches no
  "! ZTEINV_CONST row at all - the configurable window would be silently
  "! ignored and the hard-coded default would always win.
  METHODS check_cancel_allowed
    IMPORTING iv_bukrs         TYPE zde_einv_bukrs
              iv_created_on    TYPE d
              iv_created_at    TYPE t
              iv_status        TYPE zde_einv_status
    RETURNING VALUE(rv_reason) TYPE string.

  "! Maps a platform status onto a UI criticality.
  "!
  "! Replaces set_status_colors, which filled an lvc_t_scol cell-colour
  "! table from /CLR/EINV_STATUS-COLOR_CODE, and the icon derivation
  "! (@5B@ / @5C@ / @5D@ / @01@ / @BZ@) of call_seller_action.
  METHODS map_criticality
    IMPORTING iv_bukrs              TYPE zde_einv_bukrs
              iv_status             TYPE zde_einv_status
    RETURNING VALUE(rv_criticality) TYPE zde_einv_crit.

  "! Lets a country add or override HTTP headers for its endpoints.
  "! /CLR/EINV_API rows with FUNCTIONALITY = 'API_PARAMETER' already
  "! cover the configurable case; this hook is for anything that has to
  "! be computed (a signature, a per-request nonce).
  METHODS enrich_headers
    IMPORTING iv_bukrs      TYPE zde_einv_bukrs
              iv_function   TYPE zde_einv_func
    CHANGING  ct_header     TYPE if_web_http_request=>name_value_pairs.

ENDINTERFACE.
