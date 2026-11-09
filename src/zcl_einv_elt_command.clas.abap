"! <p class="shorttext synchronized">e-Invoice: ELT command request</p>
"!
"! Replaces /CLR/ZCL_ELT~get_command_einvoice, which the conversion of
"! the ELT package to ABAP Cloud did not carry over. See section 52 of
"! CONVERSION_DESIGN.md: the HANA /CLR/ZCL_ELT has 38 methods, the
"! converted ZCL_ELT has 27, and the eleven missing ones are the whole
"! e-invoice chain.
"!
"! WHY THIS CANNOT BE THE GENERIC get_command( )
"!
"! The first conversion called ZCL_ELT~get_command and recorded the
"! substitution as deliberate. It is not equivalent, in three ways that
"! the HANA source makes explicit:
"!
"!   1. A DIFFERENT ENDPOINT. get_command_einvoice reads the config row
"!      labelled GET_COMMAND_EINV; the generic one reads GET_COMMAND.
"!   2. A DOCUMENT-SPECIFIC REQUEST. It POSTs the document in the body.
"!      The generic get_command takes no importing parameters at all - it
"!      is a poll for whatever command the platform has queued, and has
"!      no way to know which document is being submitted.
"!   3. The response is the command FOR THAT DOCUMENT, so its command_id
"!      is the one the ingestion step and the later status refresh must
"!      quote.
"!
"! WHAT IS NOT COPIED
"!
"! The HANA method is 241 lines, of which about 200 are CL_HTTP_CLIENT
"! construction, proxy handling and error branches. None of that is
"! legal in ABAP Cloud and none of it is needed: CL_WEB_HTTP_CLIENT_MANAGER
"! covers it, exactly as ZCL_EINV_API_CLIENT already does for the Clear
"! platform APIs. What is copied verbatim is the part that matters - the
"! config key, the payload template, and the error texts, so a support
"! call about this message finds the same words in both systems.
"!
"! The constants for the header names and the config labels are taken
"! from ZCL_ELT rather than repeated here, so a change in the ELT package
"! reaches this class.
CLASS zcl_einv_elt_command DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    CONSTANTS:
      "! Config label of the e-invoice command endpoint. The generic
      "! engine's key is GET_COMMAND; this one is a different URL on the
      "! platform and has to be maintained separately in ZTELT_CONFIG.
      "!
      "! THIS ROW IS A PATH and gets HOSTNAME in front of it - see
      "! get_command( ) below. PRESIGN_URL_EINV is the other way round: an
      "! absolute URL used as-is. The asymmetry is in the HANA source
      "! (get_command_einvoice concatenates, ingest_files_einvoice does
      "! not) and is not a bug in either place.
      gc_cfg_get_command TYPE string VALUE 'GET_COMMAND_EINV',
      "! Config label of the e-invoice upload target, read by
      "! ZCL_EINV_ELT_INGEST. The e-invoice path does NOT call
      "! generate_pre_sign: it posts straight to this endpoint, where the
      "! generic path asks the platform's GENERATE_PRESIGN API for a
      "! one-time URL first. Despite the name nothing here is presigned -
      "! the label matches the HANA config row and is kept for that
      "! reason alone.
      gc_cfg_presign     TYPE string VALUE 'PRESIGN_URL_EINV'.

    TYPES:
      BEGIN OF ty_result,
        http_code TYPE i,
        reason    TYPE string,
        command   TYPE zstr_elt_command,
        error     TYPE zde_einv_errmsg,
      END OF ty_result.

    "! Asks the platform for the extraction command for ONE document.
    "!
    "! @parameter iv_bukrs | Company code
    "! @parameter iv_belnr | Accounting document
    "! @parameter iv_gjahr | Fiscal year
    "! @parameter iv_vbeln | Billing document, blank for an FI-only document
    METHODS get_command
      IMPORTING iv_bukrs         TYPE zde_einv_bukrs
                iv_belnr         TYPE zde_einv_accdoc
                iv_gjahr         TYPE zde_einv_gjahr
                iv_vbeln         TYPE zde_einv_billdoc OPTIONAL
      RETURNING VALUE(rs_result) TYPE ty_result.

    "! The configured e-invoice upload target, or empty when the row is
    "! not maintained. ZCL_EINV_ELT_INGEST reads the same row through its
    "! own config lookup; this stays as the single public answer to
    "! "is the e-invoice endpoint configured at all", which is the first
    "! thing to check when a submission goes nowhere.
    METHODS get_ingest_url
      RETURNING VALUE(rv_url) TYPE string.

    "! @parameter io_elt | The ELT engine instance the caller already
    "!   built. Its constructor loads ZTELT_CONFIG into GT_ERP_CONFIG, so
    "!   this class reads the configuration from there rather than issuing
    "!   its own SELECT. Two reasons: the two must never disagree about
    "!   which rows are current, and the selection in ZCL_ELT filters on
    "!   SY-SYSID, which is not released for ABAP Cloud - inherited code
    "!   may use it, new code in this package may not.
    METHODS constructor
      IMPORTING io_elt TYPE REF TO zcl_elt.

  PRIVATE SECTION.

    " The payload of /CLR/ZCL_ELT~get_command_einvoice, verbatim. The
    " platform matches on all four values; salesDoc is empty for a
    " document that has no billing document, which is the NO_ACC case.
    "
    " Three constants rather than one: a CONSTANTS ... VALUE clause takes
    " a literal, not an expression, so the `&&` that joins the HANA
    " source's three lines is not allowed here. They are concatenated at
    " the point of use instead, which keeps the three lines identical to
    " the original.
    CONSTANTS:
      gc_payload_1 TYPE string VALUE
        '{ "action":"EINVOICE_GLOBAL", "commandType":"DATA_EXTRACTION",' ##NO_TEXT,
      gc_payload_2 TYPE string VALUE
        '  "commandParameter": { "salesDoc": "&SDOC&", "accountingDoc": "&ADOC&", ' ##NO_TEXT,
      gc_payload_3 TYPE string VALUE
        '  "fiscalYear": "&FYEAR&", "companyCode":"&CCODE&" } }' ##NO_TEXT.

    DATA mo_elt TYPE REF TO zcl_elt.

    " IV_LABEL is a STRING, not ZTELT_CONFIG-LABELTYPE. The labels come
    " from ZCL_ELT's own constants, which are typed STRING, and ABAP
    " Cloud will not pass a STRING actual into a C(30) formal. Typing the
    " parameter after the caller rather than after the table is the
    " smaller lie: the conversion happens once, explicitly, in the table
    " expression below.
    METHODS config_value
      IMPORTING iv_label        TYPE string
      RETURNING VALUE(rv_value) TYPE string.

ENDCLASS.



CLASS zcl_einv_elt_command IMPLEMENTATION.

  METHOD constructor.
    mo_elt = io_elt.
  ENDMETHOD.


  METHOD config_value.
    " GT_ERP_CONFIG is filled by the ZCL_ELT constructor, which calls
    " get_erp_config( ). Reading it here rather than selecting again
    " keeps one source of truth and keeps SY-SYSID - not released for
    " ABAP Cloud - inside the inherited class where it already lives.
    rv_value = VALUE #( mo_elt->gt_erp_config[
                          labeltype = CONV ztelt_config-labeltype( iv_label ) ]-low OPTIONAL ).
  ENDMETHOD.


  METHOD get_ingest_url.
    rv_url = config_value( gc_cfg_presign ).
  ENDMETHOD.


  METHOD get_command.

    DATA(lv_path) = config_value( gc_cfg_get_command ).
    IF lv_path IS INITIAL.
      " Verbatim from the HANA method, so the same words appear in a
      " support call from either system.
      rs_result-error = 'API to get command not maintained in custom table' ##NO_TEXT.
      RETURN.
    ENDIF.

    DATA(lv_hostname) = config_value( zcl_elt=>gc_hostname ).
    IF lv_hostname IS INITIAL.
      rs_result-error = 'HOSTNAME not maintained in custom table' ##NO_TEXT.
      RETURN.
    ENDIF.

    DATA(lv_payload) = gc_payload_1 && gc_payload_2 && gc_payload_3.
    REPLACE ALL OCCURRENCES OF '&SDOC&'  IN lv_payload WITH CONV string( iv_vbeln ).
    REPLACE ALL OCCURRENCES OF '&ADOC&'  IN lv_payload WITH CONV string( iv_belnr ).
    REPLACE ALL OCCURRENCES OF '&FYEAR&' IN lv_payload WITH CONV string( iv_gjahr ).
    REPLACE ALL OCCURRENCES OF '&CCODE&' IN lv_payload WITH CONV string( iv_bukrs ).

    DATA lo_client TYPE REF TO if_web_http_client.

    TRY.
        lo_client = cl_web_http_client_manager=>create_by_http_destination(
                      i_destination = cl_http_destination_provider=>create_by_url(
                                        |{ lv_hostname }{ lv_path }| ) ).
      CATCH cx_web_http_client_error cx_http_dest_provider_error INTO DATA(lx_dest).
        " 'Error in create URL(Get Command)' in the HANA method.
        rs_result-error = |Error in create URL(Get Command) { lx_dest->get_text( ) }| ##NO_TEXT.
        RETURN.
    ENDTRY.

    TRY.
        DATA(lo_request) = lo_client->get_http_request( ).

        lo_request->set_header_fields( VALUE #(
          ( name = zcl_elt=>gc_auth_token      value = config_value( zcl_elt=>gc_auth ) )
          ( name = zcl_elt=>gc_erp_instance_id value = config_value( zcl_elt=>gc_erp_id ) )
          ( name = 'Content-Type'              value = zcl_elt=>gc_appl_json ) ) ).

        lo_request->set_text( lv_payload ).

        DATA(lo_response) = lo_client->execute( if_web_http_client=>post ).

        DATA(ls_status)     = lo_response->get_status( ).
        rs_result-http_code = ls_status-code.
        rs_result-reason    = ls_status-reason.

        IF ls_status-code = 200.
          DATA(lv_json) = lo_response->get_text( ).
          IF lv_json IS INITIAL.
            rs_result-error = |Empty config file in response (Get Command) { ls_status-code } { ls_status-reason }| ##NO_TEXT.
          ELSE.
            /ui2/cl_json=>deserialize( EXPORTING json        = lv_json
                                                 pretty_name = abap_true
                                       CHANGING  data        = rs_result-command ).
          ENDIF.
        ELSE.
          rs_result-error = |GET COMMAND RECEIVE API { ls_status-code } { ls_status-reason }| ##NO_TEXT.
        ENDIF.

        lo_client->close( ).

      CATCH cx_web_http_client_error cx_web_message_error INTO DATA(lx_http).
        " The HANA method distinguished a send failure from a receive
        " failure because CL_HTTP_CLIENT has two calls; CL_WEB_HTTP_CLIENT
        " has one, so there is one message.
        rs_result-error = |Send API failed (Get Command) { lx_http->get_text( ) }| ##NO_TEXT.
        TRY.
            lo_client->close( ).
          CATCH cx_web_http_client_error.
        ENDTRY.
    ENDTRY.

  ENDMETHOD.

ENDCLASS.
