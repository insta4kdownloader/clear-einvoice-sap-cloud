"! <p class="shorttext synchronized">e-Invoice: ELT ingestion upload</p>
"!
"! Replaces /CLR/ZCL_ELT~trigger_ingestion_einvoice and
"! ~ingest_files_einvoice, the third and fourth of the eleven e-invoice
"! methods the conversion of the ELT package did not carry over (section
"! 52). ZCL_EINV_ELT_COMMAND was the first pair, ZCL_EINV_ELT_POSTING the
"! second.
"!
"! WHY THE GENERIC INGESTION IS NOT A SUBSTITUTE
"!
"! ZCL_EINV_SUBMIT has been calling ZCL_ELT~trigger_ingestion, which runs
"! create_files -> generate_pre_sign -> ingest_files -> post_command.
"! That was reported as a known substitution rather than hidden, but it is
"! wrong in four ways at once, not one:
"!
"!   1. THE URL. generate_pre_sign calls the platform's GENERATE_PRESIGN
"!      API and uploads to the one-time URL it returns. The e-invoice path
"!      never asks: it posts straight to the endpoint configured as
"!      PRESIGN_URL_EINV. Two different endpoints, two different config
"!      rows.
"!   2. THE VERB. The generic upload is a PUT to a presigned S3 URL. The
"!      e-invoice upload is a POST to a Clear API.
"!   3. THE HEADERS. A presigned URL carries its own authorization in the
"!      query string, so ingest_files sends none. The e-invoice endpoint
"!      needs x-clear-auth-token, x-erp-instance-id and - importantly -
"!      x-idempotency-key set to the command id, which is what stops a
"!      retried submission producing two IRNs for one invoice.
"!   4. THE RESPONSE. ingest_files reads the response body into a local
"!      variable and discards it; it has no exporting parameter for it.
"!      On the e-invoice path that body IS the IRN - it is what
"!      ingestion_writeback_einvoice writes back onto the document. The
"!      generic path throws the answer away.
"!
"! So "the generic trigger_ingestion does the right work with the wrong
"! upload target", which is what the comment in ZCL_EINV_SUBMIT said,
"! understated it. Only create_files is shared. Everything after it
"! differs, and the response that matters is dropped on the floor.
"!
"! WHAT IS SHARED
"!
"! create_files( ), which builds the extract and leaves the archive in
"! ZCL_ELT~gv_zip_file_data. HANA has create_files_einvoice, but the two
"! differ only in which telemetry actions they log - the extraction logic
"! is identical - so the generic one is called here rather than copied.
"! That is a substitution, and unlike the four above it is a safe one:
"! the bytes produced are the same bytes.
CLASS zcl_einv_elt_ingest DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES:
      BEGIN OF ty_result,
        file_name TYPE string,
        http_code TYPE i,
        reason    TYPE string,
        "! The response body. On success this carries the IRN payload.
        response  TYPE string,
        "! The same body, parsed - see parse_writeback( ). The CALLER
        "! applies it; this class never touches the database.
        writeback TYPE zteinv_doc,
        "! abap_true when the response actually carried an IRN_WRITEBACK or
        "! NOT_APPLICABLE_TRANSACTION line. Without it an all-initial
        "! WRITEBACK is indistinguishable from one the platform sent empty.
        has_wb    TYPE abap_boolean,
        error     TYPE zde_einv_errmsg,
      END OF ty_result.

    METHODS constructor
      IMPORTING io_elt TYPE REF TO zcl_elt.

    "! /CLR/ZCL_ELT~trigger_ingestion_einvoice.
    "!
    "! @parameter is_config     | metadata-erp_config of the command: the
    "!   table list the extract is built from.
    "! @parameter iv_command_id | sent as x-idempotency-key, so the
    "!   platform collapses a retried submission onto one IRN.
    METHODS trigger_ingestion
      IMPORTING is_config        TYPE zstr_elt_comm_data-metadata-erp_config
                iv_bukrs         TYPE zde_einv_bukrs
                iv_belnr         TYPE zde_einv_accdoc
                iv_gjahr         TYPE zde_einv_gjahr
                iv_vbeln         TYPE zde_einv_billdoc OPTIONAL
                iv_command_id    TYPE zstr_elt_comm_data-command_id
      RETURNING VALUE(rs_result) TYPE ty_result.

    "! /CLR/ZCL_ELT~ingestion_writeback_einvoice +
    "! ~insert_table_einvoice_ingst, with the database write removed.
    "!
    "! WHY IT ONLY PARSES
    "!
    "! HANA ends this chain with a dynamic MODIFY FROM TABLE. That is not
    "! available here: ZCL_EINV_SUBMIT is called from a RAP action, and a
    "! direct table write in the interaction phase is the
    "! BEHAVIOR_ILLEGAL_STATEMENT of section 50. Nor can this class issue
    "! `MODIFY ENTITIES ... IN LOCAL MODE` - that is only legal inside the
    "! behaviour pool of the BO it names (section 48a, checker rule 59),
    "! and this is not that pool.
    "!
    "! So the method stops one step short: it does the dynamic mapping, it
    "! applies the backfill, and it hands back a filled ZTEINV_DOC work
    "! area. ZBP_CDS_INT_EINV_DOC~submiteinvoice - which IS the behaviour
    "! pool, and which already collects an LT_UPDATE and issues one MODIFY
    "! ENTITIES at the end - merges it into that table.
    "!
    "! The dynamic part is not lost. The platform still names the fields
    "! and this still resolves them by ASSIGN COMPONENT; what moved is the
    "! write, not the mapping.
    "!
    "! @parameter iv_response | the raw body returned by the upload, one
    "!   JSON document per line, exactly as HANA receives it.
    METHODS parse_writeback
      IMPORTING iv_response      TYPE string
                iv_bukrs         TYPE zde_einv_bukrs
                iv_belnr         TYPE zde_einv_accdoc
                iv_gjahr         TYPE zde_einv_gjahr
                iv_vbeln         TYPE zde_einv_billdoc OPTIONAL
                iv_command_id    TYPE zstr_elt_comm_data-command_id
      EXPORTING VALUE(ev_found)  TYPE abap_boolean
      RETURNING VALUE(rs_doc)    TYPE zteinv_doc.

  PRIVATE SECTION.

    " The two posting types HANA accepts on the ingestion write-back.
    " NOT_APPLICABLE_TRANSACTION is the platform saying "this document is
    " out of scope" - it is a result, not an error, and it is written back
    " exactly like an IRN.
    CONSTANTS:
      gc_wb_irn TYPE string VALUE 'IRN_WRITEBACK'              ##NO_TEXT,
      gc_wb_nat TYPE string VALUE 'NOT_APPLICABLE_TRANSACTION' ##NO_TEXT.

    DATA mo_elt TYPE REF TO zcl_elt.

    METHODS config_value
      IMPORTING iv_label        TYPE string
      RETURNING VALUE(rv_value) TYPE string.

    "! The upload itself: /CLR/ZCL_ELT~ingest_files_einvoice.
    METHODS ingest_files
      IMPORTING iv_url           TYPE string
                iv_command_id    TYPE zstr_elt_comm_data-command_id
      RETURNING VALUE(rs_result) TYPE ty_result.

ENDCLASS.



CLASS zcl_einv_elt_ingest IMPLEMENTATION.

  METHOD constructor.
    mo_elt = io_elt.
  ENDMETHOD.


  METHOD config_value.
    " Same reasoning as ZCL_EINV_ELT_COMMAND~config_value: read the
    " buffer the ZCL_ELT constructor filled rather than selecting again,
    " so the two can never disagree about which rows are current, and
    " SY-SYSID - not released for ABAP Cloud - stays inside the inherited
    " class where it already lives.
    rv_value = VALUE #( mo_elt->gt_erp_config[
                          labeltype = CONV ztelt_config-labeltype( iv_label ) ]-low OPTIONAL ).
  ENDMETHOD.


  METHOD trigger_ingestion.

    " ---- 1. build the extract ----------------------------------------
    " Leaves the zip in mo_elt->gv_zip_file_data.
    mo_elt->create_files(
      EXPORTING it_tables    = is_config-tables
      IMPORTING ex_file_name = DATA(lv_file_name) ).

    rs_result-file_name = lv_file_name.

    IF mo_elt->gv_zip_file_data IS INITIAL.
      rs_result-error = 'Extraction produced no file' ##NO_TEXT.
      RETURN.
    ENDIF.

    " ---- 1a. the DATA_ZIP diagnostic -----------------------------------
    " HANA writes the archive to the developer's workstation here when the
    " DATA_ZIP config row is set. There is no workstation; it is kept in
    " ZTEINV_ZIP and offered as a download instead. Staged, not written -
    " the BO's save phase does the write. See ZCL_EINV_ZIP_STORE.
    DATA(lo_zip) = NEW zcl_einv_zip_store( ).
    IF lo_zip->is_enabled( mo_elt ) = abap_true.
      lo_zip->stage( is_key        = VALUE #( vbeln = iv_vbeln
                                              belnr = iv_belnr
                                              bukrs = iv_bukrs
                                              gjahr = iv_gjahr )
                     iv_command_id = CONV #( iv_command_id )
                     iv_filename   = lo_zip->file_name(
                                       io_elt     = mo_elt
                                       iv_default = COND #( WHEN mo_elt->gv_zip_file_name IS NOT INITIAL
                                                            THEN mo_elt->gv_zip_file_name
                                                            ELSE |{ iv_belnr }_{ iv_gjahr }.zip| ) )
                     iv_content    = mo_elt->gv_zip_file_data ).
    ENDIF.

    " ---- 2. the endpoint ----------------------------------------------
    " PRESIGN_URL_EINV, not GENERATE_PRESIGN. The name is misleading - it
    " is not a presigned URL and nothing is signed. It is the Clear
    " e-invoice upload API, and it is kept because the HANA config row is
    " called that and the two systems share a config table layout.
    "
    " THIS ROW IS AN ABSOLUTE URL, NOT A PATH. The two e-invoice config
    " rows differ, and the HANA source is explicit about it:
    "
    "   get_command_einvoice   url = CONV #( lv_hostname && lv_url )
    "   ingest_files_einvoice  url = iv_presigned_url
    "
    " GET_COMMAND_EINV is a path and gets HOSTNAME in front of it;
    " PRESIGN_URL_EINV already carries the host and must not. The
    " converted generic ingest_files does the same thing - it passes
    " iv_presigned_url straight to create_by_url - for the same reason.
    DATA(lv_url) = config_value( zcl_einv_elt_command=>gc_cfg_presign ).

    IF lv_url IS INITIAL.
      " Verbatim from the HANA method, so a support call about this
      " message finds the same words in both systems.
      rs_result-error = 'Presigned URL not maintained in custom table' ##NO_TEXT.
      RETURN.
    ENDIF.

    " HOSTNAME is read as a GUARD, not as a prefix. In HANA it decides
    " which branch runs: a maintained HOSTNAME means "go out over HTTP to
    " the URL given", an empty one means "use the RFC destination". There
    " is no RFC branch in the cloud, so an empty HOSTNAME is simply an
    " unconfigured system.
    IF config_value( zcl_elt=>gc_hostname ) IS INITIAL.
      rs_result-error = 'HOSTNAME not maintained in custom table' ##NO_TEXT.
      RETURN.
    ENDIF.

    " A row maintained as a path rather than a full URL would otherwise
    " fail inside create_by_url with a message about the destination
    " rather than about the configuration. Say which row is wrong.
    " to_lower: CP/NP are case sensitive, and a hand-maintained row may
    " well read HTTPS://.
    IF to_lower( lv_url ) NP 'http*'.
      rs_result-error = |PRESIGN_URL_EINV must be a full URL | &&
                        |(starting http), not a path: { lv_url }| ##NO_TEXT.
      RETURN.
    ENDIF.

    " ---- 3. upload -----------------------------------------------------
    rs_result = ingest_files( iv_url        = lv_url
                              iv_command_id = iv_command_id ).

    rs_result-file_name = lv_file_name.

    " ---- 4. parse the write-back ---------------------------------------
    " HANA: IF lv_status_code EQ '200'. ingestion_writeback_einvoice( ).
    " Same guard. A non-200 body is an error page, not an IRN.
    IF rs_result-http_code = 200 AND rs_result-response IS NOT INITIAL.
      rs_result-writeback = parse_writeback(
        EXPORTING iv_response   = rs_result-response
                  iv_bukrs      = iv_bukrs
                  iv_belnr      = iv_belnr
                  iv_gjahr      = iv_gjahr
                  iv_vbeln      = iv_vbeln
                  iv_command_id = iv_command_id
        IMPORTING ev_found      = rs_result-has_wb ).
    ENDIF.

  ENDMETHOD.


  METHOD parse_writeback.

    " One JSON document per line, exactly as HANA splits it.
    SPLIT iv_response AT cl_abap_char_utilities=>newline INTO TABLE DATA(lt_lines).

    LOOP AT lt_lines ASSIGNING FIELD-SYMBOL(<lv_line>).

      IF <lv_line> IS INITIAL.
        CONTINUE.
      ENDIF.

      DATA ls_posting TYPE zstr_elt_posting.
      CLEAR ls_posting.
      /ui2/cl_json=>deserialize( EXPORTING json        = <lv_line>
                                           pretty_name = abap_true
                                 CHANGING  data        = ls_posting ).

      IF ls_posting-posting_type <> gc_wb_irn AND
         ls_posting-posting_type <> gc_wb_nat.
        CONTINUE.
      ENDIF.

      LOOP AT ls_posting-insert_table ASSIGNING FIELD-SYMBOL(<ls_insert>).
        LOOP AT <ls_insert>-data ASSIGNING FIELD-SYMBOL(<lt_data>).
          LOOP AT <lt_data> ASSIGNING FIELD-SYMBOL(<ls_field>).

            " to_upper for the same reason as in ZCL_EINV_ELT_POSTING: the
            " platform's payload mixes case, and a component that does not
            " match is skipped in silence.
            ASSIGN COMPONENT to_upper( <ls_field>-name ) OF STRUCTURE rs_doc
                   TO FIELD-SYMBOL(<lv_value>).
            IF sy-subrc <> 0.
              " No such column. HANA does the same: VALID_DATE,
              " CANCEL_DATE, UNIQUE_IDENTIFIER and UNIQID have no column in
              " /CLR/ZT_EINV either and are dropped there too. Section 61.
              CONTINUE.
            ENDIF.

            CASE <ls_field>-type.
              WHEN 'VALUE'.
                <lv_value> = <ls_field>-value.
              WHEN 'REFERENCE'.
                " Empty in HANA for this variant too.
              WHEN 'SYSTEM'.
                " HANA resolves this by ASSIGN COMPONENT ... OF STRUCTURE sy,
                " which ABAP Cloud does not allow. It does not matter: the
                " payload sends SYSTEM entries with an EMPTY value, so the
                " HANA lookup fails and the field is filled by the backfill
                " below instead. Left as an explicit no-op so that is on
                " the record rather than rediscovered.
            ENDCASE.

          ENDLOOP.
        ENDLOOP.
      ENDLOOP.

      ev_found = abap_true.
      " HANA loops every line but writes each immediately; here the last
      " write-back line wins, which is the same outcome for a single
      " document and avoids returning a table the caller cannot key.
    ENDLOOP.

    IF ev_found = abap_false.
      CLEAR rs_doc.
      RETURN.
    ENDIF.

    " ---- the backfill of insert_table_einvoice_ingst --------------------
    " Always overwritten, whatever the payload said.
    rs_doc-crdat  = cl_abap_context_info=>get_system_date( ).
    rs_doc-crtime = cl_abap_context_info=>get_system_time( ).
    rs_doc-cruser = cl_abap_context_info=>get_user_technical_name( ).

    " Filled only where the payload left them initial.
    IF rs_doc-vbeln      IS INITIAL. rs_doc-vbeln      = iv_vbeln.      ENDIF.
    IF rs_doc-bukrs      IS INITIAL. rs_doc-bukrs      = iv_bukrs.      ENDIF.
    IF rs_doc-belnr      IS INITIAL. rs_doc-belnr      = iv_belnr.      ENDIF.
    IF rs_doc-gjahr      IS INITIAL. rs_doc-gjahr      = iv_gjahr.      ENDIF.
    IF rs_doc-command_id IS INITIAL. rs_doc-command_id = iv_command_id. ENDIF.
    IF rs_doc-status     IS INITIAL.
      rs_doc-status = 'NOT APPLICABLE TRANSACTION' ##NO_TEXT.
    ENDIF.

  ENDMETHOD.


  METHOD ingest_files.

    DATA lo_client TYPE REF TO if_web_http_client.

    TRY.
        lo_client = cl_web_http_client_manager=>create_by_http_destination(
                      i_destination = cl_http_destination_provider=>create_by_url( iv_url ) ).
      CATCH cx_web_http_client_error cx_http_dest_provider_error INTO DATA(lx_dest).
        rs_result-error = |Error in create URL(Ingest File) { lx_dest->get_text( ) }| ##NO_TEXT.
        RETURN.
    ENDTRY.

    TRY.
        DATA(lo_request) = lo_client->get_http_request( ).

        " The four headers of the HANA method. x-idempotency-key is the
        " one that matters most: the platform keys the IRN on it, so a
        " resubmitted command returns the existing IRN instead of minting
        " a second one for the same invoice.
        lo_request->set_header_fields( VALUE #(
          ( name = zcl_elt=>gc_auth_token      value = config_value( zcl_elt=>gc_auth ) )
          ( name = zcl_elt=>gc_erp_instance_id value = config_value( zcl_elt=>gc_erp_id ) )
          ( name = 'x-idempotency-key'         value = iv_command_id )
          ( name = 'Content-Type'              value = zcl_elt=>gc_appl_zip ) ) ).

        " The archive is binary. set_text would mangle it - the generic
        " ingest_files has the same xstring and uses set_binary for the
        " same reason.
        lo_request->set_binary( i_data = mo_elt->gv_zip_file_data ).

        " POST, not the generic path's PUT.
        DATA(lo_response) = lo_client->execute( if_web_http_client=>post ).

        DATA(ls_status)     = lo_response->get_status( ).
        rs_result-http_code = ls_status-code.
        rs_result-reason    = ls_status-reason.
        rs_result-response  = lo_response->get_text( ).

        IF ls_status-code <> 200.
          rs_result-error = |INGEST FILE API { ls_status-code } { ls_status-reason }| ##NO_TEXT.
        ELSEIF rs_result-response IS INITIAL.
          rs_result-error = |Empty response (Ingest File) { ls_status-code } { ls_status-reason }| ##NO_TEXT.
        ENDIF.

        lo_client->close( ).

      CATCH cx_web_http_client_error cx_web_message_error INTO DATA(lx_http).
        rs_result-error = |Send API failed (Ingest File) { lx_http->get_text( ) }| ##NO_TEXT.
        TRY.
            lo_client->close( ).
          CATCH cx_web_http_client_error.
        ENDTRY.
    ENDTRY.

  ENDMETHOD.

ENDCLASS.
