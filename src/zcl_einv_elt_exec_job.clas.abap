"! <p class="shorttext synchronized">e-Invoice job: ELT execute command</p>
"!
"! The cloud equivalent of /CLR/ZELT_EXEC_COMMAND run with p_einv = 'X'.
"!
"! HANA scheduled that report as a batch job. It looped: ask the platform
"! for a command, work out which child report serves that command, SUBMIT
"! it, repeat until NO_COMMAND or the time limit. ABAP Cloud has no
"! reports and no SUBMIT, so the loop lives here and the SUBMIT becomes a
"! method call on ZCL_EINV_ELT_POSTING.
"!
"! HOW IT IS SCHEDULED
"!
"! Not by a catalog entry of its own. HANA ran both paths from one report
"! and chose between them with the Einvoice checkbox, and the cloud does
"! the same: ZCL_ELT_EXEC_COMMAND_JOB - the class behind
"! ZAJC_ELT_EXECUTE_COMMAND - now declares P_EINV and calls
"! RUN_EINVOICE_POSTING when it is set. Schedule job template
"! ZAJT_ELT_EXECUTE_COMMAND_1, which carries P_EINV = 'X'. Section 76.
"!
"! The two paths are therefore mutually exclusive per run, which matters:
"! ZCL_ELT~elt_exec_command calls elt_ingestion for every command
"! regardless of the verb - the dispatch to the posting path was lost in
"! the conversion (see the class documentation of ZCL_EINV_ELT_POSTING) -
"! so a DATA_POSTING command reaching the extraction path is consumed and
"! discarded: the platform marks it delivered and the write-back never
"! happens. Running both templates concurrently against one command queue
"! reintroduces exactly that race. Section 56.
"!
"! IF_APJ_RT_EXEC_OBJECT stays implemented so this class can still be
"! given its own catalog entry if the two paths are ever split.
CLASS zcl_einv_elt_exec_job DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_apj_dt_exec_object.
    INTERFACES if_apj_rt_exec_object.

    "! Seconds the loop may run before it stops and leaves the rest of
    "! the queue for the next scheduled run.
    "!
    "! The HANA report's comment says "15 minutes time elapsed" and its
    "! code says `IF ( lv_secs >= 54000 )`. 54000 seconds is 15 HOURS.
    "! Somebody multiplied by 60 once too often, and the converted
    "! ZCL_ELT~elt_exec_command carries the same number. The HANA job was
    "! bounded in practice by NO_COMMAND arriving, not by this test, which
    "! is why nobody noticed.
    "!
    "! It is a parameter here, defaulting to 900 - the fifteen minutes the
    "! comment always claimed. The inherited 54000 is not corrected in
    "! ZZCLR_ELT by this package.
    DATA p_maxsec TYPE i.

    "! Retries of get_command before the run gives up.
    "!
    "! HANA waited 60 seconds between attempts (WAIT UP TO 60 SECONDS).
    "! There is no released way to sleep in ABAP Cloud, so the retries
    "! here are immediate and the back-off is the job schedule: a run that
    "! cannot reach the platform ends, and the next scheduled run tries
    "! again. Three immediate attempts still distinguish a dropped
    "! connection from an endpoint that is down.
    DATA p_retry TYPE i.

    "! The whole job body, callable without the APJ framework.
    "!
    "! HANA did not give the e-invoice posting path a report of its own:
    "! /CLR/ZELT_EXEC_COMMAND served both, and the Einvoice checkbox on its
    "! selection screen chose between them. The cloud equivalent is one job
    "! catalog entry, ZAJC_ELT_EXECUTE_COMMAND, whose class branches on
    "! P_EINV - so ZCL_ELT_EXEC_COMMAND_JOB calls this method rather than
    "! this class needing a catalog entry and template of its own.
    "!
    "! It still implements IF_APJ_RT_EXEC_OBJECT, so it can be scheduled
    "! directly if a separate catalog entry is ever wanted. Section 76.
    METHODS run_einvoice_posting
      IMPORTING iv_maxsec   TYPE i DEFAULT 900
                iv_retry    TYPE i DEFAULT 3
                iv_seq      TYPE ztelt_config-sequence OPTIONAL
                iv_einvoice TYPE abap_boolean DEFAULT abap_true.

    "! The Sequence field of /CLR/ZELT_EXEC_COMMAND: which ZTELT_CONFIG
    "! profile this run reads. Passed to ZCL_ELT's constructor.
    DATA p_seq TYPE ztelt_config-sequence.

  PRIVATE SECTION.

    CONSTANTS gc_log_object    TYPE string VALUE 'ZAJL_EINV_EXECUTION' ##NO_TEXT.
    CONSTANTS gc_log_subobject TYPE string VALUE 'JOB_LOG_ELT_POST'    ##NO_TEXT.

    METHODS write_log
      IMPORTING it_status TYPE string_table
                it_error  TYPE string_table
      RAISING   cx_bali_runtime
                cx_uuid_error.

ENDCLASS.



CLASS zcl_einv_elt_exec_job IMPLEMENTATION.

  METHOD if_apj_dt_exec_object~get_parameters.

    et_parameter_def = VALUE #(
      ( selname = 'P_MAXSEC' kind = if_apj_dt_exec_object=>parameter
        datatype = 'INT4' length = 10
        param_text = 'Max Runtime (seconds)' changeable_ind = abap_true )
      ( selname = 'P_RETRY'  kind = if_apj_dt_exec_object=>parameter
        datatype = 'INT4' length = 10
        param_text = 'Get Command Retries'   changeable_ind = abap_true )
      ( selname = 'P_SEQ'    kind = if_apj_dt_exec_object=>parameter
        datatype = 'INT4' length = 10
        param_text = 'Sequence'              changeable_ind = abap_true ) ).

    et_parameter_val = VALUE #(
      ( selname = 'P_MAXSEC' kind = if_apj_dt_exec_object=>parameter
        sign = 'I' option = 'EQ' low = '900' )
      ( selname = 'P_RETRY'  kind = if_apj_dt_exec_object=>parameter
        sign = 'I' option = 'EQ' low = '3' )
      ( selname = 'P_SEQ'    kind = if_apj_dt_exec_object=>parameter
        sign = 'I' option = 'EQ' low = '' ) ).

  ENDMETHOD.


  METHOD if_apj_rt_exec_object~execute.

    " Scheduled directly, the framework has filled P_MAXSEC and P_RETRY
    " from the job's parameters. Everything else is in RUN_EINVOICE_POSTING
    " so that ZCL_ELT_EXEC_COMMAND_JOB can reach the same body when its own
    " P_EINV is set.
    run_einvoice_posting(
      iv_maxsec = COND i( WHEN p_maxsec > 0 THEN p_maxsec ELSE 900 )
      iv_retry  = COND i( WHEN p_retry  > 0 THEN p_retry  ELSE 3 )
      iv_seq    = p_seq ).

  ENDMETHOD.


  METHOD run_einvoice_posting.

    DATA lt_status TYPE string_table.
    DATA lt_error  TYPE string_table.

    DATA(lv_maxsec) = COND i( WHEN iv_maxsec > 0 THEN iv_maxsec ELSE 900 ).
    DATA(lv_retry)  = COND i( WHEN iv_retry  > 0 THEN iv_retry  ELSE 3 ).

    APPEND |ELT e-invoice posting job started| TO lt_status ##NO_TEXT.

    GET TIME STAMP FIELD DATA(lv_start).

    DO.

      " A fresh ZCL_ELT per command, as in HANA: its constructor reloads
      " ZTELT_CONFIG and starts a new telemetry envelope, so one bad
      " command does not poison the next.
      DATA(lo_elt) = NEW zcl_elt( iv_seq = iv_seq ).
      DATA(lo_post) = NEW zcl_einv_elt_posting( lo_elt ).

      lo_elt->go_event_instance->log_measurement(
        iv_action = zcl_instru_event_class=>gc_get_comm_exec ).

      " ---- get_command, with the HANA retry ---------------------------
      DATA lv_cnt TYPE i VALUE 0.
      DATA lv_status_code TYPE i.
      DATA ls_elt_command TYPE zstr_elt_command.
      DATA lv_reason TYPE string.

      DO lv_retry TIMES.
        lv_cnt = lv_cnt + 1.
        lo_elt->go_event_instance->log_measurement(
          iv_action = zcl_instru_event_class=>gc_get_com_event_cnt
          iv_value  = CONV #( lv_cnt ) ).

        CLEAR: lv_status_code, ls_elt_command, lv_reason.
        lo_elt->get_command(
          IMPORTING ev_status_code = lv_status_code
                    ev_elt_command = ls_elt_command
                    ev_reason      = lv_reason ).

        IF lv_status_code = 200.
          lo_elt->go_event_instance->log_telemetry(
            iv_action = zcl_instru_event_class=>gc_get_com_success
            iv_value  = CONV #( lv_cnt ) ).
          EXIT.
        ENDIF.

        " No WAIT between attempts: WAIT UP TO is not released for ABAP
        " Cloud. See the comment on P_RETRY - the schedule is the back-off.
      ENDDO.

      IF lv_status_code <> 200.
        APPEND |Get Command failed after { lv_cnt } attempts: { lv_reason }| TO lt_error ##NO_TEXT.
        EXIT.
      ENDIF.

      " ---- the dispatch the conversion lost ---------------------------
      DATA(lv_action) = lo_post->get_action( ls_elt_command ).

      CASE lv_action.

        WHEN zcl_einv_elt_posting=>gc_action_none.
          lo_elt->go_event_instance->log_telemetry(
            iv_action = zcl_instru_event_class=>gc_no_command ).
          APPEND |No command queued - run complete| TO lt_status ##NO_TEXT.
          EXIT.

        WHEN zcl_einv_elt_posting=>gc_action_post.
          APPEND |DATA_POSTING command { ls_elt_command-result-command_id }| TO lt_status ##NO_TEXT.

          DATA(ls_outcome) = lo_post->trigger_posting_einvoice(
            is_file_details = ls_elt_command-result-metadata-file_details
            iv_einvoice     = iv_einvoice ).

          APPEND |  read { ls_outcome-rows_read }, written { ls_outcome-rows_written }, | &&
                 |skipped { ls_outcome-rows_skipped }, failed { ls_outcome-rows_failed }|
                 TO lt_status ##NO_TEXT.

          IF ls_outcome-error IS NOT INITIAL.
            APPEND ls_outcome-error TO lt_error.
          ENDIF.

        WHEN zcl_einv_elt_posting=>gc_action_ingest.
          " An extraction command belongs to the ingestion path, which
          " lives in ZCL_ELT and is driven by ZCL_ELT_EXEC_COMMAND_JOB.
          " Consuming it here would take it off the queue and never do
          " the work, so this job reports it and stops rather than
          " swallowing somebody else's command.
          APPEND |Extraction command { ls_elt_command-result-command_id } | &&
                 |is not this job's work - stopping so it stays queued| TO lt_error ##NO_TEXT.
          EXIT.

        WHEN OTHERS.
          APPEND |Unknown command '{ ls_elt_command-result-command }' | &&
                 |(job type '{ ls_elt_command-result-job_type }')| TO lt_error ##NO_TEXT.
          EXIT.

      ENDCASE.

      " ---- time box ---------------------------------------------------
      GET TIME STAMP FIELD DATA(lv_now).
      DATA(lv_secs) = cl_abap_tstmp=>subtract( tstmp1 = lv_now
                                               tstmp2 = lv_start ).
      IF lv_secs >= lv_maxsec.
        APPEND |Runtime limit of { lv_maxsec }s reached - | &&
               |remaining commands left for the next run| TO lt_status ##NO_TEXT.
        EXIT.
      ENDIF.

    ENDDO.

    APPEND |ELT e-invoice posting job finished| TO lt_status ##NO_TEXT.

    TRY.
        write_log( it_status = lt_status
                   it_error  = lt_error ).
      CATCH cx_bali_runtime cx_uuid_error INTO DATA(lx_log).
        " ABAP Cloud forbids MESSAGE here and a logging failure must not
        " fail the run. Captured for the debugger only.
        DATA(lv_log_failure) = lx_log->get_text( ).
    ENDTRY.

  ENDMETHOD.


  METHOD write_log.

    DATA(lo_log) = cl_bali_log=>create( ).

    lo_log->set_header(
      cl_bali_header_setter=>create(
        object      = CONV #( gc_log_object )
        subobject   = CONV #( gc_log_subobject )
        external_id = cl_system_uuid=>create_uuid_c32_static( ) ) ).

    LOOP AT it_error INTO DATA(lv_err).
      lo_log->add_item(
        cl_bali_free_text_setter=>create(
          severity = if_bali_constants=>c_severity_error
          text     = CONV #( lv_err ) ) ).
    ENDLOOP.

    LOOP AT it_status INTO DATA(lv_stat).
      lo_log->add_item(
        cl_bali_free_text_setter=>create(
          severity = if_bali_constants=>c_severity_status
          text     = CONV #( lv_stat ) ) ).
    ENDLOOP.

    cl_bali_log_db=>get_instance( )->save_log(
      log                        = lo_log
      assign_to_current_appl_job = abap_true ).

  ENDMETHOD.

ENDCLASS.
