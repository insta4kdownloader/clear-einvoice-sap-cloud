"! <p class="shorttext synchronized">e-Invoice: configuration access</p>
"!
"! Owns every read of the ten ZTEINV_* configuration tables and
"! reproduces the two behaviours the HANA code relied on:
"!
"!  1. THE COMPANY-CODE / COUNTRY FALLBACK.
"!     /CLR/ZCL_EINV_FACTORY read each customizing table twice - first
"!     restricted to the company code, then, if nothing was found, with
"!     BUKRS = space for the country only:
"!
"!       SELECT ... WHERE land1 = @land1 AND bukrs = @lv_comp.
"!       IF sy-subrc <> 0.
"!         SELECT ... WHERE land1 = @land1 AND bukrs = @space.
"!       ENDIF.
"!
"!     get_scoped( ) below is that pattern, once, for all tables.
"!
"!  2. IN-SESSION BUFFERING.
"!     The factory loaded everything into public attributes of the
"!     e-invoice instance (GT_CONFIG, GT_INVMAP, GT_EINV_STATUS,
"!     GT_EINV_DOCTYP, GT_EINV_API) so the report could read them
"!     without hitting the database again. Same effect here, but
"!     encapsulated and per-company-code.
"!
"! Deliberately NOT carried over:
"!   /CLR/EINV_FCAT, /CLR/EINV_APFCAT  - ALV field catalogues
"!   /CLR/EINV_SELSCR                  - selection-screen show/hide
"!   /CLR/EINV_ALVFUN, /CLR/EINV_APALV - GUI function-code enablement
"!   the ICON / COLOUR columns of /CLR/EINV_STATUS
"! all of which describe a SAP GUI screen and are replaced by CDS
"! annotations, Fiori adaptation and RAP feature control.
CLASS zcl_einv_config DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.

    TYPES: ty_t_const   TYPE STANDARD TABLE OF zteinv_const WITH EMPTY KEY,
           ty_t_api     TYPE STANDARD TABLE OF zteinv_api WITH EMPTY KEY,
           ty_t_invmap  TYPE STANDARD TABLE OF zteinv_invmap WITH EMPTY KEY,
           ty_t_doctyp  TYPE STANDARD TABLE OF zteinv_doctyp WITH EMPTY KEY,
           ty_t_status  TYPE STANDARD TABLE OF zteinv_status WITH EMPTY KEY.

    CONSTANTS:
      "! FUNCTIONALITY values of ZTEINV_API, unchanged from
      "! /CLR/EINV_API so existing customizing can be copied over.
      BEGIN OF gc_function,
        status        TYPE zde_einv_func VALUE 'EINV_STATUS',
        print         TYPE zde_einv_func VALUE 'EINV_PRINT',
        seller_action TYPE zde_einv_func VALUE 'EINV_SELLER_ACTION',
        cancel        TYPE zde_einv_func VALUE 'EINV_CANCEL',
        ap_status     TYPE zde_einv_func VALUE 'EINV_AP_STATUS',
        get_doc_list  TYPE zde_einv_func VALUE 'GET_DOC_LIST',
        get_doc_deta  TYPE zde_einv_func VALUE 'GET_DOC_DETAILS',
        parameter     TYPE zde_einv_func VALUE 'API_PARAMETER',
        ap_parameter  TYPE zde_einv_func VALUE 'API_AP_PARAMETER',
      END OF gc_function.

    CLASS-METHODS get_instance
      RETURNING VALUE(ro_result) TYPE REF TO zcl_einv_config.

    "! True when the company code has a ZTEINV_CNTRY row.
    "! Replaces the factory's first SELECT, which returned an unbound
    "! reference and made the report issue /CLR/ZME_EINV 005.
    METHODS is_company_registered
      IMPORTING iv_bukrs         TYPE zde_einv_bukrs
      RETURNING VALUE(rv_result) TYPE abap_boolean.

    METHODS get_country
      IMPORTING iv_bukrs          TYPE zde_einv_bukrs
      RETURNING VALUE(rv_country) TYPE zde_einv_land1.

    METHODS get_project_id
      IMPORTING iv_bukrs         TYPE zde_einv_bukrs
      RETURNING VALUE(rv_result) TYPE zde_einv_projectid.

    METHODS get_handler_class
      IMPORTING iv_bukrs         TYPE zde_einv_bukrs
      RETURNING VALUE(rv_result) TYPE zde_einv_handler.

    METHODS is_auto_generate_active
      IMPORTING iv_bukrs         TYPE zde_einv_bukrs
      RETURNING VALUE(rv_result) TYPE abap_boolean.

    METHODS get_constants
      IMPORTING iv_bukrs        TYPE zde_einv_bukrs
                iv_label        TYPE zde_einv_label
                iv_product      TYPE zde_einv_product DEFAULT 'EINV'
      RETURNING VALUE(rt_const) TYPE ty_t_const.

    "! Endpoint URL plus the extra header rows for one functionality.
    METHODS get_endpoint
      IMPORTING iv_bukrs      TYPE zde_einv_bukrs
                iv_function   TYPE zde_einv_func
      EXPORTING ev_url        TYPE zde_einv_url
                et_header     TYPE ty_t_api.

    METHODS get_invmap
      IMPORTING iv_bukrs         TYPE zde_einv_bukrs
      RETURNING VALUE(rt_result) TYPE ty_t_invmap.

    "! Transaction type for the status / print endpoints.
    "!
    "! Replaces the derivation in get_status:
    "!   SELECT ... FROM /clr/zt_einv AS inv
    "!     LEFT OUTER JOIN /clr/einv_doctyp AS dty
    "!       ON dty~doc_type_code = inv~doc_type
    "!   lv_trns_type = COND #( WHEN b2c IS NOT INITIAL
    "!                          THEN |{ transact_type }_B2C|
    "!                          ELSE transact_type ).
    METHODS get_transaction_type
      IMPORTING iv_bukrs         TYPE zde_einv_bukrs
                iv_doc_type      TYPE zde_einv_doct
                iv_b2c           TYPE zde_einv_flag OPTIONAL
      RETURNING VALUE(rv_result) TYPE string.

    "! Configured criticality for a status, or 0 when not maintained.
    METHODS get_criticality
      IMPORTING iv_bukrs         TYPE zde_einv_bukrs
                iv_status        TYPE zde_einv_status
      RETURNING VALUE(rv_result) TYPE zde_einv_crit.

    METHODS get_vat_number
      IMPORTING iv_bukrs         TYPE zde_einv_bukrs
      RETURNING VALUE(rv_result) TYPE zde_einv_vat.

    "! The Clear auth token.
    "!
    "! In the HANA package this was
    "!   SELECT SINGLE low FROM /clr/zt_elt_cnfg
    "!     WHERE label_type = 'AUTH' AND sequence = @seq AND sys_id = @sy-sysid
    "! i.e. a bearer token in plain text in a Z table, and the factory
    "! then exposed it as the PUBLIC attribute GV_AUTH.
    "!
    "! The token is still read from the ELT configuration table
    "! (ZTELT_CONFIG of ZZCLR_ELT) so that one place configures both
    "! packages, but it is returned by a method and never stored in a
    "! public attribute.
    "!
    "! MIGRATION NOTE: the strategic Public Cloud answer is a
    "! Communication Arrangement holding the credential, with
    "! cl_http_destination_provider=>create_by_comm_arrangement( ).
    "! ZCL_EINV_API_CLIENT is written so that switching to it means
    "! changing one method - see its create_client( ).
    METHODS get_auth_token
      IMPORTING iv_bukrs         TYPE zde_einv_bukrs
      RETURNING VALUE(rv_token)  TYPE string.

    METHODS get_hostname
      RETURNING VALUE(rv_result) TYPE string.

    METHODS invalidate.

  PROTECTED SECTION.
  PRIVATE SECTION.

    CLASS-DATA go_instance TYPE REF TO zcl_einv_config.

    TYPES: BEGIN OF ty_scope,
             bukrs     TYPE zde_einv_bukrs,
             cntry     TYPE zteinv_cntry,
             loaded    TYPE abap_boolean,
           END OF ty_scope.

    DATA mt_scope  TYPE SORTED TABLE OF ty_scope WITH UNIQUE KEY bukrs.
    DATA mt_const  TYPE ty_t_const.
    DATA mt_api    TYPE ty_t_api.
    DATA mt_invmap TYPE ty_t_invmap.
    DATA mt_doctyp TYPE ty_t_doctyp.
    DATA mt_status TYPE ty_t_status.
    DATA mv_const_loaded  TYPE abap_boolean.
    DATA mv_api_loaded    TYPE abap_boolean.
    DATA mv_invmap_loaded TYPE abap_boolean.
    DATA mv_doctyp_loaded TYPE abap_boolean.
    DATA mv_status_loaded TYPE abap_boolean.

    METHODS load_scope
      IMPORTING iv_bukrs         TYPE zde_einv_bukrs
      RETURNING VALUE(rs_result) TYPE ty_scope.

    METHODS load_all.

ENDCLASS.



CLASS zcl_einv_config IMPLEMENTATION.


  METHOD get_instance.
    IF go_instance IS NOT BOUND.
      go_instance = NEW zcl_einv_config( ).
    ENDIF.
    ro_result = go_instance.
  ENDMETHOD.


  METHOD invalidate.
    CLEAR: mt_scope, mt_const, mt_api, mt_invmap, mt_doctyp, mt_status,
           mv_const_loaded, mv_api_loaded, mv_invmap_loaded,
           mv_doctyp_loaded, mv_status_loaded.
  ENDMETHOD.


  METHOD load_scope.
    DATA(ls_cached) = VALUE #( mt_scope[ bukrs = iv_bukrs ] OPTIONAL ).
    IF ls_cached-loaded = abap_true.
      rs_result = ls_cached.
      RETURN.
    ENDIF.

    SELECT SINGLE * FROM zteinv_cntry
      WHERE bukrs = @iv_bukrs
      INTO @rs_result-cntry.

    rs_result-bukrs  = iv_bukrs.
    rs_result-loaded = abap_true.
    INSERT rs_result INTO TABLE mt_scope.
  ENDMETHOD.


  METHOD load_all.
    " One read per table per session, mirroring what the factory did
    " once per report start.
    IF mv_const_loaded = abap_false.
      SELECT * FROM zteinv_const INTO TABLE @mt_const.
      mv_const_loaded = abap_true.
    ENDIF.
    IF mv_api_loaded = abap_false.
      SELECT * FROM zteinv_api INTO TABLE @mt_api.
      mv_api_loaded = abap_true.
    ENDIF.
    IF mv_invmap_loaded = abap_false.
      SELECT * FROM zteinv_invmap WHERE einvoice = 'X' INTO TABLE @mt_invmap.
      mv_invmap_loaded = abap_true.
    ENDIF.
    IF mv_doctyp_loaded = abap_false.
      SELECT * FROM zteinv_doctyp INTO TABLE @mt_doctyp.
      mv_doctyp_loaded = abap_true.
    ENDIF.
    IF mv_status_loaded = abap_false.
      SELECT * FROM zteinv_status INTO TABLE @mt_status.
      mv_status_loaded = abap_true.
    ENDIF.
  ENDMETHOD.


  METHOD is_company_registered.
    rv_result = xsdbool( load_scope( iv_bukrs )-cntry-bukrs IS NOT INITIAL ).
  ENDMETHOD.


  METHOD get_country.
    rv_country = load_scope( iv_bukrs )-cntry-land1.
  ENDMETHOD.


  METHOD get_project_id.
    rv_result = load_scope( iv_bukrs )-cntry-projectid.
  ENDMETHOD.


  METHOD get_handler_class.
    rv_result = load_scope( iv_bukrs )-cntry-handler_class.
  ENDMETHOD.


  METHOD is_auto_generate_active.
    rv_result = xsdbool( load_scope( iv_bukrs )-cntry-auto_einv_generate = 'X' ).
  ENDMETHOD.


  METHOD get_constants.
    load_all( ).
    DATA(lv_country) = get_country( iv_bukrs ).

    " Company-code specific rows first ...
    rt_const = VALUE #( FOR ls IN mt_const
                        WHERE ( product = iv_product
                            AND zlabel  = iv_label
                            AND land1   = lv_country
                            AND bukrs   = iv_bukrs )
                        ( ls ) ).

    " ... and only if there are none, the country-wide rows.
    IF rt_const IS INITIAL.
      rt_const = VALUE #( FOR ls IN mt_const
                          WHERE ( product = iv_product
                              AND zlabel  = iv_label
                              AND land1   = lv_country
                              AND bukrs   = space )
                          ( ls ) ).
    ENDIF.
  ENDMETHOD.


  METHOD get_endpoint.
    CLEAR: ev_url, et_header.
    load_all( ).
    DATA(lv_country) = get_country( iv_bukrs ).

    DATA(lt_rows) = VALUE ty_t_api( FOR ls IN mt_api
                                    WHERE ( functionality = iv_function
                                        AND land1         = lv_country
                                        AND bukrs         = iv_bukrs )
                                    ( ls ) ).
    IF lt_rows IS INITIAL.
      lt_rows = VALUE ty_t_api( FOR ls IN mt_api
                                WHERE ( functionality = iv_function
                                    AND land1         = lv_country
                                    AND bukrs         = space )
                                ( ls ) ).
    ENDIF.

    SORT lt_rows BY sequence.
    IF lt_rows IS NOT INITIAL.
      ev_url = lt_rows[ 1 ]-url.
    ENDIF.

    " The header carrier rows: /CLR/EINV_API kept them under
    " FUNCTIONALITY = 'API_PARAMETER' and call_get_status looped over
    " them with set_header_field. Same convention.
    et_header = VALUE ty_t_api( FOR ls IN mt_api
                                WHERE ( functionality = gc_function-parameter
                                    AND land1         = lv_country
                                    AND bukrs         = iv_bukrs )
                                ( ls ) ).
    IF et_header IS INITIAL.
      " Same company-code-then-country fallback the URL lookup above uses.
      " Without it every API_PARAMETER row of the country was sent as a
      " header no matter which company code it was maintained for.
      et_header = VALUE ty_t_api( FOR ls IN mt_api
                                  WHERE ( functionality = gc_function-parameter
                                      AND land1         = lv_country
                                      AND bukrs         = space )
                                  ( ls ) ).
    ENDIF.
    SORT et_header BY sequence.
  ENDMETHOD.


  METHOD get_invmap.
    load_all( ).
    DATA(lv_country) = get_country( iv_bukrs ).
    rt_result = VALUE #( FOR ls IN mt_invmap
                         WHERE ( land1 = lv_country )
                         ( ls ) ).
  ENDMETHOD.


  METHOD get_transaction_type.
    load_all( ).
    DATA(lv_country) = get_country( iv_bukrs ).

    DATA(ls_doctyp) = VALUE #( mt_doctyp[ land1         = lv_country
                                          bukrs         = iv_bukrs
                                          doc_type_code = iv_doc_type ] OPTIONAL ).
    IF ls_doctyp-doc_type_code IS INITIAL.
      ls_doctyp = VALUE #( mt_doctyp[ land1         = lv_country
                                      bukrs         = space
                                      doc_type_code = iv_doc_type ] OPTIONAL ).
    ENDIF.

    rv_result = ls_doctyp-transact_type.

    IF iv_b2c = 'X' AND rv_result IS NOT INITIAL.
      rv_result = |{ rv_result }_B2C|.
    ENDIF.
  ENDMETHOD.


  METHOD get_criticality.
    load_all( ).
    DATA(lv_country) = get_country( iv_bukrs ).

    DATA(ls_status) = VALUE #( mt_status[ land1  = lv_country
                                          bukrs  = iv_bukrs
                                          status = iv_status ] OPTIONAL ).
    IF ls_status-status IS INITIAL.
      ls_status = VALUE #( mt_status[ land1  = lv_country
                                      bukrs  = space
                                      status = iv_status ] OPTIONAL ).
    ENDIF.

    rv_result = ls_status-criticality.
  ENDMETHOD.


  METHOD get_vat_number.
    DATA(lv_country) = get_country( iv_bukrs ).

    SELECT SINGLE vat FROM zteinv_vat
      WHERE land1 = @lv_country AND bukrs = @iv_bukrs
      INTO @rv_result.

    IF rv_result IS INITIAL.
      SELECT SINGLE vat FROM zteinv_vat
        WHERE land1 = @lv_country AND bukrs = @space
        INTO @rv_result.
    ENDIF.
  ENDMETHOD.


  METHOD get_auth_token.
    DATA(ls_scope) = load_scope( iv_bukrs ).

    " ZTELT_CONFIG is the C1-released configuration table of package
    " ZZCLR_ELT; LABELTYPE = 'AUTH' is the same label the HANA code
    " used on /CLR/ZT_ELT_CNFG.
    SELECT SINGLE low FROM ztelt_config
      WHERE labeltype = 'AUTH'
        AND projectid = @ls_scope-cntry-projectid
        AND sysid     = @ls_scope-cntry-sysid
      INTO @DATA(lv_low).

    rv_token = lv_low.
  ENDMETHOD.


  METHOD get_hostname.
    SELECT SINGLE low FROM ztelt_config
      WHERE labeltype = 'HOSTNAME'
      INTO @DATA(lv_low).
    rv_result = lv_low.
  ENDMETHOD.


ENDCLASS.
