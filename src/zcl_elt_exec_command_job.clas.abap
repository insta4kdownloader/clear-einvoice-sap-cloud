CLASS zcl_elt_exec_command_job DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_apj_dt_exec_object.
    INTERFACES if_apj_rt_exec_object.

    "! The Einvoice checkbox of /CLR/ZELT_EXEC_COMMAND.
    "!
    "! The HANA driver's loop is the SAME either way - get a command, pick
    "! the child program from the verb, SUBMIT it. The flag is forwarded:
    "!
    "!   SUBMIT (lv_program) ... WITH p_einv = 'X' ...
    "!
    "! and ends up at trigger_posting( iv_einvoice ), where it guards one
    "! statement: `IF iv_einvoice IS INITIAL. insert_table( ). ENDIF.`
    "!
    "! But /CLR/ZELT_INGESTION has no p_einv parameter, so that SUBMIT only
    "! works when the verb is DATA_POSTING. Setting the flag therefore
    "! means in practice "this run is the posting run" - by accident of the
    "! SUBMIT, not by design. This job makes that explicit instead of
    "! dumping on an extraction command. Section 77 corrects section 76,
    "! which read the flag as a path selector in the driver.
    DATA p_einv TYPE abap_boolean.

    "! The Sequence field of /CLR/ZELT_EXEC_COMMAND: the ZTELT_CONFIG
    "! profile to read. HANA passed it to NEW /CLR/ZCL_ELT( iv_seq = p_seq )
    "! and on to every child report. The conversion dropped the parameter
    "! and GET_ERP_CONFIG lost its `AND sequence = @iv_seq`. Both are back.
    "! Section 77.
    DATA p_seq TYPE ztelt_config-sequence.

    "! Runtime bound of the e-invoice loop, in seconds. Ignored unless
    "! P_EINV is set - the extraction path's own bound lives inside
    "! ZCL_ELT~elt_exec_command and is not a parameter.
    DATA p_maxsec TYPE i.

    "! Get Command retries for the e-invoice loop. Ignored unless P_EINV
    "! is set.
    DATA p_retry TYPE i.

  PRIVATE SECTION.
    DATA mv_user_name TYPE string.

    METHODS build_log_entries
      IMPORTING
        is_log                 TYPE zcl_elt=>ty_logs
        iv_erp_config          TYPE string
        iv_hostname            TYPE string
        iv_auth_token          TYPE string
        iv_erp_instance_config TYPE string
        iv_ping_url            TYPE string
        iv_ping_empty_response TYPE string
        iv_ping_fail           TYPE string
        iv_pre_sign_url        TYPE string
      RAISING
        cx_bali_runtime
        cx_uuid_error.

ENDCLASS.



CLASS ZCL_ELT_EXEC_COMMAND_JOB IMPLEMENTATION.


  METHOD if_apj_dt_exec_object~get_parameters.

    "-----------------------------------------------------------------------
    " This method was empty, which is why the job offered no selection at
    " all. /CLR/ZELT_EXEC_COMMAND had three fields:
    "
    "   Run in background   an Application Job always is - dropped
    "   Sequence            selects the ZTELT_CONFIG profile. Declared as
    "                       P_SEQ. An earlier version of this comment said
    "                       the SEQUENCE key component had been dropped in
    "                       the conversion so the field had nothing to
    "                       select. The column is a key field of
    "                       ZTELT_CONFIG; what was dropped is the WHERE
    "                       condition that used it. Section 77.
    "   Einvoice            declared below, as P_EINV.
    "
    " P_MAXSEC and P_RETRY are new: the e-invoice loop needs the bounds and
    " ZCL_EINV_ELT_EXEC_JOB has no catalog entry of its own to carry them.
    "-----------------------------------------------------------------------
    et_parameter_def = VALUE #(
      ( selname = 'P_EINV'   kind = if_apj_dt_exec_object=>parameter
        datatype = 'CHAR' length = 1
        param_text = 'e-Invoice Posting'       changeable_ind = abap_true )
      ( selname = 'P_MAXSEC' kind = if_apj_dt_exec_object=>parameter
        datatype = 'INT4' length = 10
        param_text = 'Max Runtime, e-Inv (s)'  changeable_ind = abap_true )
      ( selname = 'P_RETRY'  kind = if_apj_dt_exec_object=>parameter
        datatype = 'INT4' length = 10
        param_text = 'Get Command Retries'     changeable_ind = abap_true )
      ( selname = 'P_SEQ'    kind = if_apj_dt_exec_object=>parameter
        datatype = 'INT4' length = 10
        param_text = 'Sequence'                changeable_ind = abap_true ) ).

    et_parameter_val = VALUE #(
      ( selname = 'P_EINV'   kind = if_apj_dt_exec_object=>parameter
        sign = 'I' option = 'EQ' low = '' )
      ( selname = 'P_SEQ'    kind = if_apj_dt_exec_object=>parameter
        sign = 'I' option = 'EQ' low = '' )
      ( selname = 'P_MAXSEC' kind = if_apj_dt_exec_object=>parameter
        sign = 'I' option = 'EQ' low = '900' )
      ( selname = 'P_RETRY'  kind = if_apj_dt_exec_object=>parameter
        sign = 'I' option = 'EQ' low = '3' ) ).

  ENDMETHOD.


  METHOD if_apj_rt_exec_object~execute.

    "-----------------------------------------------------------------------
    " THE EINVOICE CHECKBOX.
    "
    " /CLR/ZELT_EXEC_COMMAND ran one loop and forwarded p_einv to the child
    " report. Only /CLR/ZELT_POSTING declares that parameter, so a run with
    " the flag set can only serve DATA_POSTING commands - the SUBMIT into
    " /CLR/ZELT_INGESTION would fail on an unknown parameter.
    "
    " So the flag is routed here, where an extraction command is reported
    " and left on the queue rather than dumping, and forwarded from there
    " to trigger_posting_einvoice( iv_einvoice ) - its one real job, which
    " is to decide whether the generic insert_table( ) runs.
    "
    " ELT_EXEC_COMMAND below is the other half, and it calls ELT_INGESTION
    " for every command it receives regardless of the verb: a DATA_POSTING
    " command reaching it is consumed and discarded. That is why the two
    " must not run concurrently against one queue. Sections 76 and 77.
    "-----------------------------------------------------------------------
    IF p_einv = abap_true.
      NEW zcl_einv_elt_exec_job( )->run_einvoice_posting(
        iv_maxsec   = p_maxsec
        iv_retry    = p_retry
        iv_seq      = p_seq
        iv_einvoice = p_einv ).
      RETURN.
    ENDIF.

    "-----------------------------------------------------------------------
    " Resolve the current user's formatted name once via the strategic API.
    " Replaces:
    "   SELECT SINGLE * FROM i_businessuserbasic WHERE userid = @sy-uname ...
    " - Closes ATC "SELECT *" finding.
    " - Removes a DB roundtrip per job run.
    " - Cloud-ready.
    "
    " get_user_formatted_name( ) can raise cx_abap_context_info_error
    " (technical users, missing BP record, name resolution failure).
    " We catch and fall back to sy-uname — a job must not abort over a
    " logging cosmetic.
    "-----------------------------------------------------------------------
    TRY.
        mv_user_name = cl_abap_context_info=>get_user_formatted_name( ).
      CATCH cx_abap_context_info_error.
        CLEAR mv_user_name.
    ENDTRY.

    IF mv_user_name IS INITIAL.
      mv_user_name = sy-uname.
    ENDIF.

    " iv_seq: HANA's NEW /CLR/ZCL_ELT( iv_seq = p_seq ). It picks the
    " ZTELT_CONFIG profile this run reads - endpoint, token, project.
    DATA(lo_elt) = NEW zcl_elt( iv_seq = p_seq ).

    DATA lt_logs TYPE STANDARD TABLE OF zcl_elt=>ty_logs.

    lo_elt->elt_exec_command(
      IMPORTING
        ex_log_no_command              = DATA(lv_log_no_command)
        ex_log_command_id              = DATA(lv_command_id)
        ex_event_count                 = DATA(lv_event_count)
        ex_file_name                   = DATA(lv_file_name)
        gc_extraction_empty_metadata   = DATA(lv_extraction_empty_metadata)
        gc_extraction_empty_command_id = DATA(lv_extraction_empty_command_id)
        ex_send_api_fail_gen_prsi      = DATA(lv_send_api_fail_gen_prsi)
        ex_rcv_api_gen_prsi_ret_code   = DATA(lv_rcv_api_gen_prsi_ret_code)
        ex_rcv_api_gen_prsi_resp       = DATA(lv_rcv_api_gen_prsi_resp)
        ex_rcv_api_gen_prsi_resp_init  = DATA(lv_rcv_api_gen_prsi_resp_init)
        ex_rcv_api_gen_prsi_ret_code_f = DATA(lv_rcv_api_gen_prsi_ret_code_f)
        ex_abap_response               = DATA(lv_abap_response)
        ex_status_code                 = DATA(lv_status_code)
        ex_reason                      = DATA(lv_reason)
        ex_pre_sign_url                = DATA(lv_pre_sign_url)
        ex_gen_pre_sign_url            = DATA(lv_gen_pre_sign_url)
        ex_ingestfile_status_code      = DATA(lv_ingestfile_status_code)
        ex_ingestfile_reason           = DATA(lv_ingestfile_reason)
        ex_rcv_api_upload_ret_code_f   = DATA(lv_rcv_api_upload_ret_code_f)
        ex_rcv_api_upload_ret_code     = DATA(lv_rcv_api_upload_ret_code)
        ex_send_api_fail_upload        = DATA(lv_send_api_fail_upload)
        ex_create_url_fail_upload      = DATA(lv_create_url_fail_upload)
        ex_postcomm_status_code        = DATA(lv_postcomm_status_code)
        ex_postcomm_reason             = DATA(lv_postcomm_reason)
        ex_post_comm_url_not_maint     = DATA(lv_post_comm_url_not_maint)
        ex_create_url_fail_post_comm   = DATA(lv_create_url_fail_post_comm)
        ex_send_api_fail_post_comm     = DATA(lv_send_api_fail_post_comm)
        ex_rcv_api_post_com_ret_code_f = DATA(lv_rcv_api_post_com_ret_code_f)
        et_logs                        = lt_logs ).

    lo_elt->ping_test(
      IMPORTING
        ex_ping_url            = DATA(lv_ping_url)
        ex_ping_empty_response = DATA(lv_ping_empty_response)
        ex_ping_fail           = DATA(lv_ping_fail) ).

    DATA(lv_erp_config)          = lo_elt->get_erp_config( ).
    DATA(lv_hostname)            = lo_elt->get_hostname( ).
    DATA(lv_auth_token)          = lo_elt->get_auth_token( ).
    DATA(lv_erp_instance_config) = lo_elt->get_erp_instance_id( ).

    LOOP AT lt_logs INTO DATA(ls_logs).
      TRY.
          build_log_entries(
            is_log                 = ls_logs
            iv_erp_config          = lv_erp_config
            iv_hostname            = lv_hostname
            iv_auth_token          = lv_auth_token
            iv_erp_instance_config = lv_erp_instance_config
            iv_ping_url            = lv_ping_url
            iv_ping_empty_response = lv_ping_empty_response
            iv_ping_fail           = lv_ping_fail
            iv_pre_sign_url        = lv_pre_sign_url ).

        CATCH cx_bali_runtime cx_uuid_error INTO DATA(lx_log_err).
          " ABAP Cloud language version disallows MESSAGE here.
          " Capture for debugger; do not rethrow.
          DATA(lv_log_failure) = lx_log_err->get_text( ).
      ENDTRY.
    ENDLOOP.

  ENDMETHOD.


  METHOD build_log_entries.

    DATA(lo_log) = cl_bali_log=>create( ).

    lo_log->set_header(
      cl_bali_header_setter=>create(
        object      = 'ZAJL_ELT_EXECUTION'
        subobject   = 'JOB_LOG_ELT'
        external_id = cl_system_uuid=>create_uuid_c32_static( ) ) ).

    DATA(lt_status) = VALUE string_table(
      ( |Job Started| )              "#EC NOTEXT
      ( |Program Started : ZCL_ELT, User Name { mv_user_name }| ) ). "#EC NOTEXT

    DATA lt_error TYPE string_table.

    IF iv_erp_config IS NOT INITIAL.
      APPEND iv_erp_config TO lt_error.

    ELSEIF iv_hostname IS NOT INITIAL.
      APPEND iv_hostname TO lt_error.

    ELSEIF iv_auth_token IS NOT INITIAL.
      APPEND iv_auth_token TO lt_error.

    ELSEIF iv_erp_instance_config IS NOT INITIAL.
      APPEND iv_erp_instance_config TO lt_error.

    ELSEIF is_log-ex_log_no_command IS NOT INITIAL.
      APPEND |Extraction Program Started with Command ID - { is_log-ex_log_no_command }| TO lt_error. "#EC NOTEXT

    ELSEIF is_log-ex_log_command_id IS NOT INITIAL AND is_log-ex_pre_sign_url IS NOT INITIAL.
      APPEND |Extraction Program Started with Command ID - { is_log-ex_log_command_id }| TO lt_error.  "#EC NOTEXT
      APPEND iv_pre_sign_url TO lt_error.

    ELSEIF is_log-ex_log_command_id IS NOT INITIAL AND is_log-ex_file_name IS INITIAL.
      APPEND |Extraction Program Started with Command ID - { is_log-ex_log_command_id }| TO lt_status."#EC NOTEXT
      APPEND |File Creation Error| TO lt_error.  "#EC NOTEXT

    ELSEIF is_log-ex_log_command_id IS NOT INITIAL AND is_log-gc_extraction_empty_metadata IS NOT INITIAL.
      APPEND |Extraction Program Started with Command ID - { is_log-ex_log_command_id }| TO lt_status.  "#EC NOTEXT
      APPEND is_log-gc_extraction_empty_metadata TO lt_error.

    ELSEIF is_log-ex_log_command_id IS NOT INITIAL AND is_log-ex_file_name IS NOT INITIAL.
      APPEND |Extraction Program Started with Command ID - { is_log-ex_log_command_id }| TO lt_status. "#EC NOTEXT
      APPEND |File Name: { is_log-ex_file_name }| TO lt_status.   "#EC NOTEXT

    ELSEIF is_log-ex_log_command_id IS NOT INITIAL AND
           ( iv_ping_fail           IS NOT INITIAL OR
             iv_ping_empty_response IS NOT INITIAL OR
             iv_ping_url            IS NOT INITIAL ).
      APPEND |Extraction Program Started with Command ID - { is_log-ex_log_command_id }| TO lt_status.  "#EC NOTEXT
      IF iv_ping_fail           IS NOT INITIAL. APPEND iv_ping_fail           TO lt_error. ENDIF.
      IF iv_ping_empty_response IS NOT INITIAL. APPEND iv_ping_empty_response TO lt_error. ENDIF.
      IF iv_ping_url            IS NOT INITIAL. APPEND iv_ping_url            TO lt_error. ENDIF.

    ELSEIF is_log-ex_log_command_id IS NOT INITIAL AND
           ( is_log-ex_postcomm_status_code        IS NOT INITIAL OR
             is_log-ex_postcomm_reason             IS NOT INITIAL OR
             is_log-ex_post_comm_url_not_maint     IS NOT INITIAL OR
             is_log-ex_create_url_fail_post_comm   IS NOT INITIAL OR
             is_log-ex_rcv_api_post_com_ret_code_f IS NOT INITIAL OR
             is_log-ex_send_api_fail_post_comm     IS NOT INITIAL ).
      APPEND |Extraction Program Started with Command ID - { is_log-ex_log_command_id }| TO lt_status.  "#EC NOTEXT
      IF is_log-ex_postcomm_status_code        IS NOT INITIAL. APPEND is_log-ex_postcomm_status_code        TO lt_error. ENDIF.
      IF is_log-ex_postcomm_reason             IS NOT INITIAL. APPEND is_log-ex_postcomm_reason             TO lt_error. ENDIF.
      IF is_log-ex_post_comm_url_not_maint     IS NOT INITIAL. APPEND is_log-ex_post_comm_url_not_maint     TO lt_error. ENDIF.
      IF is_log-ex_create_url_fail_post_comm   IS NOT INITIAL. APPEND is_log-ex_create_url_fail_post_comm   TO lt_error. ENDIF.
      IF is_log-ex_rcv_api_post_com_ret_code_f IS NOT INITIAL. APPEND is_log-ex_rcv_api_post_com_ret_code_f TO lt_error. ENDIF.
      IF is_log-ex_send_api_fail_post_comm     IS NOT INITIAL. APPEND is_log-ex_send_api_fail_post_comm     TO lt_error. ENDIF.

    ELSE.
      RETURN.
    ENDIF.

    APPEND |Extraction Program ended| TO lt_status.  "#EC NOTEXT
    APPEND |Job Finished|             TO lt_status.  "#EC NOTEXT

    "-----------------------------------------------------------------------
    " Materialise items into the BAL log.
    " cl_bali_free_text_setter=>create( text = ... ) expects c(200).
    " CONV #( ) infers the target type — lines >200 chars get truncated.
    "-----------------------------------------------------------------------
    LOOP AT lt_error INTO DATA(lv_err).
      lo_log->add_item(
        cl_bali_free_text_setter=>create(
          severity = if_bali_constants=>c_severity_error
          text     = CONV #( lv_err ) ) ).
    ENDLOOP.

    LOOP AT lt_status INTO DATA(lv_stat).
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
