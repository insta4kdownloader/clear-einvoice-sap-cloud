"! <p class="shorttext synchronized">e-Invoice: submission orchestrator</p>
"!
"! Replaces function module /CLR/EINV_EWAY_TRIGGER_ELT (function group
"! /CLR/EINV_ELT, package /CLR/ELT), which was the single hand-over
"! point from the e-invoice cockpit into the ELT engine. Function
"! modules cannot be created in ABAP Cloud, so it becomes a class.
"!
"! What the function module did:
"!
"!   DATA(lo_elt) = NEW /clr/zcl_elt( iv_seq ).
"!   DO 2 TIMES.
"!     lo_elt->get_command_einvoice( iv_vbeln = ... IMPORTING ... ).
"!     IF lv_status_code = 200. EXIT. ENDIF.
"!     WAIT UP TO 3 SECONDS.
"!   ENDDO.
"!   IF ls_command-result-command <> 'DATA_EXTRACTION'.
"!     ls_einv-error = 'Command Not Found'.
"!     MODIFY /clr/zt_einv FROM ls_einv.
"!   ELSE.
"!     lo_elt->trigger_ingestion_einvoice( ... ).
"!   ENDIF.
"!
"! Three things had to change:
"!
"!  1. WAIT UP TO n SECONDS blocks a work process and is not allowed.
"!     The retry loop is gone; a failed pick-up is reported and the
"!     APJ job ZCL_EINV_SUBMIT_JOB retries on its next run, which is
"!     the correct asynchronous pattern.
"!
"!  2. MODIFY /clr/zt_einv straight from the trigger wrote the status
"!     table behind the cockpit's back. Here the outcome is RETURNED
"!     and the RAP handler persists it inside the LUW.
"!
"!  3. get_command_einvoice / trigger_ingestion_einvoice do not exist
"!     on the converted ZCL_ELT of ZZCLR_ELT - only the generic
"!     get_command / trigger_ingestion do.
"!
"!     An earlier version of this comment claimed the generic pair was
"!     "the better outcome anyway". That was wrong, and it is corrected
"!     here rather than quietly deleted. The generic get_command takes no
"!     importing parameters and polls for whatever command is queued; it
"!     cannot submit a named document. The command half is now
"!     reimplemented in ZCL_EINV_ELT_COMMAND. The ingestion half is still
"!     the generic path and reports that it is. Sections 52 and 53.
CLASS zcl_einv_submit DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    CONSTANTS:
      gc_command_extraction TYPE string VALUE 'DATA_EXTRACTION',
      gc_http_ok            TYPE i      VALUE 200.

    TYPES: BEGIN OF ty_result,
             success    TYPE abap_boolean,
             status     TYPE zde_einv_status,
             message    TYPE zde_einv_errmsg,
             command_id TYPE zde_einv_cmdid,
             country    TYPE zde_einv_land1,
             "! The parsed ingestion write-back - the IRN, the signed
             "! invoice, the QR code and the platform's own status, as
             "! ZCL_EINV_ELT_INGEST~parse_writeback resolved them.
             "!
             "! This class does NOT apply it. The caller is the behaviour
             "! pool, which already issues one MODIFY ENTITIES at the end
             "! of the action, and that is the only place the write is
             "! legal. Section 61.
             writeback  TYPE zteinv_doc,
             has_wb     TYPE abap_boolean,
           END OF ty_result.

    "! Submits one document to the Clear platform.
    "!
    "! IV_COUNTRY was added to the whole submission chain in the
    "! 2026-09-25 HANA drop:
    "!   submit_data           passes gv_land1
    "!   submit_data_retrieval gained VALUE(iv_country) TYPE land1
    "!   /CLR/EINV_EWAY_TRIGGER_ELT gained IV_COUNTRY
    "!   /CLR/ZCL_ELT receives it when building the command
    "! That parameter is the mechanism that actually replaced the empty
    "! country subclasses - country branching moved into the ELT command
    "! layer. It is resolved from configuration when not supplied.
    METHODS submit_document
      IMPORTING iv_bukrs         TYPE zde_einv_bukrs
                iv_belnr         TYPE zde_einv_accdoc
                iv_gjahr         TYPE zde_einv_gjahr
                iv_vbeln         TYPE zde_einv_billdoc OPTIONAL
                iv_country       TYPE zde_einv_land1 OPTIONAL
                "! IV_SEQ of /CLR/EINV_EWAY_TRIGGER_ELT, which did
                "!   NEW /clr/zcl_elt( iv_seq = iv_seq )
                "! and thereby chose the ZTELT_CONFIG profile. Dropped in
                "! the first conversion along with ZCL_ELT's own parameter.
                "! Optional, as it was there: left blank, the instance reads
                "! the configuration the way it has been reading it.
                "! Section 77.
                iv_seq           TYPE ztelt_config-sequence OPTIONAL
      RETURNING VALUE(rs_result) TYPE ty_result.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_einv_submit IMPLEMENTATION.


  METHOD submit_document.

    " ZCL_ELT is the C1-released engine of package ZZCLR_ELT. It is
    " reused unchanged: it already owns the auth token, the hostname,
    " the presigned-URL upload, the zip creation, the dynamic
    " extraction driven by the platform's erp_config-tables, the
    " acknowledgement and the instrumentation logging.
    DATA(lv_country) = COND zde_einv_land1(
      WHEN iv_country IS NOT INITIAL
      THEN iv_country
      ELSE zcl_einv_config=>get_instance( )->get_country( iv_bukrs ) ).

    DATA(lo_elt) = NEW zcl_elt( iv_seq = iv_seq ).

    rs_result-country = lv_country.

    " THE COMMAND REQUEST IS E-INVOICE SPECIFIC.
    " The first conversion called ZCL_ELT~get_command here and recorded
    " the substitution as deliberate. It was wrong: get_command takes no
    " importing parameters at all - it polls for whatever command the
    " platform has queued and cannot know which document is being
    " submitted - and it reads a different config endpoint. The HANA
    " trigger called get_command_einvoice, which POSTs the document.
    " That method did not survive the conversion of the ELT package, so
    " ZCL_EINV_ELT_COMMAND reimplements it. Section 52.
    DATA(lo_command) = NEW zcl_einv_elt_command( lo_elt ).

    DATA(ls_cmd) = lo_command->get_command( iv_bukrs = iv_bukrs
                                            iv_belnr = iv_belnr
                                            iv_gjahr = iv_gjahr
                                            iv_vbeln = iv_vbeln ).

    DATA(ls_command) = ls_cmd-command.

    IF ls_cmd-error IS NOT INITIAL OR ls_cmd-http_code <> gc_http_ok.
      " The HANA trigger retried twice with WAIT UP TO 3 SECONDS. Not
      " allowed in the cloud - and pointless inside a RAP action, which
      " a user is waiting on. The document keeps its error and the
      " scheduled job picks it up again.
      rs_result-success = abap_false.
      rs_result-status  = 'ERROR'.
      rs_result-message = COND #(
        WHEN ls_cmd-error  IS NOT INITIAL THEN ls_cmd-error
        WHEN ls_cmd-reason IS NOT INITIAL THEN CONV zde_einv_errmsg( ls_cmd-reason )
        ELSE CONV zde_einv_errmsg( |Get command failed with HTTP { ls_cmd-http_code }| ) ).
      RETURN.
    ENDIF.

    rs_result-command_id = ls_command-result-command_id.

    IF ls_command-result-command <> gc_command_extraction.
      " Verbatim from the HANA trigger, which set
      "   ls_einv-error = 'Command Not Found'.
      rs_result-success = abap_false.
      rs_result-status  = 'ERROR'.
      rs_result-message = |Command Not Found (received '{ ls_command-result-command }')|.
      RETURN.
    ENDIF.

    " INGESTION IS THE E-INVOICE PATH, NOT THE GENERIC ONE.
    "
    " This used to call ZCL_ELT~trigger_ingestion and report the
    " substitution in the result message. The substitution was worse than
    " that message implied. trigger_ingestion runs
    "   create_files -> generate_pre_sign -> ingest_files -> post_command
    " and differs from the HANA trigger_ingestion_einvoice in four ways,
    " not one:
    "
    "   * it asks the platform's GENERATE_PRESIGN API for a one-time URL
    "     instead of posting to the endpoint configured as
    "     PRESIGN_URL_EINV,
    "   * it PUTs where the e-invoice API expects a POST,
    "   * it sends no auth headers, because a presigned URL carries its
    "     own - so the e-invoice endpoint would reject it - and no
    "     x-idempotency-key, which is what stops a retried submission
    "     minting a second IRN for one invoice,
    "   * it discards the response body, which on this path IS the IRN.
    "
    " ZCL_EINV_ELT_INGEST reimplements trigger_ingestion_einvoice and
    " ingest_files_einvoice. Only create_files is shared with the generic
    " path, and that one is genuinely common - it produces the same
    " bytes. Section 57.
    DATA(lo_ingest) = NEW zcl_einv_elt_ingest( lo_elt ).

    DATA(ls_ing) = lo_ingest->trigger_ingestion(
      is_config     = ls_command-result-metadata-erp_config
      iv_bukrs      = iv_bukrs
      iv_belnr      = iv_belnr
      iv_gjahr      = iv_gjahr
      iv_vbeln      = iv_vbeln
      iv_command_id = ls_command-result-command_id ).

    IF ls_ing-error IS NOT INITIAL.
      rs_result-success = abap_false.
      rs_result-status  = 'ERROR'.
      rs_result-message = ls_ing-error.
      RETURN.
    ENDIF.

    rs_result-writeback = ls_ing-writeback.
    rs_result-has_wb    = ls_ing-has_wb.

    " THE WRITE-BACK IS PARSED HERE AND APPLIED BY THE CALLER.
    " HANA ends the chain with ingestion_writeback_einvoice ->
    " insert_table_einvoice_ingst -> MODIFY /CLR/ZT_EINV. The parsing is
    " done (above, in ZCL_EINV_ELT_INGEST); the write is not, because
    " neither a direct table MODIFY nor MODIFY ENTITIES ... IN LOCAL MODE
    " is legal from here. RS_RESULT-WRITEBACK carries the filled row and
    " the behaviour pool merges it into its own LT_UPDATE. Section 61.
    "
    " A caller that ignores WRITEBACK gets the old behaviour - submitted,
    " no IRN on the document - rather than a short dump, which is the
    " right failure mode for an optional field on a result structure.
    rs_result-success = abap_true.
    rs_result-status  = 'SUBMITTED'.
    rs_result-message = |Submitted, command { rs_result-command_id }, file { ls_ing-file_name }|.

  ENDMETHOD.


ENDCLASS.
