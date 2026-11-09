CLASS zcl_instru_event_class DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    DATA gv_guid TYPE zde_guid_22.
    DATA iv_guid TYPE zde_guid_22.

    CONSTANTS: gc_erp                         TYPE string VALUE 'SAP',
               gc_cat_error                   TYPE string VALUE 'error',
               gc_get_comm_url_not_maint      TYPE string VALUE 'GET_COMMAND_URL_NOT_MAINTAINED',
               gc_create_url_fail_get_com     TYPE string VALUE 'CREATE_URL_FAIL_GET_COMMAND',
               gc_send_api_fail_get_com       TYPE string VALUE 'SEND_API_FAIL_GET_COMMAND',
               gc_cat_telemetry               TYPE string VALUE 'telemetry',
               gc_rcv_api_get_com_ret_code    TYPE string VALUE 'RECEIVE_API_SUCCESS_RETURN_CODE_GET_COMMAND',
               gc_rcv_api_get_com_resp        TYPE string VALUE 'RECEIVE_API_GET_COMMAND_RESPONSE',
               gc_rcv_api_get_com_resp_init   TYPE string VALUE 'RECEIVE_API_GET_COMMAND_RESPONSE_INITIAL',
               gc_get_context_data_start      TYPE string VALUE 'GET_CONTEXT_DATA_START',
               gc_get_context_data_end        TYPE string VALUE 'GET_CONTEXT_DATA_END',
               gc_precheck_condition_start    TYPE string VALUE 'PRE_CHECK_CONDITION_TEST_START',
               gc_precheck_condition_end      TYPE string VALUE 'PRE_CHECK_CONDITION_TEST_END',
               gc_precheck_condition_failed   TYPE string VALUE 'PRE_CHECK_CONDITION_FAILED',
               gc_error_table_updated         TYPE string VALUE 'ERROR_TABLE_UPDATED',
               gc_precheck_condition_passed   TYPE string VALUE 'PRECHECK_CONDITION_PASSED',
               gc_create_url_fail_get_file    TYPE string VALUE 'CREATE_URL_GET_FILE',
               gc_send_api_fail_get_file      TYPE string VALUE 'SEND_API_FAIL_GET_FILE',
               gc_rcv_api_fail_get_file       TYPE string VALUE 'RCV_API_FAIL_GET_FILE',
               gc_rcv_api_get_file_ret_code   TYPE string VALUE 'RCV_API_GET_FILE_RET_CODE',
               gc_post_com_success            TYPE string VALUE 'POST_COMMAND_SUCCESS',
               gc_post_com_evnt_cnt           TYPE string VALUE 'POST_COMMAND_EVENT_COUNT',
               gc_post_comm_url_not_maint     TYPE string VALUE 'POST_COMMAND_URL_NOT_MAINTAINED',
               gc_send_api_fail_post_comm     TYPE string VALUE 'SEND_API_FAIL_POST_COMMAND',
               gc_rcv_api_fail_post_comm      TYPE string VALUE 'RCV_API_FAIL_POST_COMMAND',
               gc_rcv_api_post_com_ret_code   TYPE string VALUE 'RCV_API_POST_COMM_RET_CODE',
               gc_rcv_api_post_com_ret_code_f TYPE string VALUE 'RCV_API_POST_COMM_RET_CODE_FAILED',
               gc_create_url_fail_post_comm   TYPE string VALUE 'CREATE_URL_FAIL_POST_COMMAND',
               gc_exec_post_file_start        TYPE string VALUE 'EXECUTE_POSTING_FILE_START',
               gc_idem_already_exist          TYPE string VALUE 'IDEM_ALREADY_EXISTS',
               gc_all_check_condition_passed  TYPE string VALUE 'ALL_CHECK_CONDITION_PASSED',
               gc_exec_post_file_end          TYPE string VALUE 'EXECUTE_POSTING_FILE_END',
               gc_rcv_api_upload_ret_code_f   TYPE string VALUE 'RCV_API_UPLOAD_FAIL_RETURN_CODE',
               gc_rcv_api_upload_ret_code     TYPE string VALUE 'RCV_API_UPLOAD_SUCCESS_RETURN_CODE',
               gc_rcv_api_fail_upload         TYPE string VALUE 'RCV_API_FAIL_UPLOAD',
               gc_send_api_fail_upload        TYPE string VALUE 'SEND_API_FAIL_UPLOAD',
               gc_create_url_fail_upload      TYPE string VALUE 'CREATE_URL_FAIL_UPLOAD',
               gc_json_file_created           TYPE string VALUE 'JSON_FILE_CREATED',
               gc_cat_measurement             TYPE string VALUE 'measurement'.

    "Get command event
    CONSTANTS :gc_get_comm_exec               TYPE string VALUE 'GET_COMMAND_EXECUTED',
               gc_get_com_event_cnt           TYPE string VALUE 'GET_COMMAND_EVENT_COUNT',
               gc_no_command                  TYPE string VALUE 'NO_COMMAND',
               gc_extraction_empty_command_id TYPE string VALUE 'EXTRACTION_EMPTY_COMMAND_ID',
               gc_extraction_empty_metadata   TYPE string VALUE 'EXTRACTION_EMPTY_METADATA',
               gc_extraction_start            TYPE string VALUE 'EXTRACTION_PROGRAM_STARTED',
               gc_extraction_end              TYPE string VALUE 'EXTRACTION_PROGRAM_END',
               gc_get_com_success             TYPE string VALUE 'GET_COMMAND_SUCCESS'.



    "Generate pre sign url events
    CONSTANTS :gc_gen_prsi_url_not_maint      TYPE string VALUE 'GET_PRESIGN_URL_NOT_MAINTAINED',
               gc_send_api_fail_gen_prsi      TYPE string VALUE 'SEND_API_FAIL_GET_PRESIGN_URL',
               gc_create_url_fail_gen_prsi    TYPE string VALUE 'CREATE_URL_FAIL_GET_PRESIGN_URL',
               gc_rcv_api_fail_gen_prsi       TYPE string VALUE 'RECEIVE_API_FAIL_GET_PRESIGN_URL',
               gc_rcv_api_gen_prsi_ret_code   TYPE string VALUE 'RECEIVE_API_SUCCESS_RETURN_CODE_GET_PRESIGN_URL',
               gc_rcv_api_gen_prsi_ret_code_f TYPE string VALUE 'RECEIVE_API_FAIL_RETURN_CODE_GET_PRESIGN_URL',
               gc_rcv_api_gen_prsi_resp       TYPE string VALUE 'RECEIVE_API_GET_PRESIGN_URL_RESPONSE',
               gc_rcv_api_gen_prsi_resp_init  TYPE string VALUE 'RECEIVE_API_GET_PRESIGN_URL_RESPONSE_INITIAL'.
**Get create files event
    CONSTANTS :gc_start_file_creation TYPE string VALUE 'FILE_CREATION_STARTED',
               gc_zip_file_saved      TYPE string VALUE 'ZIP_FILE_SAVED',
               gc_total_entry         TYPE string VALUE 'TOTAL_ENTRY_FETCHED',
               gc_end_file_creation   TYPE string VALUE 'FILE_CREATION_ENDED'.
    " ------------------------------------------------------------------
    " RAP deferral. INSERT and COMMIT WORK are both forbidden while a
    " behaviour implementation is active - the first submit from the Fiori
    " cockpit terminated with BEHAVIOR_ILLEGAL_STATEMENT inside
    " UPDATE_DB_TABLE. A caller that runs inside a RAP LUW sets GV_DEFER,
    " and the rows are held until the business object's save phase calls
    " FLUSH, where a database write is legal. Callers outside RAP leave
    " GV_DEFER unset and keep the original immediate write.
    " ------------------------------------------------------------------
    CLASS-DATA gv_defer TYPE abap_boolean .

    "! Writes everything held back while GV_DEFER was set. Called from the
    "! saver of the business object, so no COMMIT WORK here: the RAP LUW
    "! owns the commit.
    CLASS-METHODS flush .

    "! Discards what was held back. Called when the LUW is abandoned, so a
    "! discarded request does not leak its telemetry into the next save.
    CLASS-METHODS discard .

    CLASS-DATA gv_s_environment TYPE string .
    CLASS-DATA gv_s_erp_version TYPE string .
    CLASS-DATA gv_s_addon_v TYPE string .

    "retrial evenst
    CONSTANTS : gc_gen_presign_url_event_cnt TYPE string VALUE 'GENERATE_PRESIGN_URL_EVENT_COUNT',
                gc_ingest_event_cnt          TYPE string VALUE 'GET_INGEST_EVENT_COUNT'.

    "success events
    CONSTANTS : gc_gen_presign_succ TYPE string VALUE 'PRESIGN_URL_SUCCESS',
                gc_ingest_succ      TYPE string VALUE 'INGESTION_SUCCESS'.


    TYPES:
      BEGIN OF ty_s_event_data,
        workspace_id      TYPE string,
        environment       TYPE string,
        erp               TYPE string,
        erp_version       TYPE string,
        addon_version     TYPE string,
        enterprise_id     TYPE string,
        enterprise_name   TYPE string,
        erp_document_type TYPE string,
        erp_document_id   TYPE string,
        workflow_id       TYPE string,
        node_id           TYPE string,
        node_type         TYPE string,
        company           TYPE bukrs,
        guid              TYPE string,
        category          TYPE string,
        action            TYPE string,
        description       TYPE string,
        response          TYPE string,
        doc_count         TYPE string,
        value             TYPE string,
        event_timestamp   TYPE string,
        erp_user_id       TYPE string,
        background_flag   TYPE string,
        program_name      TYPE string,
      END OF ty_s_event_data .

    TYPES: BEGIN OF ty_s_tracker,
             timestamp TYPE timestampl,
           END OF ty_s_tracker .

    TYPES : ty_t_event_data TYPE TABLE OF ty_s_event_data .
    TYPES:ty_t_tracker TYPE TABLE OF ty_s_tracker .
    DATA gt_event_data TYPE ty_t_event_data.
    DATA gt_event_tracker TYPE ty_t_tracker .
    DATA gt_db_table TYPE ztevent_log_tt.
    DATA gv_event_counter TYPE  zde_int4.

    METHODS log_error IMPORTING iv_node_type         TYPE string OPTIONAL
                                iv_node_id           TYPE string OPTIONAL
                                iv_erp_document_type TYPE string OPTIONAL
                                iv_erp_document_id   TYPE string OPTIONAL
                                iv_workflow_id       TYPE string OPTIONAL
                                iv_action            TYPE string OPTIONAL
                                it_description       TYPE string_table OPTIONAL
                                it_response          TYPE string_table OPTIONAL
                                iv_value             TYPE string OPTIONAL
                                iv_doc_count         TYPE string OPTIONAL
                                iv_company           TYPE string OPTIONAL
                      EXPORTING ev_error             TYPE abap_boolean.

    METHODS log_telemetry IMPORTING iv_node_id           TYPE string OPTIONAL
                                    iv_node_type         TYPE string OPTIONAL
                                    iv_erp_document_id   TYPE string OPTIONAL
                                    iv_erp_document_type TYPE string OPTIONAL
                                    iv_workflow_id       TYPE string OPTIONAL
                                    iv_action            TYPE string OPTIONAL
                                    it_description       TYPE string_table OPTIONAL
                                    it_response          TYPE string_table OPTIONAL
                                    iv_value             TYPE string OPTIONAL
                                    iv_doc_count         TYPE string OPTIONAL
                                    iv_checkpoint_event  TYPE abap_boolean OPTIONAL
                                    is_recon_st          TYPE ztrecon_status OPTIONAL
                                    iv_company           TYPE string OPTIONAL
                          EXPORTING ev_error             TYPE abap_boolean.

    METHODS log_start  IMPORTING iv_node_type   TYPE string OPTIONAL
                                 iv_node_id     TYPE string OPTIONAL
                                 iv_action      TYPE string
                                 iv_workflow_id TYPE string OPTIONAL
                                 iv_value       TYPE string OPTIONAL
                                 iv_doc_count   TYPE string OPTIONAL
                                 it_description TYPE string_table OPTIONAL
                                 iv_company     TYPE string OPTIONAL.

    METHODS : log_end     IMPORTING iv_node_type   TYPE string OPTIONAL
                                    iv_node_id     TYPE string OPTIONAL
                                    iv_action      TYPE string
                                    iv_workflow_id TYPE string OPTIONAL
                                    iv_value       TYPE string OPTIONAL
                                    iv_doc_count   TYPE string OPTIONAL
                                    it_description TYPE string_table OPTIONAL.

    METHODS : log_measurement IMPORTING iv_node_type         TYPE string OPTIONAL
                                        iv_node_id           TYPE string OPTIONAL
                                        iv_action            TYPE string
                                        iv_workflow_id       TYPE string OPTIONAL
                                        iv_value             TYPE string OPTIONAL
                                        iv_doc_count         TYPE string OPTIONAL
                                        iv_checkpoint_event  TYPE abap_boolean OPTIONAL
                                        is_recon_st          TYPE ztrecon_status OPTIONAL
                                        it_description       TYPE string_table OPTIONAL
                                        iv_company           TYPE string OPTIONAL
                                        iv_erp_document_type TYPE string OPTIONAL
                                        iv_erp_document_id   TYPE string OPTIONAL .

    METHODS : constructor IMPORTING iv_guid          TYPE zde_guid_22 OPTIONAL
                                    iv_event_counter TYPE zde_event_counter OPTIONAL.



    METHODS get_timestamp_iso IMPORTING iv_iso                  TYPE    abap_boolean OPTIONAL
                              EXPORTING eo_timestamp            TYPE    timestampl
                              RETURNING VALUE(eo_iso_timestamp) TYPE string.

    METHODS : get_guid RETURNING VALUE(ro_guid) TYPE zde_guid_22.

    METHODS : get_guid1 RETURNING VALUE(ro_guid1) TYPE zde_guid_22.




  PROTECTED SECTION.
  PRIVATE SECTION.


    " Class-level, because the rows outlive the ZCL_INSTRU_EVENT_CLASS
    " instance: ZCL_ELT creates one per call, while the RAP LUW that has to
    " flush them spans many.
    CLASS-DATA gt_pending TYPE ztevent_log_tt.

    DATA gv_log_event TYPE abap_boolean VALUE 'X'.
    DATA: gv_workspace_id TYPE c LENGTH 40.
    DATA gv_bg_run TYPE zde_bg_flag." VALUE 'X' .
    DATA gv_cprog TYPE zde_cprog VALUE 'ZCL_ELT'.

*    gv_cprog = 'ZCL_ELT'.

    METHODS : convert_to_json EXPORTING ev_data_json TYPE string.

    METHODS update_db_table EXPORTING ev_error TYPE abap_boolean.

    METHODS log_event_data IMPORTING iv_node_type         TYPE string OPTIONAL
                                     iv_node_id           TYPE string OPTIONAL
                                     iv_erp_document_type TYPE string OPTIONAL
                                     iv_erp_document_id   TYPE string OPTIONAL
                                     iv_workflow_id       TYPE string OPTIONAL
                                     iv_category          TYPE string OPTIONAL
                                     iv_action            TYPE string OPTIONAL
                                     it_description       TYPE string_table OPTIONAL
                                     it_response          TYPE string_table OPTIONAL
                                     iv_value             TYPE string OPTIONAL
                                     iv_doc_count         TYPE string OPTIONAL
                                     iv_company           TYPE string OPTIONAL
                           EXPORTING ev_error             TYPE abap_boolean.
ENDCLASS.



CLASS ZCL_INSTRU_EVENT_CLASS IMPLEMENTATION.


  METHOD constructor.

    IF iv_guid IS INITIAL.

      me->get_guid(
        RECEIVING
          ro_guid = gv_guid
      ).
    ELSE.
*      gv_guid = iv_guid.
      gv_guid = iv_guid.
    ENDIF.

    IF iv_event_counter IS NOT INITIAL.
      gv_event_counter = iv_event_counter.
    ENDIF.


    IF sy-batch = 'X'.
      gv_bg_run = abap_true.
    ENDIF.



*    gv_cprog = sy-cprog.
**    get_auth_token( ).
*    gv_s_environment = sy-sysid.
*    gv_s_addon_v = 'SAPK-100COINCLR'.


  ENDMETHOD.


  METHOD convert_to_json.
    CHECK gv_log_event EQ abap_true.
    IF gt_event_data IS NOT INITIAL.
      ev_data_json = /ui2/cl_json=>serialize( data = gt_event_data
                                  pretty_name = /ui2/cl_json=>pretty_mode-camel_case ).

      DATA(lv_len) = strlen( ev_data_json ).
      lv_len = lv_len - 2.
      ev_data_json = ev_data_json+1(lv_len).
    ENDIF.
  ENDMETHOD.


  METHOD get_guid.

    DATA: l_uuid_16  TYPE sysuuid_x16.
    DATA: oref       TYPE REF TO cx_uuid_error.

      TRY.
          l_uuid_16 = cl_system_uuid=>create_uuid_x16_static( ).
        CATCH cx_uuid_error INTO oref.
          l_uuid_16 = '0'.
      ENDTRY.

      TRY.
          cl_system_uuid=>convert_uuid_x16_static( EXPORTING uuid = l_uuid_16
                                                   IMPORTING uuid_c22 = gv_guid ).

        CATCH cx_uuid_error INTO oref. "#EC NEEDED
      ENDTRY.
      ro_guid = gv_guid.

  ENDMETHOD.


  METHOD get_guid1.

 ro_guid1 = gv_guid.

  ENDMETHOD.


  METHOD get_timestamp_iso.

    DATA(lv_iso) = iv_iso.
    DATA lv_timestamp TYPE timestampl.
    GET TIME STAMP FIELD lv_timestamp.
    DATA(lv_timestamp_iso) = |{ lv_timestamp TIMESTAMP = ISO  }|.
    IF lv_iso IS NOT INITIAL.
      eo_iso_timestamp = lv_timestamp_iso.
      SPLIT eo_iso_timestamp AT ',' INTO DATA(lv_x) DATA(lv_y).
      eo_iso_timestamp = lv_x && '.' && lv_y(3) && 'Z'.
    ELSE.
      eo_timestamp = lv_timestamp.
    ENDIF.

  ENDMETHOD.


  METHOD log_end.

    DATA:lv_time_diff TYPE string.
    CHECK gv_log_event EQ abap_true.
    "Get current timestamp(time of logging end event)
    me->get_timestamp_iso(
      IMPORTING
        eo_timestamp     =    DATA(lv_current_timestamp) " UTC Time Stamp in Short Form (YYYYMMDDhhmmss)
    ).
    "Get total number of rows in event tracker
    DATA(lv_latest_event) = lines( gt_event_tracker ). "DESCRIBE TABLE gt_event_tracker LINES DATA(lv_latest_event).
    "Read latest logged entry from event tracker
    READ TABLE gt_event_tracker INTO DATA(ls_event_tracker) INDEX lv_latest_event.

    lv_time_diff = lv_current_timestamp - ls_event_tracker-timestamp.

    me->log_event_data(
      EXPORTING
        iv_node_id           =   iv_node_id
        iv_node_type         =   iv_node_type
        iv_workflow_id       =   iv_workflow_id  " WORKFLOW ID
        iv_category          =   gc_cat_measurement
        iv_action            =   iv_action
        iv_value             =   lv_time_diff  " LV_TIME_DIFF is already TYPE string; CONV is rejected as redundant
        iv_doc_count         =   iv_doc_count
        it_description       =   it_description
    ).
    DELETE gt_event_tracker INDEX lv_latest_event.

  ENDMETHOD.


  METHOD log_error.
    CONSTANTS:lc_failed(6) TYPE c    VALUE 'FAILED'.
    me->log_event_data(

        iv_node_id           =   iv_node_id
        iv_node_type         =   iv_node_type
        iv_erp_document_id   =   iv_erp_document_id
        iv_erp_document_type =   iv_erp_document_type
        iv_company           =   iv_company
        iv_workflow_id       =   iv_workflow_id  " WORKFLOW ID
        iv_category          =   gc_cat_error
        iv_action            =   iv_action
        it_description       =   it_description
        it_response          =   it_response
        iv_value             =   iv_value  " numeric value being measured(Count of data)
        iv_doc_count         =   iv_doc_count
    ).

    SELECT SINGLE * FROM ztrecon_status
            WHERE pan = @iv_node_id AND
                  guid    = @gv_guid
                  INTO @DATA(ls_db_recon_st).
    IF sy-subrc EQ 0 AND ls_db_recon_st IS NOT INITIAL.
      ls_db_recon_st-overall_status = lc_failed.
      MODIFY ztrecon_status  FROM @ls_db_recon_st.
    ENDIF.

  ENDMETHOD.


  METHOD log_event_data.

    DATA:lv_description TYPE string,
         lv_response    TYPE string.

    CHECK gv_log_event EQ abap_true.

    APPEND INITIAL LINE TO gt_event_data ASSIGNING FIELD-SYMBOL(<lfs_event_data>).
    <lfs_event_data>-workspace_id   = gv_workspace_id.
    <lfs_event_data>-environment    = gv_s_environment.
    <lfs_event_data>-erp            = gc_erp.
    <lfs_event_data>-guid           = gv_guid.
    <lfs_event_data>-erp_version    = gv_s_erp_version.
    <lfs_event_data>-addon_version  = gv_s_addon_v.
    <lfs_event_data>-erp_document_type  = iv_erp_document_type.
    <lfs_event_data>-erp_document_id    = iv_erp_document_id.
    <lfs_event_data>-workflow_id        = iv_workflow_id.
    <lfs_event_data>-node_id            = iv_node_id.
    <lfs_event_data>-company            = iv_company.
    <lfs_event_data>-node_type          = iv_node_type.
    <lfs_event_data>-category           = iv_category.
    <lfs_event_data>-action             = iv_action.

    LOOP AT it_description INTO DATA(ls_description).
      IF lv_description IS NOT INITIAL.
        lv_description = |{ lv_description }| & | | & |{ ls_description }|.
      ELSE.
        lv_description = ls_description.
      ENDIF.
    ENDLOOP.

    <lfs_event_data>-description        = lv_description.
    <lfs_event_data>-value              = iv_value.
    <lfs_event_data>-doc_count          = iv_doc_count.
    DATA(lv_timestamp_iso) = get_timestamp_iso( iv_iso = abap_true ).
    <lfs_event_data>-event_timestamp    = lv_timestamp_iso.
    <lfs_event_data>-erp_user_id        = sy-uname.
    <lfs_event_data>-background_flag    = gv_bg_run.
    <lfs_event_data>-program_name       = gv_cprog.

    APPEND INITIAL LINE TO gt_db_table ASSIGNING FIELD-SYMBOL(<lfs_db_table>).
    <lfs_db_table>-entry_date = cl_abap_context_info=>get_system_date( ).
*    GET TIME.
    <lfs_db_table>-entry_time = cl_abap_context_info=>get_system_time( ).
    me->get_timestamp_iso(
      IMPORTING
        eo_timestamp     =  DATA(lv_timestamp)   " UTC Time Stamp in Short Form (YYYYMMDDhhmmss)
    ).

    <lfs_db_table>-timestamp      = lv_timestamp.
    <lfs_db_table>-guid           = gv_guid.
    gv_event_counter              = gv_event_counter +  1.
    <lfs_db_table>-event_counter  = gv_event_counter.
    <lfs_db_table>-pan            = iv_node_id.
    <lfs_db_table>-company        = iv_company.
    <lfs_db_table>-workflow_id    = iv_workflow_id.
    <lfs_db_table>-guid           = gv_guid.
    <lfs_db_table>-category       = iv_category.
    <lfs_db_table>-action         = iv_action.

    LOOP AT it_response INTO DATA(ls_response).
      lv_response = |{ lv_response }| & || & |{ ls_response }|.
    ENDLOOP.

    <lfs_db_table>-response = lv_response.
    <lfs_event_data>-response = lv_response.
    <lfs_db_table>-doc_count      = iv_doc_count.
    <lfs_db_table>-value          = iv_value.
    <lfs_db_table>-error_description    = lv_description.
    me->convert_to_json(
      IMPORTING
        ev_data_json = <lfs_db_table>-event_data
    ).

    <lfs_db_table>-user_id = sy-uname.
    <lfs_db_table>-background_flag    = gv_bg_run.
*    if gv_cprog eq = ''
    <lfs_db_table>-program_name       = gv_cprog.

    update_db_table(
      IMPORTING
        ev_error =    ev_error " General Flag
    ).


  ENDMETHOD.


  METHOD log_measurement.

    CONSTANTS:lc_success(8)               TYPE c    VALUE 'SUCCESS',
              lc_failure(7)               TYPE c    VALUE 'FAILURE',
              lc_in_progress(11)          TYPE c    VALUE 'IN_PROGRESS',
              lc_completed(9)             TYPE c    VALUE 'COMPLETED',
              lc_na(2)                    TYPE c    VALUE 'NA',
              lc_workflow_completed(19)   TYPE c    VALUE 'WORKFLOW_COMPLETED',
              lc_workflow_in_progress(20) TYPE c    VALUE 'WORKFLOW_IN_PROGRESS',
              lc_workflow_failed(15)      TYPE c    VALUE 'WORKFLOW_FAILED'.
    DATA:ls_recon_st TYPE ztrecon_status.
    CHECK gv_log_event EQ abap_true.
    me->log_event_data(
      EXPORTING
        iv_node_id           =   iv_node_id
        iv_node_type         =   iv_node_type
        iv_company           =   iv_company
        iv_workflow_id       =   iv_workflow_id  " WORKFLOW ID
        iv_category          =   gc_cat_measurement
        iv_action            =   iv_action
        iv_value             =   iv_value  " numeric value being measured(Count of data)
        iv_doc_count         =   iv_doc_count
        it_description       =   it_description
    ).
    IF iv_checkpoint_event EQ abap_true AND is_recon_st IS NOT INITIAL.
      SELECT SINGLE * FROM ztrecon_status
        WHERE pan = @iv_node_id AND
              guid    = @gv_guid
              INTO @DATA(ls_db_recon_st).
      READ TABLE it_description INTO DATA(ls_description) INDEX 1.
      IF sy-subrc EQ 0.
        DATA(lv_desc) = ls_description.
      ENDIF.
      IF iv_value IS NOT INITIAL.
        DATA(lv_val) = iv_value.
      ENDIF.
      IF iv_doc_count IS NOT INITIAL.
        DATA(lv_count) = iv_doc_count.
      ENDIF.

      CASE abap_true.

        WHEN is_recon_st-created_at_f.
          ls_db_recon_st-pan = iv_node_id.
          ls_db_recon_st-guid    = gv_guid.
          ls_db_recon_st-overall_status = lc_in_progress.
          GET TIME STAMP FIELD DATA(lv_timestamp).
          ls_db_recon_st-created_at = lv_timestamp.

        WHEN is_recon_st-overall_status_f.
          ls_db_recon_st-overall_status = lc_completed.

        WHEN is_recon_st-presigned_url_status_f.
          IF lv_val EQ '200'.
            ls_db_recon_st-presigned_url_status = lc_success.
          ELSE.
            ls_db_recon_st-presigned_url_status = lc_failure.
          ENDIF.

        WHEN is_recon_st-workflow_id_f.
          ls_db_recon_st-workflow_id = iv_workflow_id.

        WHEN is_recon_st-workflow_status_f.
          ls_db_recon_st-workflow_status = lv_desc.

        WHEN is_recon_st-ingestion_status_f.
          IF ls_db_recon_st-presigned_url_status EQ lc_failure.
            ls_db_recon_st-ingestion_status = lc_failure.
          ELSE.
            IF ls_db_recon_st-workflow_status EQ lc_workflow_completed OR
               ls_db_recon_st-workflow_status EQ lc_workflow_failed.
              IF lv_desc IS INITIAL.
                ls_db_recon_st-ingestion_status = lc_success.
              ELSE.
                ls_db_recon_st-ingestion_status = lv_desc.
              ENDIF.
            ENDIF.
          ENDIF.

        WHEN is_recon_st-ing_err_down_status_f.
          IF lv_val EQ '200'.
            ls_db_recon_st-ing_err_down_status = lc_success.
          ELSE.
            ls_db_recon_st-ing_err_down_status = lc_failure.
          ENDIF.

        WHEN is_recon_st-ing_err_upd_status_f.
          IF ls_db_recon_st-ing_err_down_status EQ lc_success.
            IF lv_count IS NOT INITIAL.
              ls_db_recon_st-ing_err_upd_status = lc_success.
            ELSE.
              ls_db_recon_st-ing_err_upd_status = lc_failure.
            ENDIF.
          ENDIF.

        WHEN is_recon_st-recon_status_f.
          IF lv_desc IS NOT INITIAL.
            ls_db_recon_st-recon_status = lv_desc.
          ENDIF.

        WHEN is_recon_st-recon_rslt_down_status_f.
          IF lv_val EQ '200'.
            ls_db_recon_st-recon_rslt_down_status = lc_success.
          ELSE.
            ls_db_recon_st-recon_rslt_down_status = lc_failure.
          ENDIF.

        WHEN is_recon_st-recon_rslt_upd_status_f.
          IF lv_count IS NOT INITIAL.
            ls_db_recon_st-recon_rslt_upd_status = lc_success.
          ELSE.
            ls_db_recon_st-recon_rslt_upd_status = lc_failure.
          ENDIF.
        WHEN OTHERS.
      ENDCASE.
      GET TIME STAMP FIELD lv_timestamp.
      ls_db_recon_st-updated_at = lv_timestamp.
      MODIFY ztrecon_status FROM @ls_db_recon_st.
    ENDIF.

  ENDMETHOD.


  METHOD log_start.
    CHECK gv_log_event EQ abap_true.
    APPEND INITIAL LINE TO gt_event_tracker ASSIGNING FIELD-SYMBOL(<lfs_event_tracker>).
    me->get_timestamp_iso(
      IMPORTING
        eo_timestamp     =   <lfs_event_tracker>-timestamp   " UTC Time Stamp in Short Form (YYYYMMDDhhmmss)
    ).
    me->log_event_data(
        iv_node_id           =   iv_node_id
        iv_node_type         =   iv_node_type
        iv_company           =   iv_company
        iv_workflow_id       =   iv_workflow_id  " WORKFLOW ID
        iv_category          =   gc_cat_measurement
        iv_action            =   iv_action
        iv_value             =   iv_value  " numeric value being measured(Count of data)
        iv_doc_count         =   iv_doc_count
        it_description       =   it_description
    ).


  ENDMETHOD.


  METHOD log_telemetry.

    CONSTANTS:lc_success(8)               TYPE c    VALUE 'SUCCESS',
              lc_failure(7)               TYPE c    VALUE 'FAILURE',
              lc_in_progress(11)          TYPE c    VALUE 'IN_PROGRESS',
              lc_completed(9)             TYPE c    VALUE 'COMPLETED',
              lc_failed(6)                TYPE c    VALUE 'FAILED',
              lc_na(2)                    TYPE c    VALUE 'NA',
              lc_workflow_completed(19)   TYPE c    VALUE 'WORKFLOW_COMPLETED',
              lc_workflow_in_progress(20) TYPE c    VALUE 'WORKFLOW_IN_PROGRESS',
              lc_workflow_failed(15)      TYPE c    VALUE 'WORKFLOW_FAILED'.
    DATA:ls_recon_st TYPE ztrecon_status.
    CHECK gv_log_event EQ abap_true.

    me->log_event_data(
      EXPORTING
        iv_node_id           =   iv_node_id
        iv_node_type         =   iv_node_type
        iv_company           =   iv_company
        iv_erp_document_id   =   iv_erp_document_id
        iv_erp_document_type =   iv_erp_document_type
        iv_workflow_id       =   iv_workflow_id  " WORKFLOW ID
        iv_category          =   gc_cat_telemetry
        iv_action            =   iv_action
        it_description       =   it_description
        it_response          =   it_response
        iv_value             =   iv_value  " numeric value being measured(Count of data)
        iv_doc_count         =   iv_doc_count
    ).

    IF iv_checkpoint_event EQ abap_true AND is_recon_st IS NOT INITIAL.
      SELECT SINGLE * FROM ztrecon_status
        WHERE pan     = @iv_node_id AND
              guid    = @gv_guid
              INTO @DATA(ls_db_recon_st).
      READ TABLE it_description INTO DATA(ls_description) INDEX 1.
      IF sy-subrc EQ 0.
        DATA(lv_desc) = ls_description.
      ENDIF.

      IF iv_value IS NOT INITIAL.
        DATA(lv_val) = iv_value.
        CONDENSE lv_val.
      ENDIF.
      IF iv_doc_count IS NOT INITIAL.
        DATA(lv_count) = iv_doc_count.
      ENDIF.

      CASE abap_true.
        WHEN is_recon_st-created_at_f.
          ls_db_recon_st-pan = iv_node_id.
          ls_db_recon_st-company = iv_company.
          ls_db_recon_st-guid    = gv_guid.
          ls_db_recon_st-overall_status = lc_in_progress.
          GET TIME STAMP FIELD DATA(lv_timestamp).
          ls_db_recon_st-created_at = lv_timestamp.

        WHEN is_recon_st-overall_status_f.
          ls_db_recon_st-overall_status = lc_completed.

        WHEN is_recon_st-presigned_url_status_f.
          IF lv_val EQ '200'.
            ls_db_recon_st-presigned_url_status = lc_success.
          ELSE.
            ls_db_recon_st-presigned_url_status = lc_failure.
          ENDIF.

        WHEN is_recon_st-workflow_id_f.
          ls_db_recon_st-workflow_id = iv_workflow_id.

        WHEN is_recon_st-workflow_status_f.
          ls_db_recon_st-workflow_status = lv_desc.

        WHEN is_recon_st-ingestion_status_f.
          IF ls_db_recon_st-presigned_url_status EQ lc_failure.
            ls_db_recon_st-ingestion_status = lc_failure.
          ELSE.
            IF ls_db_recon_st-workflow_status EQ lc_workflow_completed OR
               ls_db_recon_st-workflow_status EQ lc_workflow_failed.
              IF lv_desc IS INITIAL.
                ls_db_recon_st-ingestion_status = lc_success.
              ELSE.
                ls_db_recon_st-ingestion_status = lv_desc.
              ENDIF.
            ENDIF.
          ENDIF.

        WHEN is_recon_st-ing_err_down_status_f.
          IF lv_val EQ '200'.
            ls_db_recon_st-ing_err_down_status = lc_success.
          ELSE.
            ls_db_recon_st-ing_err_down_status = lc_failure.
          ENDIF.

        WHEN is_recon_st-ing_err_upd_status_f.
          IF ls_db_recon_st-ing_err_down_status EQ lc_success.
            IF lv_count IS NOT INITIAL.
              ls_db_recon_st-ing_err_upd_status = lc_success.
            ELSE.
              ls_db_recon_st-ing_err_upd_status = lc_failure.
            ENDIF.
          ENDIF.

        WHEN is_recon_st-recon_status_f.
          IF lv_desc IS NOT INITIAL.
            ls_db_recon_st-recon_status = lv_desc.
          ENDIF.

        WHEN is_recon_st-recon_rslt_down_status_f.
          IF lv_val EQ '200'.
            ls_db_recon_st-recon_rslt_down_status = lc_success.
          ELSE.
            ls_db_recon_st-recon_rslt_down_status = lc_failure.
          ENDIF.

        WHEN is_recon_st-recon_rslt_upd_status_f.
          IF lv_count IS NOT INITIAL.
            ls_db_recon_st-recon_rslt_upd_status = lc_success.
          ELSE.
            ls_db_recon_st-recon_rslt_upd_status = lc_failure.
          ENDIF.
        WHEN OTHERS.
      ENDCASE.

      GET TIME STAMP FIELD lv_timestamp.
      ls_db_recon_st-updated_at = lv_timestamp.
      IF ls_db_recon_st-created_at IS NOT INITIAL.
        ls_db_recon_st-time_elapsed = ls_db_recon_st-updated_at - ls_db_recon_st-created_at.
        MODIFY ztrecon_status FROM @ls_db_recon_st.
      ENDIF.
    ENDIF.



  ENDMETHOD.


  METHOD update_db_table.

    CHECK gv_log_event EQ abap_true.

    " Inside a RAP LUW this method may not touch the database. Hold the
    " rows and let FLUSH write them in the save phase.
    IF gv_defer EQ abap_true.
      APPEND LINES OF gt_db_table TO gt_pending.
      CLEAR: gt_db_table,
             gt_event_data.
      RETURN.
    ENDIF.

    INSERT ztevent_log FROM TABLE @gt_db_table.
    IF sy-subrc NE 0.
      ev_error = abap_true.
    ELSE.
      COMMIT WORK AND WAIT.
    ENDIF.
    CLEAR:gt_db_table,
          gt_event_data.

  ENDMETHOD.


  METHOD flush.
    " No COMMIT WORK: this runs in the save phase of a RAP LUW, which
    " commits for us. A COMMIT here would be the same contract violation
    " one layer further on.
    IF gt_pending IS INITIAL.
      RETURN.
    ENDIF.

    INSERT ztevent_log FROM TABLE @gt_pending.
    CLEAR gt_pending.
  ENDMETHOD.


  METHOD discard.
    CLEAR gt_pending.
  ENDMETHOD.

ENDCLASS.
