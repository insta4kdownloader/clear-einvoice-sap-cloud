"! <p class="shorttext synchronized">e-Document: action validation and send</p>
"!
"! One class replacing two near-identical copies of the same logic:
"!
"!   AP inbound   /CLR/EINV_AP_COCKPIT_COMMON
"!                  FORM send_action_data + FORM call_action_api
"!   Self-billed  /CLR/ELT_EINVOICE_SELF_SUB
"!                  FORM self_send_action_data + FORM self_call_action_api
"!
"! The two HANA versions differ in exactly three things, which are the
"! constructor argument and what it resolves to:
"!
"!   | | AP | Self-billed |
"!   |---|---|---|
"!   | EINV_TYPE literal | 'PURCHASE' | 'SELF_BILLED' |
"!   | /CLR/EINV_API functionality | EINV_AP_STATUS | EINV_SELF_STATUS |
"!   | taxpayerIdentifier sent | SELLER_VAT | BUYER_VAT (own VAT) |
"!
"! Everything else was copy-paste, including the bugs. Two are fixed here:
"!
"!  * The AP payload template was malformed JSON - a stray '{' before
"!    "documentTypeCode" and unbalanced braces:
"!
"!      '{ "documentNumber": "&DOCID&","documentDate": "&DOCDT&", ' &&
"!      '"taxpayerIdentifier": "&TAXPAYER&",' &&
"!      '{ "documentTypeCode": "&DOCTYP&", "actionType": "&ACTIONTYPE&",' &&
"!      '  "actionData": { "reasonCodes": ["&REASONCODE&"],' &&
"!      '  "comment": "&COMMENT&" } }'
"!
"!    The self-billed copy fixed the stray brace but kept the
"!    REPLACE-based templating, which escapes only the comment. Here the
"!    payload is a typed structure and the serializer does the quoting.
"!
"!  * The self-billed version silently falls back to the AP endpoint when
"!    no EINV_SELF_STATUS row exists. That fallback is kept - removing it
"!    would break existing configuration - but it is now reported in the
"!    result message instead of being invisible.
CLASS zcl_einv_edoc_action DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    CONSTANTS:
      BEGIN OF gc_type,
        purchase    TYPE zde_einv_type VALUE 'PURCHASE',
        self_billed TYPE zde_einv_type VALUE 'SELF_BILLED',
      END OF gc_type.

    TYPES: BEGIN OF ty_document,
             documentid     TYPE zde_elt_docid,
             documentnumber TYPE zde_elt_docno,
             issue_dt       TYPE d,
             inv_typ_code   TYPE zde_elt_inv_type_code,
             seller_vat     TYPE zde_elt_vat_id,
             buyer_vat      TYPE zde_elt_vat_id,
           END OF ty_document.

    TYPES: BEGIN OF ty_result,
             success TYPE abap_boolean,
             status  TYPE zde_elt_status,
             message TYPE zde_elt_api_message,
             http    TYPE i,
           END OF ty_result.

    METHODS constructor
      IMPORTING iv_einv_type TYPE zde_einv_type.

    "! Empty string when the action is valid, otherwise the reason.
    "!
    "! Ported from the validation block of send_action_data:
    "!   - ACTION_TYPE mandatory
    "!   - if any reason code is configured for that action type, then
    "!     REASON_CODE is mandatory and must be one of them
    METHODS validate_action
      IMPORTING iv_action_type   TYPE zde_einv_action
                iv_reason_code   TYPE zde_einv_reason
      RETURNING VALUE(rv_reason) TYPE string.

    METHODS send
      IMPORTING is_document      TYPE ty_document
                iv_action_type   TYPE zde_einv_action
                iv_reason_code   TYPE zde_einv_reason OPTIONAL
                iv_comment       TYPE zde_elt_comment OPTIONAL
      RETURNING VALUE(rs_result) TYPE ty_result.

  PROTECTED SECTION.
  PRIVATE SECTION.

    DATA mv_einv_type TYPE zde_einv_type.
    DATA mv_function  TYPE zde_einv_func.

    "! Company code whose configuration drives the endpoint. The HANA
    "! cockpits took it from ABAP memory ('/CLR/EINV_COCKPIT'); here it is
    "! resolved from the document's own VAT registration, which is the only
    "! SAP-side anchor these tables have - they carry no BUKRS column.
    METHODS resolve_company
      IMPORTING is_document     TYPE ty_document
      RETURNING VALUE(rv_bukrs) TYPE zde_einv_bukrs.

ENDCLASS.



CLASS zcl_einv_edoc_action IMPLEMENTATION.


  METHOD constructor.
    mv_einv_type = iv_einv_type.

    " /CLR/ELT_EINVOICE_SELF_DD declares gc_self_api_status = 'EINV_SELF_STATUS'
    " and falls back to 'EINV_AP_STATUS' when no such row exists.
    mv_function = COND #( WHEN iv_einv_type = gc_type-self_billed
                          THEN 'EINV_SELF_STATUS'
                          ELSE zcl_einv_config=>gc_function-ap_status ).
  ENDMETHOD.


  METHOD validate_action.

    IF iv_action_type IS INITIAL.
      rv_reason = 'Enter an action type'.
      RETURN.
    ENDIF.

    " The action type must exist for this e-invoice type. The HANA code
    " only populated the dropdown from this table and never re-checked,
    " so a value pasted into the cell was accepted unvalidated.
    SELECT SINGLE @abap_true FROM zteinv_action
      WHERE einv_type   = @mv_einv_type
        AND action_type = @iv_action_type
      INTO @DATA(lv_exists).

    IF lv_exists <> abap_true.
      rv_reason = |Action type { iv_action_type } is not configured for { mv_einv_type }|.
      RETURN.
    ENDIF.

    SELECT reason_code FROM zteinv_reason
      WHERE action_type = @iv_action_type
      INTO TABLE @DATA(lt_reason).

    IF lt_reason IS INITIAL.
      " No reason codes configured for this action - nothing more to check.
      RETURN.
    ENDIF.

    IF iv_reason_code IS INITIAL.
      rv_reason = |Enter a reason code for action { iv_action_type }|.
      RETURN.
    ENDIF.

    IF NOT line_exists( lt_reason[ table_line = iv_reason_code ] ).
      rv_reason = |Reason code { iv_reason_code } is not valid for action { iv_action_type }|.
    ENDIF.

  ENDMETHOD.


  METHOD resolve_company.
    " Self-billed: we are the buyer, so our own VAT is BUYER_VAT.
    " AP inbound: we are the buyer too - the AP cockpit filtered
    " BUYER_VAT on our own registrations and SELLER_VAT on the selection.
    DATA(lv_own_vat) = CONV zde_einv_vat( is_document-buyer_vat ).

    SELECT SINGLE bukrs FROM zteinv_cntry
      WHERE vat = @lv_own_vat
      INTO @rv_bukrs.

    IF rv_bukrs IS NOT INITIAL.
      RETURN.
    ENDIF.

    " Fall back to the older /CLR/EINV_VAT equivalent. The 2026-09-25 drop
    " added VAT to /CLR/EINV_CNTRY and repointed the AP cockpit at it, but
    " left the self-billed include reading /CLR/EINV_VAT - so both tables
    " are live. Reading both is what keeps either configuration working.
    SELECT SINGLE bukrs FROM zteinv_vat
      WHERE vat = @lv_own_vat
      INTO @rv_bukrs.
  ENDMETHOD.


  METHOD send.

    DATA(lv_bukrs) = resolve_company( is_document ).

    IF lv_bukrs IS INITIAL.
      rs_result-success = abap_false.
      rs_result-status  = 'ERROR'.
      rs_result-message = |No company code found for VAT { is_document-buyer_vat } |
                       && |in ZTEINV_CNTRY or ZTEINV_VAT|.
      RETURN.
    ENDIF.

    " Typed payload. Field names are the camelCase the platform expects and
    " are produced by the serializer, not by REPLACE on a template string.
    DATA ls_request TYPE zstr_einv_act_req.
    ls_request-documentnumber     = is_document-documentnumber.
    ls_request-documentdate       = zcl_einv_util=>format_date_iso( is_document-issue_dt ).
    ls_request-documenttypecode   = is_document-inv_typ_code.
    ls_request-actiontype         = iv_action_type.
    ls_request-comment            = iv_comment.

    " The one genuine functional difference between the two variants.
    ls_request-taxpayeridentifier = COND #(
        WHEN mv_einv_type = gc_type-self_billed
        THEN is_document-buyer_vat        " self-billed: our own VAT
        ELSE is_document-seller_vat ).    " AP inbound: the supplier's VAT

    IF iv_reason_code IS NOT INITIAL.
      ls_request-actiondata-reasoncodes = VALUE #( ( iv_reason_code ) ).
    ENDIF.

    DATA(lo_api) = NEW zcl_einv_api_client( ).

    DATA(ls_call) = lo_api->post_edocument_action(
                      iv_bukrs    = lv_bukrs
                      iv_function = mv_function
                      is_request  = ls_request ).

    rs_result-http    = ls_call-http.
    rs_result-success = ls_call-success.
    rs_result-message = ls_call-message.

    " send_action_data set the row status from the response and counted
    " sent vs failed; the status literal itself came from the platform.
    rs_result-status = COND #( WHEN ls_call-success = abap_true
                               THEN COND #( WHEN ls_call-status IS NOT INITIAL
                                            THEN ls_call-status
                                            ELSE 'SENT' )
                               ELSE 'ERROR' ).

  ENDMETHOD.


ENDCLASS.
