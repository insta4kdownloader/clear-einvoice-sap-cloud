"! <p class="shorttext synchronized">e-Invoice: Clear platform HTTP client</p>
"!
"! Replaces the four hand-written HTTP blocks of the HANA package:
"!   /CLR/ZCL_EINV_BASE~call_get_status
"!   /CLR/ZCL_EINV_BASE~call_print_pdf
"!   /CLR/ZCL_EINV_BASE~call_seller_action
"!   /CLR/AP_EINVOICE~call_api  (+ FORM call_action_api in the AP cockpit)
"!
"! Every one of them repeated the same ~40 lines:
"!
"!   cl_http_client=>create_by_url( url = lv_url IMPORTING client = ... ).
"!   CREATE OBJECT lr_rest_client EXPORTING io_http_client = ...
"!   lr_http_client->request->set_version( co_protocol_version_1_0 ).
"!   ...->set_header_field( name = '~request_method' value = 'GET' ).
"!   ...->set_header_field( name = 'x-cleartax-auth-token' value = gv_auth ).
"!   lr_http_client->send( ). lr_http_client->receive( ).
"!
"! None of cl_http_client, cl_rest_http_client, if_http_client,
"! if_http_request=>co_protocol_version_1_0 or the '~request_method'
"! pseudo-header is released for ABAP Cloud. The replacement is
"! cl_web_http_client_manager + cl_http_destination_provider, which is
"! exactly what the already-converted ZCL_ELT of ZZCLR_ELT uses - see
"! its generate_pre_sign( ) - so both packages call out the same way.
"!
"! One defect of the original is fixed here rather than carried over:
"!
"!   * CORRECTED, section 83. This paragraph used to say the auth header
"!     name was "inconsistent" and that ZCL_ELT's 'x-clear-auth-token'
"!     was therefore used everywhere. That was wrong, and it sent the
"!     wrong header to every endpoint this class calls.
"!
"!     /CLR/ZCL_EINV_BASE and /CLR/AP_EINVOICE both send
"!     'x-cleartax-auth-token' - five call sites, all agreeing. ZCL_ELT
"!     sends 'x-clear-auth-token' because it talks to a DIFFERENT
"!     service: the ELT platform at /one-integration/..., not the
"!     e-invoice API at api.mea.cleartax.com/einvoice/....
"!
"!     The one genuine outlier was FORM call_action_api of the AP
"!     cockpit - a single site against five. Unifying on the outlier's
"!     value, because a class in another package happened to share it,
"!     is what the correction undoes.
"!
"!   * Request bodies were built by string concatenation. The template
"!     in FORM call_action_api was actually malformed JSON (a stray '{'
"!     before "documentTypeCode") and only the comment field was
"!     escaped. Bodies are now serialized from typed structures.
CLASS zcl_einv_api_client DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    CONSTANTS:
      "! Header names. Aligned with ZCL_ELT of package ZZCLR_ELT.
      BEGIN OF gc_header,
        "! 'x-cleartax-auth-token', NOT 'x-clear-auth-token'.
        "!
        "! These are two different services. The e-invoice API - the one
        "! this class calls, api.<region>.cleartax.com/einvoice/... - wants
        "! x-cleartax-auth-token. The ELT platform that ZCL_ELT calls,
        "! /one-integration/..., wants x-clear-auth-token. Section 83.
        auth_token   TYPE string VALUE 'x-cleartax-auth-token',
        erp_instance TYPE string VALUE 'x-erp-instance-id',
        content_type TYPE string VALUE 'Content-Type',
        vat          TYPE string VALUE 'x-clear-vat',
        branch       TYPE string VALUE 'x-clear-branch',
        request_id   TYPE string VALUE 'x-request-id',
        country_code TYPE string VALUE 'x-clear-country-code',
      END OF gc_header.

    CONSTANTS:
      gc_appl_json TYPE string VALUE 'application/json'.

    CONSTANTS:
      "! Action types offered by dynpro 0200 of
      "! /CLR/ELT_EINVOICE_COCKPIT_SO01 (VRM_SET_VALUES in status_0200).
      BEGIN OF gc_action,
        complete        TYPE zde_einv_action VALUE 'COMPLETE',
        confirm_payment TYPE zde_einv_action VALUE 'CONFIRM_PAYMENT',
      END OF gc_action.

    " One StatusReasons[] entry of a government reporting detail.
    TYPES: BEGIN OF ty_status_reason,
             code     TYPE zde_einv_rescode,
             messages TYPE string_table,
           END OF ty_status_reason,
           ty_status_reason_tt TYPE STANDARD TABLE OF ty_status_reason
                               WITH DEFAULT KEY.

    " One GovtReportingDetails[] entry of the status response.
    "
    " Deserialized in a SECOND pass, into this type rather than into
    " ZSTR_EINV_STATUS_RES. /CLR/ZCL_EINV_BASE does the same and says why:
    " the DDIC status structure is shared with other flows, so the
    " government block must not be bolted onto it. Here the reason is
    " stronger still - ZSTR_EINV_STATUS_RES is a DDIC structure and
    " cannot hold a nested table of tables at all.
    TYPES: BEGIN OF ty_govt_detail,
             transaction_id TYPE zde_einv_ppf_trans,
             action         TYPE zde_einv_ppf_act,
             action_type    TYPE zde_einv_ppf_acttyp,
             status         TYPE zde_einv_status,
             received_at    TYPE string,
             status_reasons TYPE ty_status_reason_tt,
           END OF ty_govt_detail,
           ty_govt_detail_tt TYPE STANDARD TABLE OF ty_govt_detail
                             WITH DEFAULT KEY.

    " The envelope of the second pass. One member only - everything else
    " in the body is read by the first pass into ZSTR_EINV_STATUS_RES.
    TYPES: BEGIN OF ty_govt_response,
             govt_reporting_details TYPE ty_govt_detail_tt,
           END OF ty_govt_response.

    TYPES: BEGIN OF ty_status_result,
             success TYPE abap_boolean,
             status  TYPE zde_einv_status,
             message TYPE zde_einv_errmsg,
             doc_id  TYPE zde_einv_docid,
             qr_code TYPE string,
             errors  TYPE zstr_einv_errdtl_tt,
             "! GovtReportingDetails[] as the platform sent it, in array
             "! order. The caller flattens it; see section 81.
             govt    TYPE ty_govt_detail_tt,
             http    TYPE i,
           END OF ty_status_result.

    "! Splits an ISO 8601 instant - "2026-10-02T11:42:07.123Z" - into the
    "! three DDIC fields /CLR/ZT_EINV_PPF stores, plus a sortable key.
    "!
    "! The HANA helper is ISO_TS_SPLIT of /CLR/ZCL_EINV_BASE. Its contract
    "! matters and is kept exactly: an unparsable or empty input yields
    "! EV_KEY = SPACE, so in the "latest entry" comparison it can never
    "! win over a real timestamp. Lenient by design - the authority's
    "! string is not ours to validate, and a badly formed one must not
    "! cost us the rest of the history.
    CLASS-METHODS iso_ts_split
      IMPORTING iv_iso  TYPE string
      EXPORTING ev_date TYPE d
                ev_time TYPE t
                "! ZDE_INT3, not a bare TYPE n - which is NUMC length 1,
                "! and would keep the first digit of the milliseconds and
                "! silently drop the other two.
                ev_msec TYPE zde_int3
                ev_key  TYPE string.

    TYPES: BEGIN OF ty_pdf_result,
             success  TYPE abap_boolean,
             message  TYPE string,
             filename TYPE string,
             content  TYPE xstring,
             http     TYPE i,
           END OF ty_pdf_result.

    TYPES: BEGIN OF ty_action_result,
             success TYPE abap_boolean,
             status  TYPE zde_einv_status,
             message TYPE zde_einv_errmsg,
             errors  TYPE zstr_einv_errdtl_tt,
             http    TYPE i,
           END OF ty_action_result.

    "! HTTP GET on the EINV_STATUS endpoint.
    "! Replaces call_get_status. The URL placeholders are the same:
    "!   &1 -> platform document id, &2 -> transaction type.
    METHODS get_status
      IMPORTING iv_bukrs         TYPE zde_einv_bukrs
                iv_doc_id        TYPE string
                iv_doc_type      TYPE string
      RETURNING VALUE(rs_result) TYPE ty_status_result.

    "! HTTP GET on the EINV_PRINT endpoint, returning the raw PDF.
    "! Replaces call_print_pdf minus the SCMS_DOWNLOAD / file_save_dialog
    "! front-end write, which has no Public Cloud equivalent.
    METHODS get_printout
      IMPORTING iv_bukrs         TYPE zde_einv_bukrs
                iv_doc_id        TYPE string
                iv_doc_type      TYPE string
      RETURNING VALUE(rs_result) TYPE ty_pdf_result.

    "! HTTP POST on the EINV_SELLER_ACTION endpoint.
    "! Replaces call_seller_action, including the CONFIRM_PAYMENT
    "! variant with collection date and VAT-rate split.
    METHODS post_seller_action
      IMPORTING iv_bukrs         TYPE zde_einv_bukrs
                iv_doc_id        TYPE string
                iv_action_type   TYPE zde_einv_action
                iv_coll_date     TYPE d OPTIONAL
                iv_comment       TYPE string OPTIONAL
                it_vat_split     TYPE zstr_einv_vatsplit_tt OPTIONAL
      RETURNING VALUE(rs_result) TYPE ty_action_result.

    TYPES: BEGIN OF ty_edoc_result,
             success TYPE abap_boolean,
             status  TYPE zde_elt_status,
             message TYPE zde_elt_api_message,
             doc_id  TYPE zde_elt_docid,
             http    TYPE i,
             "! The document list of GET_DOCUMENT_LIST. It is a component of
             "! the result rather than a separate EXPORTING parameter
             "! because ABAP allows RETURNING only on a method that has no
             "! EXPORTING and no CHANGING parameters at all.
             docs    TYPE zstr_einv_apdoc_tt,
           END OF ty_edoc_result.

    "! HTTP POST of an e-document action (AP inbound / self-billed).
    "!
    "! Replaces FORM call_action_api (AP cockpit) and FORM
    "! self_call_action_api (self-billing include). Both built the JSON by
    "! REPLACE-ing placeholders into a template string; the AP template was
    "! malformed and neither escaped anything but the comment.
    "!
    "! The endpoint is passed in rather than hard-coded, because the two
    "! callers use different /CLR/EINV_API functionality values
    "! (EINV_AP_STATUS vs EINV_SELF_STATUS) and the self-billed one falls
    "! back to the AP endpoint when its own row is missing.
    METHODS post_edocument_action
      IMPORTING iv_bukrs         TYPE zde_einv_bukrs
                iv_function      TYPE zde_einv_func
                is_request       TYPE zstr_einv_act_req
      RETURNING VALUE(rs_result) TYPE ty_edoc_result.

    "! HTTP GET of the document list for a date range.
    "!
    "! Replaces /CLR/AP_EINVOICE~get_documents, the only live API call on
    "! the inbound path. Query string, verbatim from that method:
    "!   ?start-date={ISO}&end-date={ISO}&einvoice-type={TYPE}
    METHODS get_document_list
      IMPORTING iv_bukrs         TYPE zde_einv_bukrs
                iv_einv_type     TYPE zde_einv_type
                iv_date_from     TYPE d
                iv_date_to       TYPE d
      RETURNING VALUE(rs_result) TYPE ty_edoc_result.

    "! HTTP POST on the EINV_CANCEL endpoint.
    "! /CLR/ZCL_EINV_BASE~call_cancel was empty, so this has no HANA
    "! counterpart to copy - the payload follows the same shape the
    "! seller action uses.
    METHODS post_cancel
      IMPORTING iv_bukrs         TYPE zde_einv_bukrs
                iv_doc_id        TYPE string
                iv_doc_type      TYPE string
                iv_reason_code   TYPE zde_einv_reason OPTIONAL
                iv_comment       TYPE string OPTIONAL
      RETURNING VALUE(rs_result) TYPE ty_action_result.

  PROTECTED SECTION.
  PRIVATE SECTION.

    TYPES: BEGIN OF ty_call,
             http_code TYPE i,
             reason    TYPE string,
             body_text TYPE string,
             body_raw  TYPE xstring,
             error     TYPE string,
           END OF ty_call.

    "! Builds the client for one call.
    "!
    "! >>> THE ONE PLACE TO CHANGE FOR COMMUNICATION ARRANGEMENTS <<<
    "! Today the destination is created from the configured URL, which
    "! keeps the ZTEINV_API / ZTELT_CONFIG customizing model of the HANA
    "! package and matches how ZCL_ELT of ZZCLR_ELT works. To move the
    "! endpoint and credential into a Communication Arrangement, replace
    "! the create_by_url( ) call with
    "!
    "!   cl_http_destination_provider=>create_by_comm_arrangement(
    "!     comm_scenario  = 'Z_EINV_CLEAR_OUT'
    "!     service_id     = 'Z_EINV_CLEAR_REST'
    "!     comm_system_id = ... )
    "!
    "! and drop the auth-token header below - the destination then
    "! carries the credential and nothing secret lives in a Z table.
    METHODS create_client
      IMPORTING iv_url           TYPE string
      RETURNING VALUE(ro_client) TYPE REF TO if_web_http_client
      RAISING   cx_web_http_client_error
                cx_http_dest_provider_error.

    METHODS build_url
      IMPORTING iv_bukrs         TYPE zde_einv_bukrs
                iv_function      TYPE zde_einv_func
                iv_placeholder_1 TYPE string OPTIONAL
                iv_placeholder_2 TYPE string OPTIONAL
      RETURNING VALUE(rv_url)    TYPE string.

    METHODS build_headers
      IMPORTING iv_bukrs         TYPE zde_einv_bukrs
                iv_function      TYPE zde_einv_func
                iv_with_body     TYPE abap_boolean DEFAULT abap_false
      RETURNING VALUE(rt_header) TYPE if_web_http_request=>name_value_pairs.

    METHODS execute
      IMPORTING iv_bukrs         TYPE zde_einv_bukrs
                iv_function      TYPE zde_einv_func
                iv_url           TYPE string
                iv_method        TYPE string
                iv_body          TYPE string OPTIONAL
      RETURNING VALUE(rs_result) TYPE ty_call.

    METHODS collect_error_text
      IMPORTING it_errors       TYPE zstr_einv_errdtl_tt
      RETURNING VALUE(rv_text)  TYPE zde_einv_errmsg.

ENDCLASS.



CLASS zcl_einv_api_client IMPLEMENTATION.


**********************************************************************
* Infrastructure
**********************************************************************

  METHOD create_client.
    ro_client = cl_web_http_client_manager=>create_by_http_destination(
                  i_destination = cl_http_destination_provider=>create_by_url( iv_url ) ).
  ENDMETHOD.


  METHOD build_url.
    " Same templating the HANA code used:
    "   REPLACE '&1' IN lv_url WITH iv_doc_id.
    "   REPLACE '&2' IN lv_url WITH iv_doc_type.
    zcl_einv_config=>get_instance( )->get_endpoint(
      EXPORTING iv_bukrs    = iv_bukrs
                iv_function = iv_function
      IMPORTING ev_url      = DATA(lv_path) ).

    IF lv_path IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lv_url) = CONV string( lv_path ).
    REPLACE ALL OCCURRENCES OF '&1' IN lv_url WITH iv_placeholder_1.
    REPLACE ALL OCCURRENCES OF '&2' IN lv_url WITH iv_placeholder_2.

    " The HANA package stored absolute URLs in /CLR/EINV_API-URL, while
    " ZZCLR_ELT stores a path and prefixes ZTELT_CONFIG-HOSTNAME.
    " Support both, so existing customizing can be reused unchanged.
    IF lv_url CS 'http'.
      rv_url = lv_url.
    ELSE.
      rv_url = |{ zcl_einv_config=>get_instance( )->get_hostname( ) }{ lv_url }|.
    ENDIF.
  ENDMETHOD.


  METHOD build_headers.
    DATA(lo_config) = zcl_einv_config=>get_instance( ).

    " No '~request_method' entry. That was an ICF pseudo-header of
    " cl_http_client; cl_web_http_client puts whatever set_header_fields( )
    " is given straight on the wire, so it would be sent as a literal
    " header. The verb is set by the argument of execute( ) instead.
    rt_header = VALUE #(
      ( name = gc_header-auth_token   value = lo_config->get_auth_token( iv_bukrs ) )
      ( name = gc_header-request_id   value = zcl_einv_util=>get_uuid( ) )
      ( name = gc_header-country_code value = CONV string( lo_config->get_country( iv_bukrs ) ) ) ).

    IF iv_with_body = abap_true.
      APPEND VALUE #( name = gc_header-content_type value = gc_appl_json ) TO rt_header.
    ENDIF.

    DATA(lv_vat) = lo_config->get_vat_number( iv_bukrs ).
    IF lv_vat IS NOT INITIAL.
      APPEND VALUE #( name = gc_header-vat value = CONV string( lv_vat ) ) TO rt_header.
    ENDIF.

    " The configurable extra headers: /CLR/EINV_API rows with
    " FUNCTIONALITY = 'API_PARAMETER', looped over with
    " set_header_field in every HANA HTTP block.
    lo_config->get_endpoint(
      EXPORTING iv_bukrs    = iv_bukrs
                iv_function = iv_function
      IMPORTING et_header   = DATA(lt_param) ).

    " A configured row WINS over a built-in header of the same name.
    "
    " 'x-clear-country-code' is both derived above, from the company
    " code's country, and a plausible API_PARAMETER row - the AE setup has
    " four such rows and the status call needs x-clear-country-code and
    " x-clear-trn. Appending both would put the name on the wire twice,
    " and which one the server honours is not something to leave to
    " chance. Explicit customizing is the more specific statement of
    " intent, so it replaces rather than duplicates. Section 83.
    LOOP AT lt_param INTO DATA(ls_param) WHERE param_name IS NOT INITIAL.
      DATA(lv_name) = CONV string( ls_param-param_name ).
      DELETE rt_header WHERE name = lv_name.
      APPEND VALUE #( name  = lv_name
                      value = CONV string( ls_param-param_value ) ) TO rt_header.
    ENDLOOP.

    " Country hook for anything that must be computed per request.
    zcl_einv_country_factory=>get_handler( iv_bukrs )->enrich_headers(
      EXPORTING iv_bukrs    = iv_bukrs
                iv_function = iv_function
      CHANGING  ct_header   = rt_header ).
  ENDMETHOD.


  METHOD execute.
    IF iv_url IS INITIAL.
      " /CLR/ZME_EINV had a dedicated message for this; the HANA code
      " often just left LV_URL empty and skipped the call silently.
      rs_result-error = |Endpoint { iv_function } is not maintained in ZTEINV_API|.
      RETURN.
    ENDIF.

    DATA lo_client TYPE REF TO if_web_http_client.

    TRY.
        lo_client = create_client( iv_url ).
      CATCH cx_web_http_client_error cx_http_dest_provider_error INTO DATA(lx_dest).
        rs_result-error = lx_dest->get_text( ).
        RETURN.
    ENDTRY.

    TRY.
        DATA(lo_request) = lo_client->get_http_request( ).
        lo_request->set_header_fields( build_headers( iv_bukrs     = iv_bukrs
                                                      iv_function  = iv_function
                                                      iv_with_body = xsdbool( iv_body IS NOT INITIAL ) ) ).

        IF iv_body IS NOT INITIAL.
          lo_request->set_text( iv_body ).
        ENDIF.

        DATA(lo_response) = lo_client->execute(
          COND #( WHEN iv_method = 'POST'
                  THEN if_web_http_client=>post
                  ELSE if_web_http_client=>get ) ).

        DATA(ls_status)      = lo_response->get_status( ).
        rs_result-http_code  = ls_status-code.
        rs_result-reason     = ls_status-reason.
        " Binary first, and text only when the payload is textual.
        " get_text( ) character-converts the body using the response
        " content type; on the application/pdf bytes that get_printout
        " receives that raises cx_web_message_error, and the CATCH below
        " would then discard the PDF and report a conversion error.
        rs_result-body_raw = lo_response->get_binary( ).

        DATA(lv_ctype) = to_lower( lo_response->get_header_field( 'content-type' ) ).
        IF lv_ctype IS INITIAL
           OR lv_ctype CS 'json' OR lv_ctype CS 'text' OR lv_ctype CS 'xml'.
          rs_result-body_text = lo_response->get_text( ).
        ENDIF.

        lo_client->close( ).

      CATCH cx_web_http_client_error cx_web_message_error INTO DATA(lx_http).
        rs_result-error = lx_http->get_text( ).
        TRY.
            lo_client->close( ).
          CATCH cx_web_http_client_error.
        ENDTRY.
    ENDTRY.
  ENDMETHOD.


  METHOD collect_error_text.
    " call_get_status did:
    "   LOOP AT ls_response-_error_details INTO ...
    "     CONCATENATE lv_error <error_message> INTO lv_error SEPARATED BY space.
    DATA lv_text TYPE string.
    LOOP AT it_errors INTO DATA(ls_err).
      IF ls_err-error_message IS INITIAL.
        CONTINUE.
      ENDIF.
      lv_text = COND #( WHEN lv_text IS INITIAL
                        THEN ls_err-error_message
                        ELSE |{ lv_text }; { ls_err-error_message }| ).
    ENDLOOP.
    rv_text = lv_text.
  ENDMETHOD.


**********************************************************************
* Status
**********************************************************************

  METHOD get_status.
    DATA(lv_url) = build_url( iv_bukrs         = iv_bukrs
                              iv_function      = zcl_einv_config=>gc_function-status
                              iv_placeholder_1 = iv_doc_id
                              iv_placeholder_2 = iv_doc_type ).

    DATA(ls_call) = execute( iv_bukrs    = iv_bukrs
                             iv_function = zcl_einv_config=>gc_function-status
                             iv_url      = lv_url
                             iv_method   = 'GET' ).

    rs_result-http = ls_call-http_code.

    IF ls_call-error IS NOT INITIAL.
      rs_result-message = ls_call-error.
      RETURN.
    ENDIF.

    IF ls_call-body_text IS NOT INITIAL.
      DATA ls_response TYPE zstr_einv_status_res.
      /ui2/cl_json=>deserialize( EXPORTING json        = ls_call-body_text
                                           pretty_name = abap_true
                                 CHANGING  data        = ls_response ).

      rs_result-status  = ls_response-status.
      rs_result-doc_id  = ls_response-document_id.
      rs_result-qr_code = ls_response-qr_code.
      rs_result-errors  = ls_response-error_details.
      rs_result-message = collect_error_text( ls_response-error_details ).

      " SECOND PASS - the government reporting block.
      " /ui2/cl_json ignores JSON members the target type does not have,
      " so one body can be deserialized twice into two different shapes.
      " That is what /CLR/ZCL_EINV_BASE does, and it is the only option
      " here: GovtReportingDetails nests StatusReasons, which nests a
      " message array, and a DDIC structure cannot express that.
      DATA ls_govt TYPE ty_govt_response.
      /ui2/cl_json=>deserialize( EXPORTING json        = ls_call-body_text
                                           pretty_name = abap_true
                                 CHANGING  data        = ls_govt ).

      rs_result-govt = ls_govt-govt_reporting_details.
    ENDIF.

    IF ls_call-http_code = 200.
      rs_result-success = abap_true.
    ELSE.
      rs_result-success = abap_false.
      IF rs_result-message IS INITIAL.
        rs_result-message = |HTTP { ls_call-http_code } { ls_call-reason }|.
      ENDIF.
    ENDIF.
  ENDMETHOD.


**********************************************************************
* Printout
**********************************************************************

  METHOD get_printout.
    DATA(lv_url) = build_url( iv_bukrs         = iv_bukrs
                              iv_function      = zcl_einv_config=>gc_function-print
                              iv_placeholder_1 = iv_doc_id
                              iv_placeholder_2 = iv_doc_type ).

    DATA(ls_call) = execute( iv_bukrs    = iv_bukrs
                             iv_function = zcl_einv_config=>gc_function-print
                             iv_url      = lv_url
                             iv_method   = 'GET' ).

    rs_result-http = ls_call-http_code.

    IF ls_call-error IS NOT INITIAL.
      rs_result-message = ls_call-error.
      RETURN.
    ENDIF.

    " call_print_pdf inspected the body for the literal "ErrorMessage"
    " when the status was not 200, then deserialized
    " /CLR/EINV_STR_PRINT_RES. Same two-step, but keyed on the status
    " code first so a 200 with a body is never mistaken for an error.
    IF ls_call-http_code <> 200.
      rs_result-success = abap_false.
      IF ls_call-body_text CS 'rrorMessage' OR ls_call-body_text CS 'rror'.
        DATA ls_err TYPE zstr_einv_print_res.
        /ui2/cl_json=>deserialize( EXPORTING json        = ls_call-body_text
                                             pretty_name = abap_true
                                   CHANGING  data        = ls_err ).
        rs_result-message = collect_error_text( ls_err-error ).
      ENDIF.
      IF rs_result-message IS INITIAL.
        rs_result-message = |HTTP { ls_call-http_code } { ls_call-reason }|.
      ENDIF.
      RETURN.
    ENDIF.

    rs_result-success  = abap_true.
    rs_result-content  = ls_call-body_raw.
    rs_result-filename = |EINV_{ iv_doc_id }.pdf|.
  ENDMETHOD.


**********************************************************************
* Seller action
**********************************************************************

  METHOD post_seller_action.
    " The HANA URL had '&1' replaced by the hard-coded literal 'SALES'.
    DATA(lv_url) = build_url( iv_bukrs         = iv_bukrs
                              iv_function      = zcl_einv_config=>gc_function-seller_action
                              iv_placeholder_1 = 'SALES' ).

    " Typed payload instead of the string-template body of
    " call_seller_action, so escaping is the serializer's problem.
    DATA ls_request TYPE zstr_einv_act_req.
    ls_request-documentid = iv_doc_id.
    ls_request-actiontype = iv_action_type.
    ls_request-comment    = iv_comment.

    IF iv_action_type = gc_action-confirm_payment.
      ls_request-actiondata-collectiondate = zcl_einv_util=>format_date_ddmmyyyy( iv_coll_date ).
      ls_request-actiondata-vatratesplit   = it_vat_split.
    ENDIF.

    DATA(lv_body) = /ui2/cl_json=>serialize(
                      data        = ls_request
                      compress    = abap_true
                      pretty_name = /ui2/cl_json=>pretty_mode-camel_case ).

    DATA(ls_call) = execute( iv_bukrs    = iv_bukrs
                             iv_function = zcl_einv_config=>gc_function-seller_action
                             iv_url      = lv_url
                             iv_method   = 'POST'
                             iv_body     = lv_body ).

    rs_result-http = ls_call-http_code.

    IF ls_call-error IS NOT INITIAL.
      rs_result-message = ls_call-error.
      rs_result-status  = 'ERROR'.
      RETURN.
    ENDIF.

    DATA ls_response TYPE zstr_einv_action_res.
    IF ls_call-body_text IS NOT INITIAL.
      /ui2/cl_json=>deserialize( EXPORTING json        = ls_call-body_text
                                           pretty_name = abap_true
                                 CHANGING  data        = ls_response ).
    ENDIF.

    rs_result-errors  = ls_response-error_details.
    rs_result-message = collect_error_text( ls_response-error_details ).

    IF ls_call-http_code = 200 AND to_lower( ls_response-success ) = 'true'.
      rs_result-success = abap_true.
      " call_seller_action set COMPLETED for COMPLETE and COLLECTED for
      " CONFIRM_PAYMENT.
      rs_result-status = COND #( WHEN iv_action_type = gc_action-confirm_payment
                                 THEN 'COLLECTED'
                                 ELSE 'COMPLETED' ).
    ELSE.
      rs_result-success = abap_false.
      rs_result-status  = 'ERROR'.
      IF rs_result-message IS INITIAL.
        rs_result-message = |HTTP { ls_call-http_code } { ls_call-reason }|.
      ENDIF.
    ENDIF.
  ENDMETHOD.


**********************************************************************
* e-Document actions (AP inbound and self-billed)
**********************************************************************

  METHOD post_edocument_action.

    DATA(lv_url) = build_url( iv_bukrs         = iv_bukrs
                              iv_function      = iv_function
                              iv_placeholder_1 = is_request-documentnumber
                              iv_placeholder_2 = is_request-documenttypecode ).

    IF lv_url IS INITIAL AND iv_function = 'EINV_SELF_STATUS'.
      " The self-billing include falls back to the AP endpoint when no
      " EINV_SELF_STATUS row exists. Kept, but reported rather than silent.
      lv_url = build_url( iv_bukrs         = iv_bukrs
                          iv_function      = zcl_einv_config=>gc_function-ap_status
                          iv_placeholder_1 = is_request-documentnumber
                          iv_placeholder_2 = is_request-documenttypecode ).
      IF lv_url IS NOT INITIAL.
        rs_result-message = 'EINV_SELF_STATUS not maintained - used EINV_AP_STATUS. '.
      ENDIF.
    ENDIF.

    DATA(lv_body) = /ui2/cl_json=>serialize(
                      data        = is_request
                      compress    = abap_true
                      pretty_name = /ui2/cl_json=>pretty_mode-camel_case ).

    DATA(ls_call) = execute( iv_bukrs    = iv_bukrs
                             iv_function = iv_function
                             iv_url      = lv_url
                             iv_method   = 'POST'
                             iv_body     = lv_body ).

    rs_result-http = ls_call-http_code.

    IF ls_call-error IS NOT INITIAL.
      rs_result-success = abap_false.
      rs_result-message = |{ rs_result-message }{ ls_call-error }|.
      RETURN.
    ENDIF.

    DATA ls_response TYPE zstr_einv_action_res.
    IF ls_call-body_text IS NOT INITIAL.
      /ui2/cl_json=>deserialize( EXPORTING json        = ls_call-body_text
                                           pretty_name = abap_true
                                 CHANGING  data        = ls_response ).
    ENDIF.

    rs_result-doc_id = ls_response-document_id.

    " send_action_data required HTTP 200 AND _success = 'true'.
    IF ls_call-http_code = 200 AND to_lower( ls_response-success ) = 'true'.
      rs_result-success = abap_true.
      rs_result-message = |{ rs_result-message }{ ls_response-message }|.
    ELSE.
      rs_result-success = abap_false.
      DATA(lv_err) = collect_error_text( ls_response-error_details ).
      rs_result-message = |{ rs_result-message }| &&
        COND #( WHEN lv_err IS NOT INITIAL THEN lv_err
                WHEN ls_response-message IS NOT INITIAL THEN ls_response-message
                ELSE |HTTP { ls_call-http_code } { ls_call-reason }| ).
    ENDIF.

  ENDMETHOD.


  METHOD get_document_list.

    DATA(lv_url) = build_url( iv_bukrs    = iv_bukrs
                              iv_function = zcl_einv_config=>gc_function-get_doc_list ).

    IF lv_url IS NOT INITIAL.
      lv_url = |{ lv_url }?start-date={ zcl_einv_util=>format_date_iso( iv_date_from ) }|
            && |&end-date={ zcl_einv_util=>format_date_iso( iv_date_to ) }|
            && |&einvoice-type={ iv_einv_type }|.
    ENDIF.

    DATA(ls_call) = execute( iv_bukrs    = iv_bukrs
                             iv_function = zcl_einv_config=>gc_function-get_doc_list
                             iv_url      = lv_url
                             iv_method   = 'GET' ).

    rs_result-http = ls_call-http_code.

    IF ls_call-error IS NOT INITIAL.
      rs_result-message = ls_call-error.
      RETURN.
    ENDIF.

    DATA ls_response TYPE zstr_einv_apdocs_res.
    IF ls_call-body_text IS NOT INITIAL.
      /ui2/cl_json=>deserialize( EXPORTING json        = ls_call-body_text
                                           pretty_name = abap_true
                                 CHANGING  data        = ls_response ).
    ENDIF.

    IF ls_call-http_code = 200.
      rs_result-success = abap_true.
      rs_result-docs    = ls_response-documents.
    ELSE.
      rs_result-success = abap_false.
      rs_result-message = COND #(
        WHEN ls_response-error_details IS NOT INITIAL
        THEN collect_error_text( ls_response-error_details )
        ELSE |HTTP { ls_call-http_code } { ls_call-reason }| ).
    ENDIF.

  ENDMETHOD.


**********************************************************************
* Cancellation
**********************************************************************

  METHOD post_cancel.
    DATA(lv_url) = build_url( iv_bukrs         = iv_bukrs
                              iv_function      = zcl_einv_config=>gc_function-cancel
                              iv_placeholder_1 = iv_doc_id
                              iv_placeholder_2 = iv_doc_type ).

    DATA ls_request TYPE zstr_einv_act_req.
    ls_request-documentid       = iv_doc_id.
    ls_request-documenttypecode = iv_doc_type.
    ls_request-actiontype       = 'CANCEL'.
    ls_request-comment          = iv_comment.

    DATA(lv_body) = /ui2/cl_json=>serialize(
                      data        = ls_request
                      compress    = abap_true
                      pretty_name = /ui2/cl_json=>pretty_mode-camel_case ).

    DATA(ls_call) = execute( iv_bukrs    = iv_bukrs
                             iv_function = zcl_einv_config=>gc_function-cancel
                             iv_url      = lv_url
                             iv_method   = 'POST'
                             iv_body     = lv_body ).

    rs_result-http = ls_call-http_code.

    IF ls_call-error IS NOT INITIAL.
      rs_result-message = ls_call-error.
      rs_result-status  = 'ERROR'.
      RETURN.
    ENDIF.

    DATA ls_response TYPE zstr_einv_action_res.
    IF ls_call-body_text IS NOT INITIAL.
      /ui2/cl_json=>deserialize( EXPORTING json        = ls_call-body_text
                                           pretty_name = abap_true
                                 CHANGING  data        = ls_response ).
    ENDIF.

    rs_result-errors  = ls_response-error_details.
    rs_result-message = collect_error_text( ls_response-error_details ).

    IF ls_call-http_code = 200 AND to_lower( ls_response-success ) = 'true'.
      rs_result-success = abap_true.
      rs_result-status  = 'CANCELLED'.
    ELSE.
      rs_result-success = abap_false.
      rs_result-status  = 'ERROR'.
      IF rs_result-message IS INITIAL.
        rs_result-message = |HTTP { ls_call-http_code } { ls_call-reason }|.
      ENDIF.
    ENDIF.
  ENDMETHOD.



  METHOD iso_ts_split.

    " /CLR/ZCL_EINV_BASE~ISO_TS_SPLIT.
    "
    " Accepts what the authority actually sends:
    "   2026-10-02T11:42:07.123Z
    "   2026-10-02T11:42:07Z
    "   2026-10-02T11:42:07.123+02:00
    "   2026-10-02 11:42:07
    " and refuses, rather than guesses, anything else.
    "
    " No timezone conversion. The value is stored as the authority stamped
    " it, which its own comment in /CLR/ZT_EINV_PPF calls out as UTC. A
    " conversion here would silently restate someone else's fact.

    CLEAR: ev_date, ev_time, ev_msec, ev_key.

    DATA(lv_iso) = condense( val = iv_iso ).
    IF strlen( lv_iso ) < 19.
      RETURN.                        " too short to be an instant at all
    ENDIF.

    " Positions are fixed for the whole accepted set: YYYY-MM-DDxHH:MM:SS
    DATA(lv_y)  = substring( val = lv_iso off = 0  len = 4 ).
    DATA(lv_m)  = substring( val = lv_iso off = 5  len = 2 ).
    DATA(lv_d)  = substring( val = lv_iso off = 8  len = 2 ).
    DATA(lv_hh) = substring( val = lv_iso off = 11 len = 2 ).
    DATA(lv_mi) = substring( val = lv_iso off = 14 len = 2 ).
    DATA(lv_ss) = substring( val = lv_iso off = 17 len = 2 ).

    DATA(lv_digits) = lv_y && lv_m && lv_d && lv_hh && lv_mi && lv_ss.
    IF lv_digits CN '0123456789'.
      RETURN.                        " a separator landed where a digit belongs
    ENDIF.

    " Fractional seconds, when present, to exactly three places. '.1'
    " means 100ms, not 1ms, so the field is padded rather than converted.
    DATA lv_ms TYPE string VALUE '000'.
    IF strlen( lv_iso ) > 19 AND substring( val = lv_iso off = 19 len = 1 ) = '.'.
      DATA(lv_frac) = ||.
      DATA(lv_off)  = 20.
      WHILE lv_off < strlen( lv_iso ).
        DATA(lv_ch) = substring( val = lv_iso off = lv_off len = 1 ).
        IF lv_ch CN '0123456789'.
          EXIT.
        ENDIF.
        lv_frac = lv_frac && lv_ch.
        lv_off  = lv_off + 1.
      ENDWHILE.
      IF lv_frac IS NOT INITIAL.
        lv_ms = substring( val = lv_frac && '000' off = 0 len = 3 ).
      ENDIF.
    ENDIF.

    ev_date = |{ lv_y }{ lv_m }{ lv_d }|.
    ev_time = |{ lv_hh }{ lv_mi }{ lv_ss }|.
    ev_msec = lv_ms.

    " The sort key is the concatenation itself: fixed width, all digits,
    " so a plain character comparison orders instants correctly. Returned
    " only on a parse that succeeded, which is what lets the caller treat
    " SPACE as "never the latest".
    ev_key = lv_digits && lv_ms.

  ENDMETHOD.

ENDCLASS.
