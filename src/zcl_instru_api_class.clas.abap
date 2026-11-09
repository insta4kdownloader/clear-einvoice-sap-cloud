CLASS zcl_instru_api_class DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

  DATA : im_auth_token TYPE string.


    TYPES:
      ty_r_date  TYPE RANGE OF datum,
      ty_r_time  TYPE RANGE OF uzeit,
      ty_r_uname TYPE RANGE OF syuname
      .

    DATA : gv_s_auth_token  TYPE string,
           gv_proxy_host    TYPE    string,
           gv_proxy_service TYPE    string.


    METHODS send_data IMPORTING ir_entry_date      TYPE ty_r_date OPTIONAL
                                ir_entry_time      TYPE ty_r_time OPTIONAL
                                ir_uname           TYPE ty_r_uname OPTIONAL
                      EXPORTING ev_total_data_cnt  TYPE int4
                                ev_db_cnt          TYPE int4
                                ev_total_data_sent TYPE int4.

    METHODS : get_event_data IMPORTING ir_entry_date       TYPE ty_r_date OPTIONAL
                                       ir_entry_time       TYPE ty_r_time OPTIONAL
                                       ir_uname            TYPE ty_r_uname OPTIONAL
                             RETURNING VALUE(et_event_log) TYPE zt_event_lg_tt.

    METHODS constructor.

*  PROTECTED SECTION.
*  PRIVATE SECTION.

    CONSTANTS : gc_proxy_host     TYPE string VALUE 'PROXY_HOST',
                gc_proxy_service  TYPE string VALUE 'PROXY_SERVICE',
                gc_auth_token     TYPE string VALUE 'X-Cleartax-Auth-Token',
                gc_file_cont_type TYPE string VALUE 'Content-Type'.

    DATA : gv_url TYPE string.
    DATA: go_http_client TYPE REF TO if_web_http_client,
          lr_http_client TYPE REF TO if_web_http_client.

    METHODS : get_auth_token RETURNING VALUE(ex_auth_token) TYPE string.

    METHODS : get_account_settings RETURNING VALUE(ex_account_settings) TYPE string.

    METHODS : get_proxy EXPORTING ex_auth_token TYPE string
                                  ex_url TYPE string.

    METHODS: get_http_instance RETURNING VALUE(eo_http_instance) TYPE REF TO if_web_http_request.

  PROTECTED SECTION.
  PRIVATE SECTION.

ENDCLASS.



CLASS ZCL_INSTRU_API_CLASS IMPLEMENTATION.


  METHOD constructor.

*    get_auth_token( ).
    get_auth_token(
      RECEIVING
        ex_auth_token = im_auth_token
    ).


    get_account_settings( ).
    get_proxy( ).

*    go_http_client = get_http_instance( ).

  ENDMETHOD.


  METHOD get_account_settings.

    SELECT low FROM ztins_config
          WHERE sysid      = @sy-sysid AND
                labeltype  = 'API'
                INTO TABLE @DATA(gt_account_settings).
    IF sy-subrc EQ 0.
      READ TABLE gt_account_settings INTO DATA(ls_account_setting) INDEX 1.
      IF sy-subrc EQ 0.
        gv_url = ls_account_setting-low.
        ELSE.
        ex_account_settings = 'URL not maintainedn'.
        ENDIF.
        ELSE.
        ex_account_settings = 'URL not maintained'.
    ENDIF.
  ENDMETHOD.


  METHOD get_auth_token.

    SELECT low FROM ztins_config
             WHERE sysid   = @sy-sysid AND
                   labeltype  = 'AUTH'
                             INTO TABLE @DATA(gt_account_settings).
    IF sy-subrc EQ 0.
      READ TABLE gt_account_settings INTO DATA(ls_account_setting) INDEX 1.
      IF sy-subrc EQ 0.
        gv_s_auth_token = ls_account_setting-low.
        ELSE.
        ex_auth_token = 'Auth token not maintained'.
      ENDIF.
      ELSE.
      ex_auth_token = 'Auth token not maintained'.
    ENDIF.

  ENDMETHOD.


  METHOD get_event_data.

    DATA:lr_entry_date TYPE RANGE OF datum,
         lr_entry_time TYPE RANGE OF uzeit,
         lr_timestamp  TYPE RANGE OF timestamp,
         lr_created_by TYPE RANGE OF syuname.


    SELECT * FROM ztevent_log
WHERE entry_date   IN @ir_entry_date AND
   entry_time   IN @ir_entry_time AND
   user_id      IN @ir_uname AND
   sent_flag EQ ' '
         INTO TABLE @et_event_log.

  ENDMETHOD.


  METHOD get_http_instance.

*    DATA(lo_request) = lr_http_client->get_http_request( ).
*    lo_request->set_header_fields(  VALUE #(
*            (  name = '~request_method' value = 'GET' )
*            (  name = gc_auth_token  value = CONV #( gv_s_auth_token ) )
*            ( name = gc_file_cont_type value =  'application/json' ) ) ).
*
*            eo_http_instance = lo_request.

  ENDMETHOD.


  METHOD get_proxy.

    SELECT labeltype,
            low FROM ztins_config
           WHERE sysid = @sy-sysid
        INTO TABLE @DATA(gt_account_settings).
    IF sy-subrc EQ 0.
      READ TABLE gt_account_settings INTO DATA(ls_account_setting) WITH KEY labeltype = gc_proxy_host.
      IF sy-subrc EQ 0.
        gv_proxy_host = ls_account_setting-low.
        ELSE.
        ex_url = 'URL not maintained'.
      ENDIF.
      CLEAR ls_account_setting.
      READ TABLE gt_account_settings INTO ls_account_setting WITH KEY labeltype = gc_proxy_service.
      IF sy-subrc EQ 0.
        gv_proxy_service = ls_account_setting-low.
        ELSE.
        ex_auth_token = 'Auth token not maintained'.
      ENDIF.
      ELSE.
      ex_url = 'URL not maintained'.
      ex_auth_token = 'Auth token not maintained'.
    ENDIF.

  ENDMETHOD.


  METHOD send_data.

    DATA:lt_data TYPE string_table,
         lv_data TYPE string.

    DATA(lt_event_data) = get_event_data(
                            EXPORTING
                              ir_entry_date = ir_entry_date
                              ir_entry_time = ir_entry_time
                              ir_uname      = ir_uname
                            ).

*    DESCRIBE TABLE lt_event_data LINES ev_total_data_cnt.
    ev_total_data_cnt = lines( lt_event_data ).

    LOOP AT lt_event_data ASSIGNING FIELD-SYMBOL(<lfs_event_data>).
      IF NOT ( sy-tabix = 1 OR sy-tabix = ev_total_data_cnt ).
        CONCATENATE lv_data <lfs_event_data>-event_data INTO lv_data SEPARATED BY ','.
      ELSEIF sy-tabix = 1.
        lv_data = <lfs_event_data>-event_data.
      ENDIF.
    ENDLOOP.
    CONCATENATE '[' lv_data ']' INTO lv_data.

*    IF go_http_client IS BOUND.

      IF gv_url IS NOT INITIAL.

        TRY.
            lr_http_client = cl_web_http_client_manager=>create_by_http_destination(
                             i_destination = cl_http_destination_provider=>create_by_url( gv_url ) ).
          CATCH cx_web_http_client_error cx_http_dest_provider_error.  "#EC NEEDED
            "handle exception
        ENDTRY.

        DATA(lo_request) = lr_http_client->get_http_request( ).
        lo_request->set_header_fields(  VALUE #(
                (  name = '~request_method' value = 'POST' )
                (  name = gc_auth_token  value = CONV #( gv_s_auth_token ) )
                ( name = gc_file_cont_type value =  'application/json' ) ) ).


        lo_request->append_text(
          data   = lv_data
          length = strlen( lv_data ) ).

        TRY.
            DATA(lv_response) = lr_http_client->execute(
                                i_method  = if_web_http_client=>post ).
          CATCH cx_web_http_client_error.  "#EC NEEDED
        ENDTRY.

        IF sy-subrc <> 0.

        ELSE.
          DATA(lv_json_response) = lv_response->get_text( ).
          DATA(lv_ststus_check) = lv_response->get_status( ).

          IF lv_ststus_check-code EQ '200'.

            LOOP AT lt_event_data ASSIGNING <lfs_event_data>.
              <lfs_event_data>-sent_flag = abap_true.
              ev_total_data_sent = ev_total_data_sent + 1.
            ENDLOOP.

          ENDIF.

        ENDIF.
      ENDIF.

          MODIFY ztevent_log FROM TABLE @lt_event_data.
    IF sy-subrc EQ 0.
      ev_db_cnt = sy-dbcnt.
    ENDIF.
*    ENDIF.

  ENDMETHOD.
ENDCLASS.
