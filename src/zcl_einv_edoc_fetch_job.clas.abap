"! <p class="shorttext synchronized">e-Document job: fetch inbound documents</p>
"!
"! Replaces the report `/CLR/EINV_AP_GET_DOCUMENT` and its transaction
"! `/CLR/EINV_AP_GETDOC`, both of which the 2026-09-25 drop left broken -
"! the programs were deleted but the transaction still points at them.
"!
"! Its selection screen (`/CLR/EINV_AP_GET_DOCUMENT_SS`) was:
"!   P_SDATE  start date      OBLIGATORY
"!   P_EDATE  end date        OBLIGATORY
"!   P_VAT    seller VAT      OBLIGATORY
"!   P_TYPE   e-invoice type  DEFAULT 'PURCHASE'
"!   P_ADHOC  ad-hoc flag     DEFAULT 'X'
"!
"! P_VAT is not carried over: it was passed to the API as the x-clear-vat
"! header, which ZCL_EINV_API_CLIENT now derives from the company code's
"! own registration (ZTEINV_CNTRY-VAT, falling back to ZTEINV_VAT). A
"! company code parameter replaces it, which is the value the rest of the
"! configuration is keyed on anyway.
CLASS zcl_einv_edoc_fetch_job DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_apj_dt_exec_object.
    INTERFACES if_apj_rt_exec_object.

    DATA p_bukrs TYPE zde_einv_bukrs.
    DATA p_type  TYPE zde_einv_type.
    DATA p_sdate TYPE d.
    DATA p_edate TYPE d.
    DATA p_adhoc TYPE zde_einv_flag.

  PROTECTED SECTION.
  PRIVATE SECTION.

    CONSTANTS gc_log_object    TYPE string VALUE 'ZAJL_EINV_EXECUTION'.
    CONSTANTS gc_log_subobject TYPE string VALUE 'JOB_LOG_FETCH'.

    METHODS write_log
      IMPORTING it_status TYPE string_table
                it_error  TYPE string_table
      RAISING   cx_bali_runtime
                cx_uuid_error.

ENDCLASS.



CLASS zcl_einv_edoc_fetch_job IMPLEMENTATION.


  METHOD if_apj_dt_exec_object~get_parameters.
    et_parameter_def = VALUE #(
      ( selname = 'P_BUKRS' kind = if_apj_dt_exec_object=>parameter
        datatype = 'CHAR' length = 4  param_text = 'Company Code' changeable_ind = abap_true )
      ( selname = 'P_TYPE'  kind = if_apj_dt_exec_object=>parameter
        datatype = 'CHAR' length = 20 param_text = 'e-Invoice Type' changeable_ind = abap_true )
      ( selname = 'P_SDATE' kind = if_apj_dt_exec_object=>parameter
        datatype = 'DATS' length = 8  param_text = 'Start Date' changeable_ind = abap_true )
      ( selname = 'P_EDATE' kind = if_apj_dt_exec_object=>parameter
        datatype = 'DATS' length = 8  param_text = 'End Date' changeable_ind = abap_true )
      ( selname = 'P_ADHOC' kind = if_apj_dt_exec_object=>parameter
        datatype = 'CHAR' length = 1  param_text = 'Ad-Hoc Run' changeable_ind = abap_true ) ).

    et_parameter_val = VALUE #(
      ( selname = 'P_TYPE'  kind = if_apj_dt_exec_object=>parameter
        sign = 'I' option = 'EQ' low = 'PURCHASE' )
      ( selname = 'P_ADHOC' kind = if_apj_dt_exec_object=>parameter
        sign = 'I' option = 'EQ' low = 'X' ) ).
  ENDMETHOD.


  METHOD if_apj_rt_exec_object~execute.

    DATA lt_status TYPE string_table.
    DATA lt_error  TYPE string_table.

    DATA(lv_type)  = COND zde_einv_type( WHEN p_type IS NOT INITIAL
                                         THEN p_type ELSE 'PURCHASE' ).
    DATA(lv_to)    = COND d( WHEN p_edate IS NOT INITIAL
                             THEN p_edate ELSE zcl_einv_util=>get_system_date( ) ).
    DATA(lv_from)  = COND d( WHEN p_sdate IS NOT INITIAL THEN p_sdate ELSE lv_to ).

    APPEND |Fetch { lv_type } for { p_bukrs }, { lv_from } to { lv_to }| TO lt_status.

    IF p_bukrs IS INITIAL.
      APPEND 'Company code is mandatory' TO lt_error.
    ELSE.
      DATA(ls_run) = NEW zcl_einv_edoc_fetch( lv_type )->fetch_document_list(
                       iv_bukrs     = p_bukrs
                       iv_date_from = lv_from
                       iv_date_to   = lv_to
                       iv_adhoc     = COND #( WHEN p_adhoc IS NOT INITIAL
                                              THEN p_adhoc ELSE space ) ).

      APPEND |Run { ls_run-run_uuid }: { ls_run-fetched } fetched, | &&
             |{ ls_run-created } new| TO lt_status.

      IF ls_run-success = abap_false.
        APPEND CONV string( ls_run-message ) TO lt_error.
      ENDIF.

      " The run log row and the document stubs are written by the fetch
      " class; the job owns the commit, so a failed API call leaves no
      " half-written state.
      COMMIT ENTITIES.
    ENDIF.

    TRY.
        write_log( it_status = lt_status it_error = lt_error ).
      CATCH cx_bali_runtime cx_uuid_error INTO DATA(lx_log).
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
