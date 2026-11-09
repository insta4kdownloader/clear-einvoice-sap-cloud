CLASS lhc_ZCDS_CUN_COMP_DETAILS DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR zcds_cun_comp_details RESULT result.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR zcds_cun_comp_details RESULT result.
    METHODS get_global_features FOR GLOBAL FEATURES
      IMPORTING REQUEST requested_features FOR zcds_cun_comp_details RESULT result.

    METHODS ping FOR MODIFY
      IMPORTING keys FOR ACTION zcds_cun_comp_details~ping.
*    METHODS getdefaultsforcreate FOR READ
*      IMPORTING keys FOR FUNCTION zcds_cun_comp_details~getdefaultsforcreate RESULT result.

ENDCLASS.

CLASS lhc_ZCDS_CUN_COMP_DETAILS IMPLEMENTATION.

  METHOD get_instance_authorizations.
    " Access to these configuration tables is governed by the business
    " catalog on the service binding, as it was by the transaction code in
    " the HANA package. Every instance is granted here.
    "
    " RESULT has to be filled: an instance-authorization handler that returns
    " an empty table denies every operation on every row, which leaves the
    " business object activated but inert.
    result = VALUE #( FOR ls_key IN keys
                      ( %tky      = ls_key-%tky
                        %update   = if_abap_behv=>auth-allowed
                        %delete   = if_abap_behv=>auth-allowed ) ).
  ENDMETHOD.

  METHOD get_global_authorizations.
    " CREATE has no instance to authorize, so it is covered here.
    result-%create = if_abap_behv=>auth-allowed.
    result-%update = if_abap_behv=>auth-allowed.
    result-%delete = if_abap_behv=>auth-allowed.
    result-%action-ping = if_abap_behv=>auth-allowed.
  ENDMETHOD.

  METHOD get_global_features.
    " An empty RESULT leaves the action disabled on every row, which is
    " how the Ping button silently did nothing.
    result-%action-ping = if_abap_behv=>fc-o-enabled.
  ENDMETHOD.

  METHOD ping.

    CONSTANTS :gc_auth_token      TYPE string VALUE 'x-clear-auth-token',
               gc_erp_instance_id TYPE string VALUE 'x-erp-instance-id',
               gc_hostname        TYPE string VALUE 'HOSTNAME',
               gc_auth            TYPE string VALUE 'AUTH',
               gc_erp_id          TYPE string VALUE 'ERP_INSTANCE_ID',
               gc_ping            TYPE string VALUE 'PING'.
    DATA: gt_erp_config      TYPE TABLE OF ztelt_config,
          lr_http_client     TYPE REF TO if_web_http_client,
          gv_auth_token      TYPE string,
          gv_erp_instance_id TYPE string,
          gv_hostname        TYPE string.

    DATA:ls_abap_response TYPE  zstr_elt_ping_response,
         lv_resp_string   TYPE string.

    DATA lv_message LIKE LINE OF reported-zcds_cun_elt_config.

    SELECT labeltype,low FROM ztelt_config WHERE sysid = @sy-sysid
     INTO CORRESPONDING FIELDS OF TABLE @gt_erp_config.
    IF sy-subrc NE 0.
      DATA(lv_config) = me->new_message(
                            id       = 'ZELT_MSG'
                            number   = '005'
                            severity = ms-error
*                              v2       =
*                              v3       =
*                              v4       =
                          ).

      lv_message-%msg = lv_config.
      APPEND lv_message TO reported-zcds_cun_elt_config.
    ENDIF.

**Get Ping URL
    READ TABLE gt_erp_config ASSIGNING FIELD-SYMBOL(<lfs_api_url>)
WITH KEY labeltype = gc_ping.

    IF sy-subrc NE 0 OR <lfs_api_url>-low IS INITIAL.
      DATA(url_msg) = me->new_message(
                            id       = 'ZELT_MSG'
                            number   = '001'
                            severity = ms-error
*                              v2       =
*                              v3       =
*                              v4       =
                          ).

      lv_message-%msg = url_msg.
      APPEND lv_message TO reported-zcds_cun_elt_config.
    ELSE.
      DATA(lv_url) = <lfs_api_url>-low.
    ENDIF.

**Get Hostname
    READ TABLE gt_erp_config
             ASSIGNING FIELD-SYMBOL(<lfs_erp_config>)
             WITH KEY labeltype = gc_hostname.
    IF sy-subrc NE 0 OR <lfs_erp_config>-low IS INITIAL.
      DATA(lv_Hostname) = me->new_message(
                        id       = 'ZELT_MSG'
                        number   = '006'
                        severity = ms-error
*                              V1 =
*                              v2       =
*                              v3       =
*                              v4       =
                      ).

      lv_message-%msg = lv_Hostname.
      APPEND lv_message TO reported-zcds_cun_elt_config.
    ELSE.
      gv_hostname = <lfs_erp_config>-low.
    ENDIF.

**Get Authtoken
    READ TABLE gt_erp_config
     ASSIGNING <lfs_erp_config>
     WITH KEY labeltype = gc_auth.
    IF sy-subrc NE 0 OR <lfs_erp_config>-low IS INITIAL.
      DATA(lv_auth) = me->new_message(
                        id       = 'ZELT_MSG'
                        number   = '007'
                        severity = ms-error
*                              V1 =
*                              v2       =
*                              v3       =
*                              v4       =
                      ).

      lv_message-%msg = lv_auth.
      APPEND lv_message TO reported-zcds_cun_elt_config.
    ELSE.
      gv_auth_token = <lfs_erp_config>-low.
    ENDIF.

**Get Instance ID
    READ TABLE gt_erp_config
      ASSIGNING <lfs_erp_config>
      WITH KEY labeltype = gc_erp_id.
    IF sy-subrc NE 0 OR <lfs_erp_config>-low IS INITIAL.
      DATA(lv_instanceid) = me->new_message(
                        id       = 'ZELT_MSG'
                        number   = '008'
                        severity = ms-error
*                              V1 =
*                              v2       =
*                              v3       =
*                              v4       =
                      ).

      lv_message-%msg = lv_instanceid.
      APPEND lv_message TO reported-zcds_cun_elt_config.
    ELSE.
      gv_erp_instance_id = <lfs_erp_config>-low.
    ENDIF.


    IF gv_hostname IS NOT INITIAL AND lv_url IS NOT INITIAL.
      DATA(lv_conv) = CONV string( gv_hostname && lv_url ) .

      TRY.
          lr_http_client = cl_web_http_client_manager=>create_by_http_destination(
                           i_destination = cl_http_destination_provider=>create_by_url( lv_conv ) ).
        CATCH cx_web_http_client_error cx_http_dest_provider_error.  "#EC NO_HANDLER
          "handle exception
      ENDTRY.

      DATA(lo_request) = lr_http_client->get_http_request( ).
      lo_request->set_header_fields(  VALUE #(
              (  name = '~request_method' value = 'GET' )
              (  name = gc_auth_token  value = CONV #( gv_auth_token ) )
              ( name = gc_erp_instance_id value = CONV #( gv_erp_instance_id ) )
              ) ).


      TRY.
          DATA(lv_response) = lr_http_client->execute(
                              i_method  = if_web_http_client=>get ).
        CATCH cx_web_http_client_error. "#EC NO_HANDLER
      ENDTRY.

      DATA(lv_https_ststus) = lv_response->get_status( ).
      IF   lv_https_ststus-code EQ 200.
        DATA(lv_json_response) = lv_response->get_text( ).
        IF lv_json_response IS NOT INITIAL.
          /ui2/cl_json=>deserialize( EXPORTING json         = lv_json_response
                                               pretty_name  = abap_true
                                     CHANGING  data         = ls_abap_response ).
          DATA(lv_resp_msg) = me->new_message(
                                id       = 'ZELT_MSG'
                                number   = '004'
                                severity = ms-success
                                   v1      = ls_abap_response-message
*                                  v2       =
*                                  v3       =
*                              v4       =
                              ).

          lv_message-%msg = lv_resp_msg.
          APPEND lv_message TO reported-zcds_cun_elt_config.
        ELSE.
          DATA(lv_status) = me->new_message(
                                id       = 'ZELT_MSG'
                                number   = '003'
                                severity = ms-error
                                  v1        = lv_https_ststus-code
*                              v2       =
*                              v3       =
*                              v4       =
                              ).

          lv_message-%msg = lv_status.
          APPEND lv_message TO reported-zcds_cun_elt_config.
        ENDIF.
      ELSE.
        DATA(lv_sts_resp) = me->new_message(
                              id       = 'ZELT_MSG'
                              number   = '002'
                              severity = ms-error
                                 v1       = lv_json_response
*                                v2       =
*                              v3       =
*                              v4       =
                            ).

        lv_message-%msg = lv_sts_resp.
        APPEND lv_message TO reported-zcds_cun_elt_config.
      ENDIF.

    ENDIF.

  ENDMETHOD.



*  METHOD GetDefaultsForCreate.
*  ENDMETHOD.

ENDCLASS.
