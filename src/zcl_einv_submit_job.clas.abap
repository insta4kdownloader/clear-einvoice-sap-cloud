"! <p class="shorttext synchronized">e-Invoice job: submit pending documents</p>
"!
"! Replaces /CLR/ZCL_EINV_BASE~submit_data_batch, the sy-batch branch of
"! /CLR/ELT_EINVOICE_COCKPIT.
"!
"! Two things the HANA version could not do and this one does:
"!
"!  * Retry. The old flow retried inside the trigger function module
"!    with DO 2 TIMES + WAIT UP TO 3 SECONDS, blocking a work process.
"!    WAIT is not allowed in ABAP Cloud; instead a failed document keeps
"!    its error status and this job picks it up again on its next run,
"!    which is what select_pending selects on.
"!
"!  * Bounded runtime. submit_data_batch looped over the whole selection
"!    with one HTTP round trip per document and no ceiling. p_maxrow
"!    caps a run so a slow platform cannot make the job overrun its
"!    window.
CLASS zcl_einv_submit_job DEFINITION
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
    CONSTANTS gc_log_subobject TYPE string VALUE 'JOB_LOG_SUBMIT'.

    METHODS write_log
      IMPORTING it_status TYPE string_table
                it_error  TYPE string_table
      RAISING   cx_bali_runtime
                cx_uuid_error.

ENDCLASS.



CLASS zcl_einv_submit_job IMPLEMENTATION.


  METHOD if_apj_dt_exec_object~get_parameters.
    et_parameter_def = VALUE #(
      ( selname = 'P_BUKRS'   kind = if_apj_dt_exec_object=>parameter
        datatype = 'CHAR' length = 4  param_text = 'Company Code' changeable_ind = abap_true )
      ( selname = 'P_MAXROW' kind = if_apj_dt_exec_object=>parameter
        datatype = 'INT4' length = 10 param_text = 'Max Documents per Run' changeable_ind = abap_true ) ).

    et_parameter_val = VALUE #(
      ( selname = 'P_MAXROW' kind = if_apj_dt_exec_object=>parameter
        sign = 'I' option = 'EQ' low = '200' ) ).
  ENDMETHOD.


  METHOD if_apj_rt_exec_object~execute.

    DATA lt_status TYPE string_table.
    DATA lt_error  TYPE string_table.

    DATA(lv_max) = COND i( WHEN p_maxrow > 0 THEN p_maxrow ELSE 200 ).

    " Customizing is buffered per session for the life of the job; a
    " change made while the job runs is picked up on the next run.
    zcl_einv_config=>get_instance( )->invalidate( ).

    DATA(lo_worklist) = NEW zcl_einv_worklist( ).

    DATA(lt_pending) = lo_worklist->select_pending( iv_bukrs    = p_bukrs
                                                    iv_max_rows = lv_max ).

    APPEND |Submission run: { lines( lt_pending ) } pending document(s)| TO lt_status.

    DATA(lv_ok)   = 0.
    DATA(lv_fail) = 0.

    LOOP AT lt_pending INTO DATA(ls_doc).

      " The submission itself, the status write-back and the eligibility
      " rules all live in the SubmitEInvoice handler. The job executes that
      " action rather than repeating them: an external EML write (one made
      " without IN LOCAL MODE) is subject to the static field control of the
      " behaviour definition, and SyncStatus / ErrorText / CommandId are
      " declared `field ( readonly )` there. Writing them from here would be
      " rejected, the documents would keep their old status, and
      " select_pending would hand them back on the next run - submitting the
      " same invoices to the platform again and again.
      MODIFY ENTITIES OF zcds_int_einv_doc
        ENTITY einvoice
          EXECUTE SubmitEInvoice
          FROM VALUE #( ( BillingDocument    = ls_doc-vbeln
                          AccountingDocument = ls_doc-belnr
                          CompanyCode        = ls_doc-bukrs
                          FiscalYear         = ls_doc-gjahr ) )
        FAILED   DATA(ls_fail)
        REPORTED DATA(ls_rep).

      LOOP AT ls_rep-einvoice INTO DATA(ls_msg).
        IF ls_msg-%msg IS BOUND.
          APPEND |{ ls_doc-bukrs }/{ ls_doc-belnr }/{ ls_doc-gjahr }: |
              && ls_msg-%msg->if_message~get_text( ) TO lt_error.
        ENDIF.
      ENDLOOP.

      IF ls_fail IS NOT INITIAL.
        lv_fail = lv_fail + 1.
        ROLLBACK ENTITIES.
        CONTINUE.
      ENDIF.

      " One commit per document, so a single failing call cannot roll back
      " the outcome of the others - the HANA batch version had no
      " transaction boundary at all.
      COMMIT ENTITIES RESPONSE OF zcds_int_einv_doc
        FAILED   DATA(ls_cfail)
        REPORTED DATA(ls_crep).

      IF ls_cfail IS NOT INITIAL.
        lv_fail = lv_fail + 1.
        APPEND |{ ls_doc-bukrs }/{ ls_doc-belnr }/{ ls_doc-gjahr }: save rejected| TO lt_error.
      ELSE.
        lv_ok = lv_ok + 1.
      ENDIF.
    ENDLOOP.

    APPEND |Submitted: { lv_ok }, failed: { lv_fail }| TO lt_status.

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
