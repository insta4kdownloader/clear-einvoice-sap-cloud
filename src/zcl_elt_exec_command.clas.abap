CLASS zcl_elt_exec_command DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    TYPES : BEGIN OF ty_logs,
              im_log_no_command              TYPE string,
              im_command_id              TYPE string,
              im_event_count                 TYPE string,
              im_file_name                   TYPE string,
              im_extraction_empty_metadata   TYPE string,
              im_extraction_empty_command_id TYPE string,
              im_send_api_fail_gen_prsi      TYPE string,
              im_rcv_api_gen_prsi_ret_code   TYPE string,
              im_rcv_api_gen_prsi_resp       TYPE string,
              im_rcv_api_gen_prsi_resp_init  TYPE string,
              im_rcv_api_gen_prsi_ret_code_f TYPE string,
              im_abap_response               TYPE string,
              im_status_code                 TYPE string,
              im_reason                      TYPE string,
              im_pre_sign_url                TYPE string,
              im_gen_pre_sign_url            TYPE string,
              im_ingestfile_status_code      TYPE string,
              im_ingestfile_reason           TYPE string,
              im_rcv_api_upload_ret_code_f   TYPE string,
              im_rcv_api_upload_ret_code     TYPE string,
              im_send_api_fail_upload        TYPE string,
              im_create_url_fail_upload      TYPE string,
              im_postcomm_status_code        TYPE string,
              im_postcomm_reason             TYPE string,
              im_post_comm_url_not_maint     TYPE string,
              im_create_url_fail_post_comm   TYPE string,
              im_send_api_fail_post_comm     TYPE string,
              im_rcv_api_post_com_ret_code_f TYPE string,
            END OF ty_logs.

    DATA : im_logs TYPE STANDARD TABLE OF ty_logs.

    DATA : im_erp_config          TYPE string,
           im_hostname            TYPE string,
           im_auth_token          TYPE string,
           im_erp_instance_config TYPE string.

    INTERFACES if_oo_adt_classrun.
    METHODS elt_exe_command EXPORTING ex_log_no_command TYPE string.

  PROTECTED SECTION.
  PRIVATE SECTION.

ENDCLASS.



CLASS ZCL_ELT_EXEC_COMMAND IMPLEMENTATION.


  METHOD elt_exe_command.

    DATA :obj_exec_comm TYPE REF TO zcl_elt.
    CREATE OBJECT obj_exec_comm.
    obj_exec_comm->elt_exec_command(
          IMPORTING
            ex_log_no_command = DATA(im_log_no_command)
        ).
    ex_log_no_command = im_log_no_command.
  ENDMETHOD.


  METHOD if_oo_adt_classrun~main.

    DATA :obj_exec_comm TYPE REF TO zcl_elt.
    CREATE OBJECT obj_exec_comm.
*    DATA(obj_exec_comm) = zcl_elt=>create_instance( ).

    obj_exec_comm->elt_exec_command(
      IMPORTING
        ex_log_no_command              = DATA(im_log_no_command)
        ex_log_command_id              = DATA(im_command_id)
        ex_event_count                 = DATA(im_event_count)
        ex_file_name                   = DATA(im_file_name)
        gc_extraction_empty_metadata   = DATA(im_extraction_empty_metadata)
        gc_extraction_empty_command_id = DATA(im_extraction_empty_command_id)
        ex_send_api_fail_gen_prsi      = DATA(im_send_api_fail_gen_prsi)
        ex_rcv_api_gen_prsi_ret_code   = DATA(im_rcv_api_gen_prsi_ret_code)
        ex_rcv_api_gen_prsi_resp       = DATA(im_rcv_api_gen_prsi_resp)
        ex_rcv_api_gen_prsi_resp_init  = DATA(im_rcv_api_gen_prsi_resp_init)
        ex_rcv_api_gen_prsi_ret_code_f = DATA(im_rcv_api_gen_prsi_ret_code_f)
        ex_abap_response               = DATA(im_abap_response)
        ex_status_code                 = DATA(im_status_code)
        ex_reason                      = DATA(im_reason)
        ex_pre_sign_url                = DATA(im_pre_sign_url)
        ex_gen_pre_sign_url            = DATA(im_gen_pre_sign_url)
        ex_ingestfile_status_code      = DATA(im_ingestfile_status_code)
        ex_ingestfile_reason           = DATA(im_ingestfile_reason)
        ex_rcv_api_upload_ret_code_f   = DATA(im_rcv_api_upload_ret_code_f)
        ex_rcv_api_upload_ret_code     = DATA(im_rcv_api_upload_ret_code)
        ex_send_api_fail_upload        = DATA(im_send_api_fail_upload)
        ex_create_url_fail_upload      = DATA(im_create_url_fail_upload)
        ex_postcomm_status_code        = DATA(im_postcomm_status_code)
        ex_postcomm_reason             = DATA(im_postcomm_reason)
        ex_post_comm_url_not_maint     = DATA(im_post_comm_url_not_maint)
        ex_create_url_fail_post_comm   = DATA(im_create_url_fail_post_comm)
        ex_send_api_fail_post_comm     = DATA(im_send_api_fail_post_comm)
        ex_rcv_api_post_com_ret_code_f = DATA(im_rcv_api_post_com_ret_code_f)
        et_logs                        = im_logs
    ).

    im_erp_config = obj_exec_comm->get_erp_config( ).
    im_hostname   = obj_exec_comm->get_hostname( ).
    im_auth_token = obj_exec_comm->get_auth_token( ).
    im_erp_instance_config = obj_exec_comm->get_erp_instance_id( ).


  ENDMETHOD.
ENDCLASS.
