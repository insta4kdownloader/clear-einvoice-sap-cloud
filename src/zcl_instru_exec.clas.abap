CLASS zcl_instru_exec DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    DATA : lv_date  TYPE c LENGTH 200,
           lv_time  TYPE c LENGTH 200,
           lv_uname TYPE c LENGTH 200.

    INTERFACES if_apj_rt_run .
    INTERFACES if_oo_adt_classrun.

    DATA: p_send   TYPE abap_boolean,
          p_del    TYPE abap_boolean,
          p_send_s TYPE abap_boolean,
          p_send_d TYPE abap_boolean,
          p_sent   TYPE abap_boolean,
          p_del_s  TYPE abap_boolean,
          p_del_d  TYPE abap_boolean,
          p_del_f  TYPE abap_boolean,
          p_del_a  TYPE abap_boolean,
          p_days   TYPE zde_int3,
          s_date   TYPE RANGE OF d,
          s_time   TYPE RANGE OF t,
          s_uname  TYPE RANGE OF sy-uname.

    DATA:gs_event_log TYPE ztevent_log.

    DATA: lv_db_cnt1          TYPE string,
          lv_total_data_cnt1  TYPE string,
          lv_total_data_sent1 TYPE string,
          lv_del_cnt1         TYPE string.

    DATA: lv_db_cnt2          TYPE string,
          lv_total_data_cnt2  TYPE string,
          lv_total_data_sent2 TYPE string,
          lv_del_cnt2         TYPE string.






  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS ZCL_INSTRU_EXEC IMPLEMENTATION.


  METHOD if_apj_rt_run~execute.

    TRY.

        DATA lo_free TYPE REF TO if_bali_free_text_setter.

        DATA(lo_log) = cl_bali_log=>create( ).

        DATA(lo_header) = cl_bali_header_setter=>create( object      = 'ZAJL_ELT_EXECUTION'
                                                         subobject   = 'JOB_LOG_ELT'
                                                         external_id = cl_system_uuid=>create_uuid_c32_static( ) ).
        lo_log->set_header( lo_header ).

        IF p_send EQ abap_true.
          DATA(go_api_instance) = NEW zcl_instru_api_class( ).

          DATA(im_auth_token) = go_api_instance->get_auth_token( ).
          DATA(im_url) = go_api_instance->get_account_settings( ).

          SELECT SINGLE * FROM i_businessuserbasic WHERE userid = @sy-uname INTO @DATA(wa_user).


          IF im_auth_token IS NOT INITIAL.

            lo_free = cl_bali_free_text_setter=>create( severity = if_bali_constants=>c_severity_status text = |Job Started| ).
            lo_log->add_item( lo_free ).
            lo_free = cl_bali_free_text_setter=>create( severity = if_bali_constants=>c_severity_status text = |Program Started : ZCL_INSTRU_EXEC, User Name { wa_user-personfullname }| ).
            lo_log->add_item( lo_free ).
            lo_free = cl_bali_free_text_setter=>create( severity = if_bali_constants=>c_severity_status text = |{ im_auth_token }| ).
            lo_log->add_item( lo_free ).
            lo_free = cl_bali_free_text_setter=>create( severity = if_bali_constants=>c_severity_status text = |Program Ended : ZCL_INSTRU_EXEC| ).
            lo_log->add_item( lo_free ).
            lo_free = cl_bali_free_text_setter=>create( severity = if_bali_constants=>c_severity_status text = |Job Finished| ).
            lo_log->add_item( lo_free ).

          ELSEIF im_url IS NOT INITIAL.

            lo_free = cl_bali_free_text_setter=>create( severity = if_bali_constants=>c_severity_status text = |Job Started| ).
            lo_log->add_item( lo_free ).
            lo_free = cl_bali_free_text_setter=>create( severity = if_bali_constants=>c_severity_status text = |Program Started : ZCL_INSTRU_EXEC, User Name { wa_user-personfullname }| ).
            lo_log->add_item( lo_free ).
            lo_free = cl_bali_free_text_setter=>create( severity = if_bali_constants=>c_severity_status text = |{ im_url }| ).
            lo_log->add_item( lo_free ).
            lo_free = cl_bali_free_text_setter=>create( severity = if_bali_constants=>c_severity_status text = |Program Ended : ZCL_INSTRU_EXEC| ).
            lo_log->add_item( lo_free ).
            lo_free = cl_bali_free_text_setter=>create( severity = if_bali_constants=>c_severity_status text = |Job Finished| ).
            lo_log->add_item( lo_free ).

          ENDIF.

          IF s_date IS INITIAL.
            s_date  = VALUE #( (  sign = 'I'
                       option = 'BT'
                       low = cl_abap_context_info=>get_system_date( )
                       high = cl_abap_context_info=>get_system_date( )
                        ) ).
          ENDIF.
          IF s_time IS INITIAL.
            s_time  = VALUE #( (  sign = 'I'
                         option = 'EQ'
                         low = cl_abap_context_info=>get_system_time( )
                          ) ).
          ENDIF.

          IF s_uname IS INITIAL.
            s_uname  = VALUE #( (  sign = 'I'
                         option = 'EQ'
                         low = sy-uname
                          ) ).
          ENDIF.
          go_api_instance->send_data(
            EXPORTING
            ir_entry_date      = s_date[]
            ir_entry_time      = s_time[]
            ir_uname           = s_uname[]
            IMPORTING
              ev_db_cnt           = DATA(lv_db_cnt)
              ev_total_data_cnt   = DATA(lv_total_data_cnt)
              ev_total_data_sent  = DATA(lv_total_data_sent)
          ).

          IF lv_db_cnt IS NOT INITIAL.
            lv_db_cnt1 = lv_db_cnt.
            CONCATENATE 'Total rows updated-' lv_db_cnt1 INTO lv_db_cnt2.
          ENDIF.

          IF lv_total_data_cnt IS NOT INITIAL.
            lv_total_data_cnt1 =  lv_total_data_cnt.
            CONCATENATE 'Total data to be sent-' lv_total_data_cnt1 INTO lv_total_data_cnt2.
          ENDIF.

          IF lv_total_data_sent IS NOT INITIAL.
            lv_total_data_sent1 = lv_total_data_sent.
            CONCATENATE 'Total data sent successfully-' lv_total_data_sent1 INTO lv_total_data_sent2.
          ENDIF.

          IF  lv_db_cnt2 IS NOT INITIAL OR lv_total_data_cnt2 IS NOT INITIAL OR lv_total_data_sent2 IS NOT INITIAL.
*Commented by Ashish - program giving run time error. Please check.
*            UPDATE ztevent_log SET total_data_count = @lv_total_data_cnt2,
*                   total_data_sent = @lv_total_data_sent2
*                          WHERE entry_date IN @s_date[] AND
*                                entry_time IN @s_time[] AND
*                                user_id IN @s_uname[].

            IF sy-subrc = 0.
            READ TABLE s_date INTO DATA(wa_date) INDEX 1.
            READ TABLE s_time INTO DATA(wa_time) INDEX 1.
            READ TABLE s_uname INTO DATA(wa_uname) INDEX 1.

            CONCATENATE wa_date-low+6(2) '-' wa_date-low+4(2) '-' wa_date-low+0(4) INTO lv_date.
            CONCATENATE wa_time-low+0(2) ':' wa_time-low+2(2) ':' wa_time-low+4(2) INTO lv_time.

            lo_free = cl_bali_free_text_setter=>create( severity = if_bali_constants=>c_severity_status text = |Job Started| ).
            lo_log->add_item( lo_free ).
            lo_free = cl_bali_free_text_setter=>create( severity = if_bali_constants=>c_severity_status text = |Program Started : ZCL_INSTRU_EXEC, User Name { wa_user-personfullname }| ).
            lo_log->add_item( lo_free ).
            IF lv_db_cnt2 IS NOT INITIAL.
              lo_free = cl_bali_free_text_setter=>create( severity = if_bali_constants=>c_severity_status text = |{ lv_db_cnt2 }| ).
              lo_log->add_item( lo_free ).
            ENDIF.
            IF lv_total_data_cnt2 IS NOT INITIAL.
              lo_free = cl_bali_free_text_setter=>create( severity = if_bali_constants=>c_severity_status text = |{ lv_total_data_cnt2 }| ).
              lo_log->add_item( lo_free ).
            ENDIF.
            IF lv_total_data_sent2 IS NOT INITIAL.
              lo_free = cl_bali_free_text_setter=>create( severity = if_bali_constants=>c_severity_status text = |{ lv_total_data_sent2 }| ).
              lo_log->add_item( lo_free ).
            ENDIF.
            lo_free = cl_bali_free_text_setter=>create( severity = if_bali_constants=>c_severity_status text = |Program Ended : ZCL_INSTRU_EXEC| ).
            lo_log->add_item( lo_free ).
            lo_free = cl_bali_free_text_setter=>create( severity = if_bali_constants=>c_severity_status text = |Job Finished| ).
            lo_log->add_item( lo_free ).

            ENDIF.

            ELSE.

            READ TABLE s_date INTO wa_date INDEX 1.
            READ TABLE s_time INTO wa_time INDEX 1.
            READ TABLE s_uname INTO wa_uname INDEX 1.

            CONCATENATE wa_date-low+6(2) '-' wa_date-low+4(2) '-' wa_date-low+0(4) INTO lv_date.
            CONCATENATE wa_time-low+0(2) ':' wa_time-low+2(2) ':' wa_time-low+4(2) INTO lv_time.

            lo_free = cl_bali_free_text_setter=>create( severity = if_bali_constants=>c_severity_status text = |Job Started| ).
            lo_log->add_item( lo_free ).
            lo_free = cl_bali_free_text_setter=>create( severity = if_bali_constants=>c_severity_status text = |Program Started : ZCL_INSTRU_EXEC, User Name { wa_user-personfullname }| ).
            lo_log->add_item( lo_free ).
            lo_free = cl_bali_free_text_setter=>create( severity = if_bali_constants=>c_severity_error text = |Data Sent Un-successfull - Date: { lv_date } Time: { lv_time } UserName: { wa_uname-low }| ).
            lo_log->add_item( lo_free ).
            lo_free = cl_bali_free_text_setter=>create( severity = if_bali_constants=>c_severity_status text = |Program Ended : ZCL_INSTRU_EXEC| ).
            lo_log->add_item( lo_free ).
            lo_free = cl_bali_free_text_setter=>create( severity = if_bali_constants=>c_severity_status text = |Job Finished| ).
            lo_log->add_item( lo_free ).

          ENDIF.

        ELSEIF p_del EQ abap_true.
          IF p_sent EQ abap_true.
            DELETE FROM ztevent_log WHERE entry_date IN @s_date[] AND
                                               entry_time IN @s_time[] AND
                                               user_id IN @s_uname[] AND
                                               sent_flag EQ @p_sent. "#EC CI_NOFIRST


            IF sy-subrc = 0.
            READ TABLE s_date INTO wa_date INDEX 1.
            READ TABLE s_time INTO wa_time INDEX 1.
            READ TABLE s_uname INTO wa_uname INDEX 1.

            CONCATENATE wa_date-low+6(2) '-' wa_date-low+4(2) '-' wa_date-low+0(4) INTO lv_date.
            CONCATENATE wa_time-low+0(2) ':' wa_time-low+2(2) ':' wa_time-low+4(2) INTO lv_time.

              lo_free = cl_bali_free_text_setter=>create( severity = if_bali_constants=>c_severity_status text = |Job Started| ).
              lo_log->add_item( lo_free ).
              lo_free = cl_bali_free_text_setter=>create( severity = if_bali_constants=>c_severity_status text = |Program Started : ZCL_INSTRU_EXEC, User Name { wa_user-personfullname }| ).
              lo_log->add_item( lo_free ).
              lo_free = cl_bali_free_text_setter=>create( severity = if_bali_constants=>c_severity_status text = |Data Sent Successfull - Date: { lv_date } Time: { lv_time } UserName: { wa_uname-low }| ).
              lo_log->add_item( lo_free ).
              lo_free = cl_bali_free_text_setter=>create( severity = if_bali_constants=>c_severity_status text = |Sent Data Deleted Successfull| ).
              lo_log->add_item( lo_free ).
              lo_free = cl_bali_free_text_setter=>create( severity = if_bali_constants=>c_severity_status text = |Program Ended : ZCL_INSTRU_EXEC| ).
              lo_log->add_item( lo_free ).
              lo_free = cl_bali_free_text_setter=>create( severity = if_bali_constants=>c_severity_status text = |Job Finished| ).
              lo_log->add_item( lo_free ).

            ELSE.
            READ TABLE s_date INTO wa_date INDEX 1.
            READ TABLE s_time INTO wa_time INDEX 1.
            READ TABLE s_uname INTO wa_uname INDEX 1.

            CONCATENATE wa_date-low+6(2) '-' wa_date-low+4(2) '-' wa_date-low+0(4) INTO lv_date.
            CONCATENATE wa_time-low+0(2) ':' wa_time-low+2(2) ':' wa_time-low+4(2) INTO lv_time.

              lo_free = cl_bali_free_text_setter=>create( severity = if_bali_constants=>c_severity_status text = |Job Started| ).
              lo_log->add_item( lo_free ).
              lo_free = cl_bali_free_text_setter=>create( severity = if_bali_constants=>c_severity_status text = |Program Started : ZCL_INSTRU_EXEC, User Name { wa_user-personfullname }| ).
              lo_log->add_item( lo_free ).
              lo_free = cl_bali_free_text_setter=>create( severity = if_bali_constants=>c_severity_error text = |Data Sent Un-successfull - Date: { lv_date } Time: { lv_time } UserName: { wa_uname-low }| ).
              lo_log->add_item( lo_free ).
              lo_free = cl_bali_free_text_setter=>create( severity = if_bali_constants=>c_severity_error text = |Sent Data Deleted Un-successfull| ).
              lo_log->add_item( lo_free ).
              lo_free = cl_bali_free_text_setter=>create( severity = if_bali_constants=>c_severity_status text = |Program Ended : ZCL_INSTRU_EXEC| ).
              lo_log->add_item( lo_free ).
              lo_free = cl_bali_free_text_setter=>create( severity = if_bali_constants=>c_severity_status text = |Job Finished| ).
              lo_log->add_item( lo_free ).

            ENDIF.

          ELSE.
            DELETE FROM ztevent_log WHERE entry_date IN @s_date[] AND
                                             entry_time IN @s_time[] AND
                                             user_id IN @s_uname[]. "#EC CI_NOFIRST

            IF sy-subrc = 0.
            READ TABLE s_date INTO wa_date INDEX 1.
            READ TABLE s_time INTO wa_time INDEX 1.
            READ TABLE s_uname INTO wa_uname INDEX 1.

            CONCATENATE wa_date-low+6(2) '-' wa_date-low+4(2) '-' wa_date-low+0(4) INTO lv_date.
            CONCATENATE wa_time-low+0(2) ':' wa_time-low+2(2) ':' wa_time-low+4(2) INTO lv_time.

              lo_free = cl_bali_free_text_setter=>create( severity = if_bali_constants=>c_severity_status text = |Job Started| ).
              lo_log->add_item( lo_free ).
              lo_free = cl_bali_free_text_setter=>create( severity = if_bali_constants=>c_severity_status text = |Program Started : ZCL_INSTRU_EXEC, User Name { wa_user-personfullname }| ).
              lo_log->add_item( lo_free ).
              lo_free = cl_bali_free_text_setter=>create( severity = if_bali_constants=>c_severity_status text = |Deletion Successfull - Date: { lv_date } Time: { lv_time } UserName: { wa_uname-low }| ).
              lo_log->add_item( lo_free ).
              lo_free = cl_bali_free_text_setter=>create( severity = if_bali_constants=>c_severity_status text = |Program Ended : ZCL_INSTRU_EXEC| ).
              lo_log->add_item( lo_free ).
              lo_free = cl_bali_free_text_setter=>create( severity = if_bali_constants=>c_severity_status text = |Job Finished| ).
              lo_log->add_item( lo_free ).

            ELSE.
            READ TABLE s_date INTO wa_date INDEX 1.
            READ TABLE s_time INTO wa_time INDEX 1.
            READ TABLE s_uname INTO wa_uname INDEX 1.

            CONCATENATE wa_date-low+6(2) '-' wa_date-low+4(2) '-' wa_date-low+0(4) INTO lv_date.
            CONCATENATE wa_time-low+0(2) ':' wa_time-low+2(2) ':' wa_time-low+4(2) INTO lv_time.

              lo_free = cl_bali_free_text_setter=>create( severity = if_bali_constants=>c_severity_status text = |Job Started| ).
              lo_log->add_item( lo_free ).
              lo_free = cl_bali_free_text_setter=>create( severity = if_bali_constants=>c_severity_status text = |Program Started : ZCL_INSTRU_EXEC, User Name { wa_user-personfullname }| ).
              lo_log->add_item( lo_free ).
              lo_free = cl_bali_free_text_setter=>create( severity = if_bali_constants=>c_severity_error text = |Deletion Un-successfull - Date: { lv_date } Time: { lv_time } UserName: { wa_uname-low }| ).
              lo_log->add_item( lo_free ).
              lo_free = cl_bali_free_text_setter=>create( severity = if_bali_constants=>c_severity_status text = |Program Ended : ZCL_INSTRU_EXEC| ).
              lo_log->add_item( lo_free ).
              lo_free = cl_bali_free_text_setter=>create( severity = if_bali_constants=>c_severity_status text = |Job Finished| ).
              lo_log->add_item( lo_free ).

            ENDIF.

          ENDIF.
          IF sy-subrc EQ 0.

          ENDIF.

        ENDIF.

        cl_bali_log_db=>get_instance( )->save_log( log = lo_log assign_to_current_appl_job = abap_true ).

      CATCH cx_bali_runtime.  "#EC NEEDED
      CATCH cx_uuid_error.  "#EC NEEDED
    ENDTRY.

  ENDMETHOD.


  METHOD if_oo_adt_classrun~main.

    IF p_send EQ abap_true.

*      DATA(go_api_instance) = NEW zcl_instru_api_class( ).
      DATA : go_api_instance TYPE REF TO zcl_instru_api_class.
      CREATE OBJECT go_api_instance.
      DATA(im_auth_token) = go_api_instance->get_auth_token( ).
      DATA(im_url) = go_api_instance->get_account_settings( ).
      go_api_instance->get_proxy(
        IMPORTING
          ex_auth_token = DATA(im_proxy_auth)
          ex_url        = DATA(im_proxy_url)
      ).

      IF s_date IS INITIAL.
        s_date  = VALUE #( (  sign = 'I' option = 'BT'
                   low = cl_abap_context_info=>get_system_date( ) high = cl_abap_context_info=>get_system_date( ) ) ).
      ENDIF.
      IF s_time IS INITIAL.
        s_time  = VALUE #( (  sign = 'I' option = 'EQ'
                     low = cl_abap_context_info=>get_system_time( ) ) ).
      ENDIF.

      IF s_uname IS INITIAL.
        s_uname  = VALUE #( (  sign = 'I' option = 'EQ' low = sy-uname ) ).
      ENDIF.

      go_api_instance->send_data(
        EXPORTING
        ir_entry_date      = s_date[]
        ir_entry_time      = s_time[]
        ir_uname           = s_uname[]
        IMPORTING
          ev_db_cnt           = DATA(lv_db_cnt)
          ev_total_data_cnt   = DATA(lv_total_data_cnt)
          ev_total_data_sent  = DATA(lv_total_data_sent)
      ).

      IF lv_db_cnt IS NOT INITIAL.
        lv_db_cnt1 = lv_db_cnt.
        CONCATENATE 'Total rows updated-' lv_db_cnt1 INTO lv_db_cnt2.
      ENDIF.

      IF lv_total_data_cnt IS NOT INITIAL.
        lv_total_data_cnt1 =  lv_total_data_cnt.
        CONCATENATE 'Total data to be sent-' lv_total_data_cnt1 INTO lv_total_data_cnt2.
      ENDIF.

      IF lv_total_data_sent IS NOT INITIAL.
        lv_total_data_sent1 = lv_total_data_sent.
        CONCATENATE 'Total data sent successfully-' lv_total_data_sent1 INTO lv_total_data_sent2.
      ENDIF.
    ELSEIF p_del EQ abap_true.
      IF p_sent EQ abap_true.
        DELETE FROM ztevent_log WHERE entry_date IN @s_date[] AND
                                           entry_time IN @s_time[] AND
                                           user_id IN @s_uname[] AND
                                           sent_flag EQ @p_sent. "#EC CI_NOFIRST
      ELSE.
        DELETE FROM ztevent_log WHERE entry_date IN @s_date[] AND
                                         entry_time IN @s_time[] AND
                                         user_id IN @s_uname[]. "#EC CI_NOFIRST
        DELETE FROM ztrecon_status.                     "#EC CI_NOWHERE
      ENDIF.
      IF sy-subrc EQ 0.

      ENDIF.
    ENDIF.



  ENDMETHOD.
ENDCLASS.
