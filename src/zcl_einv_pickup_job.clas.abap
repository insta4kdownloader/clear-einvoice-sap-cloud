"! <p class="shorttext synchronized">e-Invoice job: pick up relevant documents</p>
"!
"! Replaces running /CLR/ELT_EINVOICE_COCKPIT in the background.
"!
"! In the HANA package the batch path was a report submitted through
"! SM36 with a variant; the code branched on sy-batch:
"!
"!   IF sy-batch IS NOT INITIAL.
"!     lo_obj->submit_data_batch( ).
"!   ELSE.
"!     lo_obj->prepare_fieldcat( ). lo_obj->display_data( sy-repid ).
"!   ENDIF.
"!
"! Reports, SUBMIT and sy-batch do not exist in ABAP Cloud. The
"! Application Job framework (APJ) replaces them: this class is the
"! executable object behind job catalog entry ZAJC_EINV_PICKUP, and the
"! selection screen becomes typed job parameters in
"! if_apj_dt_exec_object~get_parameters.
"!
"! Splitting pick-up from submission (ZCL_EINV_SUBMIT_JOB) is
"! deliberate: the HANA report did both in one pass, so a slow API made
"! the whole selection time out.
CLASS zcl_einv_pickup_job DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_apj_dt_exec_object.
    INTERFACES if_apj_rt_exec_object.

    "! Job parameters. Public attributes are how APJ binds the values
    "! declared in ZAJC_EINV_PICKUP.sajc.json.
    DATA p_bukrs  TYPE zde_einv_bukrs.
    DATA p_projid TYPE zde_einv_projectid.
    DATA p_budatf TYPE d.
    DATA p_budatt TYPE d.
    DATA p_cpudtf TYPE d.
    DATA p_cpudtt TYPE d.
    DATA p_submit  TYPE zde_einv_flag.

  PROTECTED SECTION.
  PRIVATE SECTION.

    CONSTANTS gc_log_object    TYPE string VALUE 'ZAJL_EINV_EXECUTION'.
    CONSTANTS gc_log_subobject TYPE string VALUE 'JOB_LOG_PICKUP'.

    METHODS write_log
      IMPORTING it_status TYPE string_table
                it_error  TYPE string_table
      RAISING   cx_bali_runtime
                cx_uuid_error.

ENDCLASS.



CLASS zcl_einv_pickup_job IMPLEMENTATION.


  METHOD if_apj_dt_exec_object~get_parameters.
    " Declares the job parameters and their defaults. These are the
    " selection-screen fields of /CLR/ELT_EINVOICE_SEL that get_data
    " actually used; the dead ones (P_SUBM, P_CAN, P_LOG) are dropped.
    et_parameter_def = VALUE #(
      ( selname = 'P_BUKRS'   kind = if_apj_dt_exec_object=>parameter
        datatype = 'CHAR' length = 4  param_text = 'Company Code' changeable_ind = abap_true )
      ( selname = 'P_PROJID'  kind = if_apj_dt_exec_object=>parameter
        datatype = 'CHAR' length = 30 param_text = 'Project ID' changeable_ind = abap_true )
      ( selname = 'P_BUDATF' kind = if_apj_dt_exec_object=>parameter
        datatype = 'DATS' length = 8  param_text = 'Posting Date From' changeable_ind = abap_true )
      ( selname = 'P_BUDATT' kind = if_apj_dt_exec_object=>parameter
        datatype = 'DATS' length = 8  param_text = 'Posting Date To' changeable_ind = abap_true )
      ( selname = 'P_CPUDTF' kind = if_apj_dt_exec_object=>parameter
        datatype = 'DATS' length = 8  param_text = 'Creation Date From' changeable_ind = abap_true )
      ( selname = 'P_CPUDTT' kind = if_apj_dt_exec_object=>parameter
        datatype = 'DATS' length = 8  param_text = 'Creation Date To' changeable_ind = abap_true )
      ( selname = 'P_SUBMIT'  kind = if_apj_dt_exec_object=>parameter
        datatype = 'CHAR' length = 1  param_text = 'Submit Immediately' changeable_ind = abap_true ) ).

    et_parameter_val = VALUE #(
      ( selname = 'P_SUBMIT' kind = if_apj_dt_exec_object=>parameter
        sign = 'I' option = 'EQ' low = 'X' ) ).
  ENDMETHOD.


  METHOD if_apj_rt_exec_object~execute.

    DATA lt_status TYPE string_table.
    DATA lt_error  TYPE string_table.

    APPEND |Pick-up started for company code { p_bukrs }| TO lt_status.

    IF p_bukrs IS INITIAL.
      APPEND |Company code is mandatory| TO lt_error.
      TRY.
          write_log( it_status = lt_status it_error = lt_error ).
        CATCH cx_bali_runtime cx_uuid_error.
      ENDTRY.
      RETURN.
    ENDIF.

    DATA(lo_worklist) = NEW zcl_einv_worklist( ).

    DATA(lt_relevant) = lo_worklist->select_relevant(
                          iv_projectid          = p_projid
                          iv_bukrs              = p_bukrs
                          iv_posting_date_from  = p_budatf
                          iv_posting_date_to    = p_budatt
                          iv_creation_date_from = p_cpudtf
                          iv_creation_date_to   = p_cpudtt ).

    APPEND |{ lines( lt_relevant ) } relevant document(s) found| TO lt_status.

    IF lt_relevant IS INITIAL.
      TRY.
          write_log( it_status = lt_status it_error = lt_error ).
        CATCH cx_bali_runtime cx_uuid_error.
      ENDTRY.
      RETURN.
    ENDIF.

    " Rows are created through the business object, not with a direct
    " INSERT, so the determination and the validation of
    " ZBP_CDS_INT_EINV_DOC run for job-created rows exactly as for
    " user-created ones.
    DATA lt_create TYPE TABLE FOR CREATE zcds_int_einv_doc.

    LOOP AT lt_relevant INTO DATA(ls_rel).
      APPEND VALUE #( %cid               = |JOB{ sy-tabix }|
                      BillingDocument    = ls_rel-vbeln
                      AccountingDocument = ls_rel-belnr
                      CompanyCode        = ls_rel-bukrs
                      FiscalYear         = ls_rel-gjahr
                      DocumentTypeCode   = ls_rel-doc_type
                      EInvoiceDate       = ls_rel-bldat
                      IsB2C              = ls_rel-b2c )
             TO lt_create.
    ENDLOOP.

    DATA(lt_keep) = lo_worklist->keep_new( CORRESPONDING #( lt_create ) ).

    DATA lt_new LIKE lt_create.
    LOOP AT lt_create INTO DATA(ls_cand).
      CHECK line_exists( lt_keep[ BillingDocument    = ls_cand-BillingDocument
                                  AccountingDocument = ls_cand-AccountingDocument
                                  CompanyCode        = ls_cand-CompanyCode
                                  FiscalYear         = ls_cand-FiscalYear ] ).
      APPEND ls_cand TO lt_new.
    ENDLOOP.

    APPEND |{ lines( lt_new ) } new worklist row(s) to create| TO lt_status.

    IF lt_new IS NOT INITIAL.
      MODIFY ENTITIES OF zcds_int_einv_doc
        ENTITY einvoice
          CREATE FIELDS ( BillingDocument AccountingDocument CompanyCode
                          FiscalYear DocumentTypeCode EInvoiceDate IsB2C )
          WITH lt_new
        REPORTED DATA(ls_reported)
        FAILED   DATA(ls_failed).

      COMMIT ENTITIES RESPONSE OF zcds_int_einv_doc
        FAILED   DATA(ls_commit_failed)
        REPORTED DATA(ls_commit_reported).

      IF ls_commit_failed IS NOT INITIAL.
        APPEND |Commit reported failures for one or more rows| TO lt_error.
      ENDIF.

      LOOP AT ls_reported-einvoice INTO DATA(ls_rep).
        IF ls_rep-%msg IS BOUND.
          APPEND ls_rep-%msg->if_message~get_text( ) TO lt_error.
        ENDIF.
      ENDLOOP.
    ENDIF.

    " Optional straight-through processing, the equivalent of the
    " batch variant that selected and submitted in one run.
    IF p_submit = 'X'.
      DATA(lt_pending) = lo_worklist->select_pending( iv_bukrs = p_bukrs ).
      APPEND |{ lines( lt_pending ) } document(s) queued for submission| TO lt_status.

      LOOP AT lt_pending INTO DATA(ls_pending).

        " Executes the BO action rather than calling ZCL_EINV_SUBMIT and
        " writing the result back by hand: SyncStatus / ErrorText /
        " CommandId / IsSent are `field ( readonly )` in the behaviour
        " definition, so an external EML update of them is rejected and the
        " document would be submitted again on every subsequent run.
        MODIFY ENTITIES OF zcds_int_einv_doc
          ENTITY einvoice
            EXECUTE SubmitEInvoice
            FROM VALUE #( ( BillingDocument    = ls_pending-vbeln
                            AccountingDocument = ls_pending-belnr
                            CompanyCode        = ls_pending-bukrs
                            FiscalYear         = ls_pending-gjahr ) )
          FAILED   DATA(ls_fail_sub)
          REPORTED DATA(ls_rep_sub).

        LOOP AT ls_rep_sub-einvoice INTO DATA(ls_msg_sub).
          IF ls_msg_sub-%msg IS BOUND.
            APPEND |{ ls_pending-belnr }: | && ls_msg_sub-%msg->if_message~get_text( )
                   TO lt_error.
          ENDIF.
        ENDLOOP.

        IF ls_fail_sub IS NOT INITIAL.
          ROLLBACK ENTITIES.
          CONTINUE.
        ENDIF.

        COMMIT ENTITIES RESPONSE OF zcds_int_einv_doc
          FAILED   DATA(ls_cfail_sub)
          REPORTED DATA(ls_crep_sub).

        IF ls_cfail_sub IS NOT INITIAL.
          APPEND |{ ls_pending-belnr }: save rejected| TO lt_error.
        ENDIF.
      ENDLOOP.
    ENDIF.

    APPEND |Pick-up finished| TO lt_status.

    TRY.
        write_log( it_status = lt_status it_error = lt_error ).
      CATCH cx_bali_runtime cx_uuid_error INTO DATA(lx_log).
        " ABAP Cloud forbids MESSAGE here; keep the text for the
        " debugger rather than letting a logging problem fail the job.
        DATA(lv_log_failure) = lx_log->get_text( ).
    ENDTRY.

  ENDMETHOD.


  METHOD write_log.
    " Application Log via cl_bali_*, the released replacement for the
    " BAL_* function modules. Same pattern as
    " ZCL_ELT_EXEC_COMMAND_JOB~build_log_entries in ZZCLR_ELT.
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
