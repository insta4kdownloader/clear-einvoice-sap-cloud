"! <p class="shorttext synchronized">e-Invoice: ELT posting / IRN write-back</p>
"!
"! The cloud half of the HANA posting flow:
"!
"!   /CLR/ZELT_EXEC_COMMAND  (batch driver report)
"!     -> get_command
"!     -> get_exec_program( )  -> '/CLR/ZELT_POSTING'
"!     -> SUBMIT (lv_program) WITH p_comm = ... p_einv = 'X'
"!          /CLR/ZELT_POSTING
"!            -> trigger_posting( is_file_details, iv_einvoice )
"!                 -> get_posting_file  (download from the S3 URL)
"!                 -> per line: idempotency check, check_precondition,
"!                    get_context_data
"!                 -> CASE posting_type
"!                      WHEN 'IRN_WRITEBACK' -> insert_table_einvoice
"!                         -> MODIFY /CLR/ZT_SALES_ST
"!
"! WHAT IS MISSING IN ZZCLR_ELT, AND WHY THIS CLASS EXISTS
"!
"! Four things, all of them load-bearing:
"!
"!   1. ZCL_ELT~elt_exec_command NEVER DISPATCHES. It calls elt_ingestion
"!      for every command whose command_id is filled. The HANA driver
"!      chose between two programs on the command verb. So a DATA_POSTING
"!      command is handed to the ingestion path, which has nothing to do
"!      with it.
"!   2. ZCL_ELT~get_exec_program is an empty shell - every statement in
"!      its body is commented out and it has no RETURNING parameter. It is
"!      called from nowhere.
"!   3. ZCL_ELT~trigger_posting exists and has no caller anywhere in the
"!      repository. Its CASE on posting_type has both branches commented
"!      out, so even when reached it does nothing per row.
"!   4. ZCL_ELT~insert_table_einvoice does not exist. It is one of the
"!      eleven e-invoice methods recorded as missing in section 52 of
"!      CONVERSION_DESIGN.md - the same hole that swallowed
"!      get_command_einvoice.
"!
"! Net effect: nothing in the converted package has ever written
"! ZTEINV_SALES_ST. The table, the CDS views over it and the Exchange
"! Status table on the object page are all correct and all permanently
"! empty.
"!
"! This class supplies 1, 2 and 4 for the e-invoice flow, and a corrected
"! 3, in ZZCLR_GEINV, without editing ZZCLR_ELT. Section 53 took the same
"! route for the command half and the reasoning is unchanged: ZCL_ELT is
"! shared by every ELT flow in the tenant, and this project does not own
"! it. The ZZCLR_ELT defects are reported, not patched in place.
"!
"! HOW THE TWO REPORTS BECOME NO REPORTS
"!
"! ABAP Cloud has neither reports nor SUBMIT, so the driver/child split
"! cannot survive as such - and does not need to. The split existed in
"! HANA because SUBMIT ... AND RETURN was the only way to give each
"! command its own LUW and its own short dump boundary. ZCL_EINV_ELT_EXEC_JOB
"! is the driver; the dispatch below is the SUBMIT; the methods here are
"! the child report. One process, three method calls.
CLASS zcl_einv_elt_posting DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    "! What the command verb asks for. Replaces get_exec_program, which
    "! returned a report name - a thing that no longer exists.
    TYPES ty_action TYPE c LENGTH 1.

    " I = DATA_EXTRACTION / DATA_QUALITY -> the ingestion path
    " P = DATA_POSTING                   -> this class
    " N = NO_COMMAND                     -> queue empty, stop the loop
    " ? = anything else                  -> HANA wrote s039 and left list
    "                                       processing
    CONSTANTS:
      gc_action_ingest  TYPE ty_action VALUE 'I',
      gc_action_post    TYPE ty_action VALUE 'P',
      gc_action_none    TYPE ty_action VALUE 'N',
      gc_action_unknown TYPE ty_action VALUE '?'.

    " The command verbs, verbatim from /CLR/ZCL_ELT~get_exec_program.
    CONSTANTS:
      gc_cmd_extraction TYPE string VALUE 'DATA_EXTRACTION' ##NO_TEXT,
      gc_cmd_quality    TYPE string VALUE 'DATA_QUALITY'    ##NO_TEXT,
      gc_cmd_posting    TYPE string VALUE 'DATA_POSTING'    ##NO_TEXT,
      gc_cmd_none       TYPE string VALUE 'NO_COMMAND'      ##NO_TEXT.

    " The posting_type the platform puts on an e-invoice write-back line.
    CONSTANTS gc_post_irn_writeback TYPE string VALUE 'IRN_WRITEBACK' ##NO_TEXT.

    TYPES:
      BEGIN OF ty_outcome,
        rows_read    TYPE i,
        rows_written TYPE i,
        rows_skipped TYPE i,
        rows_failed  TYPE i,
        error        TYPE string,
      END OF ty_outcome.

    METHODS constructor
      IMPORTING io_elt TYPE REF TO zcl_elt.

    "! The branch of /CLR/ZCL_ELT~get_exec_program, as a decision rather
    "! than a program name.
    METHODS get_action
      IMPORTING is_elt_command   TYPE zstr_elt_command
      RETURNING VALUE(rv_action) TYPE ty_action.

    "! /CLR/ZELT_POSTING with p_einv = 'X'.
    "!
    "! @parameter is_file_details | result-metadata-file_details of the
    "!   command: the S3 URL the posting file is downloaded from.
    "! @parameter iv_einvoice | The p_einv flag, forwarded exactly as
    "!   /CLR/ZELT_POSTING forwarded it to trigger_posting. It does ONE
    "!   thing in HANA: `IF iv_einvoice IS INITIAL. insert_table( ). ENDIF.`
    "!   Set, the generic writer is skipped and only the IRN_WRITEBACK
    "!   branch writes. Cleared, both run. It does not select a path and it
    "!   does not change the dispatch. Section 77.
    "!
    "!   It defaults to ABAP_TRUE because every caller in this package is
    "!   on the e-invoice path, which is the state this class was written
    "!   for.
    METHODS trigger_posting_einvoice
      IMPORTING is_file_details   TYPE zstr_elt_s3_detail_get
                iv_einvoice       TYPE abap_boolean DEFAULT abap_true
      RETURNING VALUE(rs_outcome) TYPE ty_outcome.

  PRIVATE SECTION.

    DATA mo_elt TYPE REF TO zcl_elt.

    "! /CLR/ZCL_ELT~insert_table_einvoice.
    "!
    "! The table written is whatever the platform names in the posting
    "! file - for the AR flow that is ZTEINV_SALES_ST. It is NOT hard
    "! coded here, exactly as it is not hard coded in HANA: the same
    "! method serves any write-back the platform defines, and pinning it
    "! to one table would break the next one.
    METHODS insert_table_einvoice
      IMPORTING is_schema         TYPE zstr_elt_posting
                iv_row_no         TYPE i
      RETURNING VALUE(rs_outcome) TYPE ty_outcome.

    "! Writes one ZTELT_SUCCESS row per written record, keyed by command
    "! and idempotency key, so the next run's duplicate check sees it.
    METHODS log_success
      IMPORTING is_schema TYPE zstr_elt_posting
                iv_row_no TYPE i
                it_rows   TYPE INDEX TABLE.

    METHODS log_failure
      IMPORTING is_schema TYPE zstr_elt_posting
                iv_row_no TYPE i
                iv_count  TYPE i.

ENDCLASS.



CLASS zcl_einv_elt_posting IMPLEMENTATION.

  METHOD constructor.
    mo_elt = io_elt.
  ENDMETHOD.


  METHOD get_action.
    CASE is_elt_command-result-command.
      WHEN gc_cmd_extraction OR gc_cmd_quality.
        rv_action = gc_action_ingest.
      WHEN gc_cmd_posting.
        rv_action = gc_action_post.
      WHEN gc_cmd_none.
        rv_action = gc_action_none.
      WHEN OTHERS.
        " HANA: MESSAGE s039 WITH command job_type / LEAVE LIST-PROCESSING.
        " A job has no list to leave; the caller logs and stops.
        rv_action = gc_action_unknown.
    ENDCASE.
  ENDMETHOD.


  METHOD trigger_posting_einvoice.

    " ---- download the posting file ------------------------------------
    mo_elt->get_posting_file(
      EXPORTING is_file_url      = is_file_details
      IMPORTING es_abap_response = DATA(lv_posting_file) ).

    IF lv_posting_file IS INITIAL.
      rs_outcome-error = 'Posting file empty or not retrievable' ##NO_TEXT.
      RETURN.
    ENDIF.

    " One JSON document per line, exactly as in HANA.
    SPLIT lv_posting_file AT cl_abap_char_utilities=>newline
          INTO TABLE DATA(lt_posting_file).

    LOOP AT lt_posting_file ASSIGNING FIELD-SYMBOL(<lv_line>).

      IF <lv_line> IS INITIAL.
        CONTINUE.
      ENDIF.

      " Plain assignment, not CONV sytabix( ): the data element SYTABIX
      " is not released for ABAP Cloud, and the inferred type of SY-TABIX
      " is already the integer the row number wants.
      DATA(lv_row_no) = sy-tabix.
      rs_outcome-rows_read = rs_outcome-rows_read + 1.

      DATA ls_posting_file TYPE zstr_elt_posting.
      CLEAR ls_posting_file.
      /ui2/cl_json=>deserialize( EXPORTING json        = <lv_line>
                                           pretty_name = abap_true
                                 CHANGING  data        = ls_posting_file ).

      mo_elt->go_event_instance->log_start(
        iv_action      = zcl_instru_event_class=>gc_exec_post_file_start
        it_description = VALUE string_table( ( <lv_line> ) ) ).

      " ---- idempotency ------------------------------------------------
      " The platform may resend a command. ZTELT_SUCCESS is the ledger;
      " a key already in it means this line was written by an earlier
      " run and must not be written again.
      SELECT SINGLE @abap_true
        FROM ztelt_success
        WHERE idem_key = @ls_posting_file-idempotency_key
        INTO @DATA(lv_exists).

      IF lv_exists = abap_true.
        rs_outcome-rows_skipped = rs_outcome-rows_skipped + 1.
        mo_elt->go_event_instance->log_error(
          iv_action = zcl_instru_event_class=>gc_idem_already_exist ).
        log_failure( is_schema = ls_posting_file
                     iv_row_no = lv_row_no
                     iv_count  = 1 ).
        CONTINUE.
      ENDIF.

      " ---- the generic writer, under HANA's guard ------------------------
      " /CLR/ZCL_ELT~trigger_posting:
      "     IF iv_einvoice IS INITIAL. insert_table( is_schema = ... ). ENDIF.
      " With the flag set only the IRN_WRITEBACK branch below writes; with
      " it cleared the generic writer runs first, as on the plain posting
      " path. This used to be hardcoded to "skip", which was right for the
      " only caller but made the parameter unexpressible.
      "
      " The converted ZCL_ELT~trigger_posting dropped the guard and calls
      " insert_table( ) unconditionally - reaching it on an e-invoice
      " command writes every row twice. That defect is still there and is
      " on the ZZCLR_ELT list; this class does not share its code.
      IF iv_einvoice IS INITIAL.
        mo_elt->insert_table( is_schema = ls_posting_file ).
      ENDIF.

      mo_elt->check_precondition(
        EXPORTING is_schema = ls_posting_file
                  iv_row_no = lv_row_no
        IMPORTING ev_error  = DATA(lv_error) ).

      IF lv_error IS NOT INITIAL.
        rs_outcome-rows_skipped = rs_outcome-rows_skipped + 1.
        CONTINUE.
      ENDIF.

      mo_elt->go_event_instance->log_telemetry(
        iv_action = zcl_instru_event_class=>gc_all_check_condition_passed ).

      CLEAR mo_elt->gt_context_data.
      mo_elt->get_context_data( is_schema = ls_posting_file ).

      CASE ls_posting_file-posting_type.
        WHEN gc_post_irn_writeback.
          DATA(ls_row_outcome) = insert_table_einvoice(
                                   is_schema = ls_posting_file
                                   iv_row_no = lv_row_no ).
          rs_outcome-rows_written = rs_outcome-rows_written + ls_row_outcome-rows_written.
          rs_outcome-rows_failed  = rs_outcome-rows_failed  + ls_row_outcome-rows_failed.

        WHEN OTHERS.
          " BAPI_ACC_DOCUMENT_POST is the generic engine's business, not
          " this package's. A posting file that reaches here with that
          " type belongs to a non-e-invoice command and is counted, not
          " written.
          rs_outcome-rows_skipped = rs_outcome-rows_skipped + 1.
      ENDCASE.

      mo_elt->go_event_instance->log_end(
        iv_action = zcl_instru_event_class=>gc_exec_post_file_end ).

      CLEAR lv_error.
    ENDLOOP.

  ENDMETHOD.


  METHOD insert_table_einvoice.

    FIELD-SYMBOLS <lt_table_data> TYPE INDEX TABLE.
    FIELD-SYMBOLS <ls_row>        TYPE any.

    DATA lr_row   TYPE REF TO data.
    DATA lr_table TYPE REF TO data.

    LOOP AT is_schema-insert_table ASSIGNING FIELD-SYMBOL(<ls_insert_table>).

      " ---- the dynamic write is the whole point -------------------------
      " The platform decides which table it is writing. For the AR status
      " flow it names ZTEINV_SALES_ST; the structure of the line is the
      " structure of that table and the field names in the JSON are its
      " column names.
      "
      " cl_abap_dyn_prg=>check_table_name_str is what makes this legal in
      " ABAP Cloud - an unchecked MODIFY (lv_name) is rejected. The
      " converted ZCL_ELT~insert_table already does this and the same
      " guard is used here.
      "
      " `packages` is restricted to this package, which the generic
      " ZCL_ELT cannot do (it passes VALUE #( ), meaning anywhere). The
      " e-invoice write-back only ever targets tables in ZZCLR_GEINV, so
      " naming the package turns "the platform may write any table in the
      " system" into "the platform may write our tables".
      TRY.
          DATA(lv_table) = cl_abap_dyn_prg=>check_table_name_str(
                             val      = <ls_insert_table>-name
                             packages = 'ZZCLR_GEINV' ).
        CATCH cx_abap_not_a_table cx_abap_not_in_package INTO DATA(lx_name).
          rs_outcome-rows_failed = rs_outcome-rows_failed + 1.
          rs_outcome-error       = lx_name->get_text( ).
          log_failure( is_schema = is_schema
                       iv_row_no = iv_row_no
                       iv_count  = 1 ).
          CONTINUE.
      ENDTRY.

      CREATE DATA lr_row   TYPE (lv_table).
      CREATE DATA lr_table TYPE TABLE OF (lv_table).
      ASSIGN lr_table->* TO <lt_table_data>.
      ASSIGN lr_row->*   TO <ls_row>.

      LOOP AT <ls_insert_table>-data ASSIGNING FIELD-SYMBOL(<lt_data>).
        CLEAR <ls_row>.
        LOOP AT <lt_data> ASSIGNING FIELD-SYMBOL(<ls_field>).

          " to_upper: the platform's posting file is not consistent about
          " case - the IRN_WRITEBACK payload has thirty-one names in upper
          " case and `zsigned_inv` in lower. A component that does not
          " match is skipped silently by the sy-subrc test below, so one
          " stray lowercase name means one column quietly never written.
          ASSIGN COMPONENT to_upper( <ls_field>-name ) OF STRUCTURE <ls_row>
                 TO FIELD-SYMBOL(<lv_value>).
          IF sy-subrc <> 0.
            " Not a column of this table. HANA does the same - its
            " UNIQUE_IDENTIFIER field has no column in /CLR/ZT_SALES_ST
            " either - so an unknown name is data the platform sends that
            " this table does not keep, not an error.
            CONTINUE.
          ENDIF.

          CASE <ls_field>-type.
            WHEN 'VALUE'.
              <lv_value> = <ls_field>-value.

            WHEN 'REFERENCE'.
              " HANA leaves this branch empty in insert_table_einvoice -
              " a write-back line carries literals, not references into
              " the context. Kept as an explicit no-op so the difference
              " from insert_table( ) is visible rather than forgotten.

            WHEN 'SYSTEM'.
              " HANA: ASSIGN COMPONENT <value> OF STRUCTURE sy.
              " Dynamic access to SY is not released for ABAP Cloud. The
              " two fields the platform ever asks for are the date and
              " the time, so they are served explicitly. Anything else is
              " left initial rather than silently wrong.
              CASE <ls_field>-value.
                WHEN 'DATUM'. <lv_value> = cl_abap_context_info=>get_system_date( ).
                WHEN 'UZEIT'. <lv_value> = cl_abap_context_info=>get_system_time( ).
                WHEN 'UNAME'. <lv_value> = cl_abap_context_info=>get_user_technical_name( ).
                WHEN OTHERS.
              ENDCASE.
          ENDCASE.
        ENDLOOP.
        APPEND <ls_row> TO <lt_table_data>.
      ENDLOOP.

      IF <lt_table_data> IS INITIAL.
        CONTINUE.
      ENDIF.

      MODIFY (lv_table) FROM TABLE @<lt_table_data>.

      IF sy-subrc = 0.
        rs_outcome-rows_written = rs_outcome-rows_written + lines( <lt_table_data> ).
        log_success( is_schema = is_schema
                     iv_row_no = iv_row_no
                     it_rows   = <lt_table_data> ).
      ELSE.
        rs_outcome-rows_failed = rs_outcome-rows_failed + lines( <lt_table_data> ).
        log_failure( is_schema = is_schema
                     iv_row_no = iv_row_no
                     iv_count  = lines( <lt_table_data> ) ).
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


  METHOD log_success.

    DATA lt_succ TYPE STANDARD TABLE OF ztelt_success.

    DATA(lv_date) = cl_abap_context_info=>get_system_date( ).
    DATA(lv_time) = cl_abap_context_info=>get_system_time( ).

    LOOP AT it_rows ASSIGNING FIELD-SYMBOL(<ls_row>).

      APPEND INITIAL LINE TO lt_succ ASSIGNING FIELD-SYMBOL(<ls_succ>).
      <ls_succ>-entry_date = lv_date.
      <ls_succ>-entry_time = lv_time.
      <ls_succ>-command_id = mo_elt->gv_command_id.
      <ls_succ>-idem_key   = is_schema-idempotency_key.
      <ls_succ>-row_no     = iv_row_no.
      <ls_succ>-status     = 'POST_SUCCESS' ##NO_TEXT.

      " The three document fields, read off whatever structure the
      " platform wrote. Absent on a table that has no such column, which
      " is why each is tested separately rather than MOVE-CORRESPONDING.
      ASSIGN COMPONENT 'BELNR' OF STRUCTURE <ls_row> TO FIELD-SYMBOL(<lv_belnr>).
      IF sy-subrc = 0.
        <ls_succ>-document_number = <lv_belnr>.
      ENDIF.
      ASSIGN COMPONENT 'BUKRS' OF STRUCTURE <ls_row> TO FIELD-SYMBOL(<lv_bukrs>).
      IF sy-subrc = 0.
        <ls_succ>-company_code = <lv_bukrs>.
      ENDIF.
      ASSIGN COMPONENT 'GJAHR' OF STRUCTURE <ls_row> TO FIELD-SYMBOL(<lv_gjahr>).
      IF sy-subrc = 0.
        <ls_succ>-fiscal_year = <lv_gjahr>.
      ENDIF.

    ENDLOOP.

    IF lt_succ IS NOT INITIAL.
      INSERT ztelt_success FROM TABLE @lt_succ ACCEPTING DUPLICATE KEYS.
    ENDIF.

  ENDMETHOD.


  METHOD log_failure.

    DATA lt_errs TYPE STANDARD TABLE OF ztelt_errors.

    DATA(lv_date) = cl_abap_context_info=>get_system_date( ).
    DATA(lv_time) = cl_abap_context_info=>get_system_time( ).

    DO iv_count TIMES.
      APPEND VALUE #( entry_date = lv_date
                      entry_time = lv_time
                      command_id = mo_elt->gv_command_id
                      idem_key   = is_schema-idempotency_key
                      row_no     = iv_row_no
                      err_no     = sy-index
                      status     = 'POST_FAILURE'
                      typemes    = 'E' ) TO lt_errs ##NO_TEXT.
    ENDDO.

    IF lt_errs IS NOT INITIAL.
      MODIFY ztelt_errors FROM TABLE @lt_errs.
    ENDIF.

  ENDMETHOD.

ENDCLASS.
