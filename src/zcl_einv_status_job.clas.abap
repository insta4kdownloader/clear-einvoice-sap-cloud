"! <p class="shorttext synchronized">e-Invoice job: refresh platform status</p>
"!
"! This job has NO counterpart in the HANA package.
"!
"! There, status was only ever refreshed when a user selected rows in
"! the cockpit and pressed the &STATUS button (get_status ->
"! call_get_status). /CLR/ZT_EINV_ASY existed as a shadow table for
"! asynchronous results, but nothing in /CLR/EINVOICE_ELT ever polled
"! for them - the rows only appeared if the platform's ingestion
"! write-back happened to fill them. A document submitted on Friday
"! afternoon therefore sat in SUBMITTED until somebody opened the
"! cockpit and looked.
"!
"! Scheduling this job closes that gap: it re-reads the status of every
"! document that has a platform document id and has not reached a final
"! state, and writes the result plus the error details through the
"! business object.
CLASS zcl_einv_status_job DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_apj_dt_exec_object.
    INTERFACES if_apj_rt_exec_object.

    DATA p_bukrs   TYPE zde_einv_bukrs.
    DATA p_maxrow TYPE i.

  PROTECTED SECTION.
  PRIVATE SECTION.

    CONSTANTS gc_log_object    TYPE string VALUE 'ZAJL_EINV_EXECUTION'.
    CONSTANTS gc_log_subobject TYPE string VALUE 'JOB_LOG_STATUS'.

    METHODS write_log
      IMPORTING it_status TYPE string_table
                it_error  TYPE string_table
      RAISING   cx_bali_runtime
                cx_uuid_error.

ENDCLASS.



CLASS zcl_einv_status_job IMPLEMENTATION.


  METHOD if_apj_dt_exec_object~get_parameters.
    et_parameter_def = VALUE #(
      ( selname = 'P_BUKRS'   kind = if_apj_dt_exec_object=>parameter
        datatype = 'CHAR' length = 4  param_text = 'Company Code' changeable_ind = abap_true )
      ( selname = 'P_MAXROW' kind = if_apj_dt_exec_object=>parameter
        datatype = 'INT4' length = 10 param_text = 'Max Documents per Run' changeable_ind = abap_true ) ).

    et_parameter_val = VALUE #(
      ( selname = 'P_MAXROW' kind = if_apj_dt_exec_object=>parameter
        sign = 'I' option = 'EQ' low = '500' ) ).
  ENDMETHOD.


  METHOD if_apj_rt_exec_object~execute.

    DATA lt_status TYPE string_table.
    DATA lt_error  TYPE string_table.

    DATA(lv_max) = COND i( WHEN p_maxrow > 0 THEN p_maxrow ELSE 500 ).

    DATA(lo_worklist) = NEW zcl_einv_worklist( ).
    " Drop the per-session customizing buffer at the start of every run.
    zcl_einv_config=>get_instance( )->invalidate( ).

    DATA(lt_open) = lo_worklist->select_for_status_refresh( iv_bukrs    = p_bukrs
                                                            iv_max_rows = lv_max ).

    APPEND |Status refresh: { lines( lt_open ) } open document(s)| TO lt_status.

    DATA(lv_changed) = 0.

    LOOP AT lt_open INTO DATA(ls_doc).

      " RefreshStatus already does the transaction-type derivation, the HTTP
      " GET, the write-back and the persisting of the error detail rows. The
      " job executes the action instead of repeating the first three and
      " skipping the fourth - and, crucially, an external EML write (one made
      " without IN LOCAL MODE) is subject to the static field control of the
      " behaviour definition, where SyncStatus and ErrorText are
      " `field ( readonly )`. Writing them from here would simply be rejected.
      MODIFY ENTITIES OF zcds_int_einv_doc
        ENTITY einvoice
          EXECUTE RefreshStatus
          FROM VALUE #( ( BillingDocument    = ls_doc-vbeln
                          AccountingDocument = ls_doc-belnr
                          CompanyCode        = ls_doc-bukrs
                          FiscalYear         = ls_doc-gjahr ) )
        FAILED   DATA(ls_fail)
        REPORTED DATA(ls_rep).

      LOOP AT ls_rep-einvoice INTO DATA(ls_msg).
        IF ls_msg-%msg IS BOUND.
          APPEND |{ ls_doc-belnr }: | && ls_msg-%msg->if_message~get_text( ) TO lt_error.
        ENDIF.
      ENDLOOP.

      IF ls_fail IS NOT INITIAL.
        ROLLBACK ENTITIES.
        CONTINUE.
      ENDIF.

      COMMIT ENTITIES RESPONSE OF zcds_int_einv_doc
        FAILED   DATA(ls_cfail)
        REPORTED DATA(ls_crep).

      IF ls_cfail IS NOT INITIAL.
        APPEND |{ ls_doc-belnr }: save rejected| TO lt_error.
      ELSE.
        lv_changed = lv_changed + 1.
      ENDIF.
    ENDLOOP.

    APPEND |{ lv_changed } document(s) changed status| TO lt_status.

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
