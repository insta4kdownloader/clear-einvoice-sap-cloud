*"* Behaviour implementation of the Sales e-Invoice business object.
*"*
*"* Origin of each handler method in the HANA package /CLR/EINVOICE_ELT:
*"*
*"*   pickupdocuments    /CLR/ZCL_EINV_BASE~get_data + consolidate_data
*"*                      + get_billing_docs + get_accounting_docs
*"*   submiteinvoice     /CLR/ZCL_EINV_BASE~submit_data
*"*                      + submit_data_batch + submit_data_retrieval
*"*   refreshstatus      /CLR/ZCL_EINV_BASE~get_status + call_get_status
*"*   requestprintout    /CLR/ZCL_EINV_BASE~print_pdf + call_print_pdf
*"*   selleraction       /CLR/ZCL_EINV_BASE~call_seller_action
*"*                      + dynpro 0200 of /CLR/ELT_EINVOICE_COCKPIT_SO01
*"*   canceleinvoice     /CLR/ZCL_EINV_BASE~cancel / call_cancel (both empty)
*"*   get_features       /CLR/EINV_ALVFUN customizing + FORM zpfstatus1
*"*
*"* No COMMIT WORK, no ENQUEUE/DEQUEUE, no MESSAGE statements: persistence
*"* is done with EML inside the RAP LUW and diagnostics through
*"* reported/failed, so the framework owns the transaction and the locks.

CLASS lhc_einvoice DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    CONSTANTS:
      "! Statuses that make a document eligible for (re-)submission.
      "! Mirrors submit_data: a row qualifies when it has no document id
      "! yet, or when it carries an error.
      BEGIN OF gc_status,
        not_processed TYPE zde_einv_status VALUE 'NOT PROCESSED',
        submitted     TYPE zde_einv_status VALUE 'SUBMITTED',
        error         TYPE zde_einv_status VALUE 'ERROR',
        valid         TYPE zde_einv_status VALUE 'VALID',
        cancelled     TYPE zde_einv_status VALUE 'CANCELLED',
        completed     TYPE zde_einv_status VALUE 'COMPLETED',
        collected     TYPE zde_einv_status VALUE 'COLLECTED',
      END OF gc_status.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR einvoice
      RESULT result.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR einvoice
      RESULT result.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR einvoice
      RESULT result.

    METHODS setcreationdata FOR DETERMINE ON MODIFY
      IMPORTING keys FOR einvoice~setcreationdata.

    METHODS checkrelevance FOR VALIDATE ON SAVE
      IMPORTING keys FOR einvoice~checkrelevance.

    METHODS pickupdocuments FOR MODIFY
      IMPORTING keys FOR ACTION einvoice~pickupdocuments.

    METHODS submiteinvoice FOR MODIFY
      IMPORTING keys FOR ACTION einvoice~submiteinvoice RESULT result.

    METHODS refreshstatus FOR MODIFY
      IMPORTING keys FOR ACTION einvoice~refreshstatus RESULT result.

    METHODS requestprintout FOR MODIFY
      IMPORTING keys FOR ACTION einvoice~requestprintout RESULT result.

    METHODS selleraction FOR MODIFY
      IMPORTING keys FOR ACTION einvoice~selleraction RESULT result.

    METHODS canceleinvoice FOR MODIFY
      IMPORTING keys FOR ACTION einvoice~canceleinvoice RESULT result.

    " The four key fields of the business object, as a plain structure.
    " Every action's key table is CORRESPONDING-converted into this on the
    " way into the helpers below, so the helpers have one concrete type
    " instead of a generic ANY TABLE.
    "
    " A plain comment, not ABAP Doc: `"!` is only accepted immediately in
    " front of the declaration it documents, and a chained TYPES: is not
    " one of them.
    TYPES:
      BEGIN OF ty_key,
        BillingDocument    TYPE zde_einv_billdoc,
        AccountingDocument TYPE zde_einv_accdoc,
        CompanyCode        TYPE zde_einv_bukrs,
        FiscalYear         TYPE zde_einv_gjahr,
      END OF ty_key,
      ty_keys TYPE STANDARD TABLE OF ty_key WITH EMPTY KEY,
      ty_enr  TYPE STANDARD TABLE OF zcds_int_einv_doc_enr WITH EMPTY KEY,

      "! One flattened ZTEINV_PPF row. A plain structure, not a RAP
      "! derived type: FLATTEN_PPF has to be declarable as a method, and
      "! TABLE FOR CREATE is not accepted in a method signature - the same
      "! limitation recorded above for read_documents. The caller turns
      "! these into %target entries.
      BEGIN OF ty_ppf_row,
        SequenceNumber       TYPE zde_int3,
        ReasonNumber         TYPE zde_int3,
        ClearDocumentId      TYPE zde_einv_docid,
        TransactionId        TYPE zde_einv_ppf_trans,
        PpfAction            TYPE zde_einv_ppf_act,
        PpfActionType        TYPE zde_einv_ppf_acttyp,
        PpfStatus            TYPE zde_einv_status,
        ReceivedDate         TYPE d,
        ReceivedTime         TYPE t,
        ReceivedMilliseconds TYPE zde_int3,
        ReasonCode           TYPE zde_einv_rescode,
        ReasonText           TYPE zde_einv_ppf_rsntxt,
      END OF ty_ppf_row,
      ty_ppf_rows TYPE STANDARD TABLE OF ty_ppf_row WITH EMPTY KEY.

    " There is deliberately no read_documents helper. Its one statement is
    " repeated in each action instead, because a RAP derived type
    " (TABLE FOR READ RESULT ...) is not accepted anywhere in a method
    " declaration - not as RETURNING, not as EXPORTING, and not in a
    " behaviour pool either.

    "! Reads the derived values that deliberately do not live on the
    "! business object: the effective status and the enrichment from the
    "! released document views. See ZCDS_INT_EINV_DOC_ENR for why.
    METHODS read_enrichment
      IMPORTING it_keys       TYPE ty_keys
      RETURNING VALUE(rt_enr) TYPE ty_enr.

    "! /CLR/ZCL_EINV_BASE~SAVE_PPF_DETAILS, minus the persistence.
    "!
    "! Flattens GovtReportingDetails[] x StatusReasons[] into the rows of
    "! ZTEINV_PPF, and reports the status and action of the entry with the
    "! highest ReceivedAt - last array index winning a tie, as HANA does
    "! with `lv_seq >= lv_max_seq`.
    "!
    "! It does NOT write anything. HANA ends with
    "!   DELETE FROM /clr/zt_einv_ppf WHERE ... + INSERT ... FROM TABLE
    "! and neither statement is allowed in the RAP interaction phase
    "! (section 50). The caller replaces the history through the
    "! composition instead. Section 81.
    METHODS flatten_ppf
      IMPORTING it_govt       TYPE zcl_einv_api_client=>ty_govt_detail_tt
                is_key        TYPE ty_key
                iv_doc_id     TYPE zde_einv_docid
      EXPORTING et_rows       TYPE ty_ppf_rows
                ev_ppf_status TYPE zde_einv_status
                ev_ppf_action TYPE zde_einv_ppf_act.

ENDCLASS.


CLASS lhc_einvoice IMPLEMENTATION.

**********************************************************************
* Authorization and feature control
**********************************************************************

  METHOD get_instance_authorizations.
    " The HANA cockpit did AUTHORITY-CHECK OBJECT 'F_BKPF_BUK'
    " ID 'BUKRS' FIELD p_bukrs ID 'ACTVT' FIELD '03'.
    " F_BKPF_BUK is not the Public Cloud pattern. Data-level
    " authorization belongs on the business object: create a restriction
    " field for CompanyCode in the IAM business role and evaluate it
    " here once the authorization object exists.
    " RESULT carries a component only for the operations that are subject
    " to instance authorization - update, delete and create-by-association.
    " Actions appear here only when they are declared with
    " ( authorization : instance ) in the behaviour definition; none is, so
    " naming %action-... would not compile. Their access is governed by the
    " business catalog, and the buttons are steered by feature control.
    result = VALUE #( FOR ls_auth IN keys
                      ( %tky = ls_auth-%tky %update = if_abap_behv=>auth-allowed ) ).
  ENDMETHOD.


  METHOD get_global_authorizations.
    " CREATE and the static action PickUpDocuments have no instance, so this
    " is where they are authorized. Rows are created by PickUpDocuments and
    " by the APJ jobs, never interactively - the projection does not expose
    " create - and access to the app itself is the business catalog's job.
    result-%create = if_abap_behv=>auth-allowed.
    result-%update = if_abap_behv=>auth-allowed.
  ENDMETHOD.


  METHOD get_instance_features.
    " Replaces /CLR/EINV_ALVFUN (a customizing table of GUI function
    " codes) and FORM zpfstatus1, which built an EXCLUDING table for
    " SET PF-STATUS. In Fiori the same intent is per-instance feature
    " control, so a button is greyed out for the rows where it makes
    " no sense rather than hidden for everybody.
    READ ENTITIES OF zcds_int_einv_doc IN LOCAL MODE
      ENTITY einvoice
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_doc).
    DATA(lt_enr) = read_enrichment( CORRESPONDING #( keys ) ).

    LOOP AT keys INTO DATA(ls_key).
      DATA(ls_doc) = VALUE #( lt_doc[ KEY entity
                                      BillingDocument    = ls_key-BillingDocument
                                      AccountingDocument = ls_key-AccountingDocument
                                      CompanyCode        = ls_key-CompanyCode
                                      FiscalYear         = ls_key-FiscalYear ]
                              OPTIONAL ).
      DATA(ls_enr) = VALUE #( lt_enr[ BillingDocument    = ls_key-BillingDocument
                                      AccountingDocument = ls_key-AccountingDocument
                                      CompanyCode        = ls_key-CompanyCode
                                      FiscalYear         = ls_key-FiscalYear ]
                              OPTIONAL ).

      " Submit: only "yet to process" or errored rows, exactly the
      " eligibility rule of submit_data.
      DATA(lv_submit) = COND #(
        WHEN ls_doc-ClearDocumentId IS INITIAL OR ls_doc-ErrorText IS NOT INITIAL
        THEN if_abap_behv=>fc-o-enabled
        ELSE if_abap_behv=>fc-o-disabled ).

      " Status / print / seller action / cancel all need a document id
      " on the platform side.
      DATA(lv_has_id) = COND #( WHEN ls_doc-ClearDocumentId IS NOT INITIAL
                                THEN if_abap_behv=>fc-o-enabled
                                ELSE if_abap_behv=>fc-o-disabled ).

      DATA(lv_cancel) = COND #(
        WHEN ls_doc-ClearDocumentId IS NOT INITIAL
         AND ls_enr-EffectiveStatus <> gc_status-cancelled
        THEN if_abap_behv=>fc-o-enabled
        ELSE if_abap_behv=>fc-o-disabled ).

      APPEND VALUE #( %tky                    = ls_key-%tky
                      %action-SubmitEInvoice   = lv_submit
                      %action-RefreshStatus    = lv_has_id
                      %action-RequestPrintout  = lv_has_id
                      %action-SellerAction     = lv_has_id
                      %action-CancelEInvoice   = lv_cancel )
             TO result.
    ENDLOOP.
  ENDMETHOD.


**********************************************************************
* Determinations and validations
**********************************************************************

  METHOD setcreationdata.
    " Replaces the CRDAT / CRTIME / CRUSER defaulting that
    " /CLR/ZCL_ELT~insert_table_einvoice_ingst did while writing
    " /CLR/ZT_EINV, and the sy-datum / sy-uzeit / sy-uname reads.
    READ ENTITIES OF zcds_int_einv_doc IN LOCAL MODE
      ENTITY einvoice
        FIELDS ( CreatedOn CreatedAt CreatedBy SyncStatus )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_doc).

    DATA lt_update TYPE TABLE FOR UPDATE zcds_int_einv_doc.

    LOOP AT lt_doc INTO DATA(ls_doc).
      APPEND VALUE #(
          %tky       = ls_doc-%tky
          %control-CreatedOn  = if_abap_behv=>mk-on
          %control-CreatedAt  = if_abap_behv=>mk-on
          %control-CreatedBy  = if_abap_behv=>mk-on
          %control-SyncStatus = if_abap_behv=>mk-on
          CreatedOn  = COND #( WHEN ls_doc-CreatedOn IS INITIAL
                               THEN zcl_einv_util=>get_system_date( )
                               ELSE ls_doc-CreatedOn )
          CreatedAt  = COND #( WHEN ls_doc-CreatedAt IS INITIAL
                               THEN zcl_einv_util=>get_system_time( )
                               ELSE ls_doc-CreatedAt )
          CreatedBy  = COND #( WHEN ls_doc-CreatedBy IS INITIAL
                               THEN zcl_einv_util=>get_user_name( )
                               ELSE ls_doc-CreatedBy )
          SyncStatus = COND #( WHEN ls_doc-SyncStatus IS INITIAL
                               THEN gc_status-not_processed
                               ELSE ls_doc-SyncStatus ) )
        TO lt_update.
    ENDLOOP.

    MODIFY ENTITIES OF zcds_int_einv_doc IN LOCAL MODE
      ENTITY einvoice
        UPDATE FIELDS ( CreatedOn CreatedAt CreatedBy SyncStatus )
        WITH lt_update
      REPORTED DATA(ls_reported).

    " Row by row through CORRESPONDING, not `LINES OF`. Inside a
    " determination `reported` is RESPONSE FOR REPORTED EARLY, while the
    " REPORTED of an EML MODIFY is the LATE form: two different deep types,
    " which the tenant rejects as "unsuitable".
    LOOP AT ls_reported-einvoice INTO DATA(ls_rep_row).
      APPEND CORRESPONDING #( ls_rep_row ) TO reported-einvoice.
    ENDLOOP.
  ENDMETHOD.


  METHOD checkrelevance.
    " Replaces the INVMAP check that consolidate_data performed with
    "   READ TABLE gt_invmap WITH KEY fkart = ... blart = ...
    "   IF sy-subrc <> 0. CONTINUE. ENDIF.
    " A missing mapping silently dropped the document there; here it is
    " a visible validation message on the row.
    READ ENTITIES OF zcds_int_einv_doc IN LOCAL MODE
      ENTITY einvoice
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_doc).

    DATA(lo_config) = zcl_einv_config=>get_instance( ).

    LOOP AT lt_doc INTO DATA(ls_doc).
      IF lo_config->is_company_registered( iv_bukrs = ls_doc-CompanyCode ) = abap_false.
        " /CLR/ZME_EINV 002 "Maintain Country-Company Code Mapping"
        APPEND VALUE #( %tky = ls_doc-%tky ) TO failed-einvoice.
        APPEND VALUE #( %tky = ls_doc-%tky
                        %msg = new_message( id       = 'ZEINV_MSG'
                                            number   = '002'
                                            severity = if_abap_behv_message=>severity-error
                                            v1       = ls_doc-CompanyCode )
                        %element-CompanyCode = if_abap_behv=>mk-on )
               TO reported-einvoice.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


**********************************************************************
* PickUpDocuments - the worklist build
**********************************************************************

  METHOD pickupdocuments.
    " Everything below runs inside a RAP LUW, so the ELT instrumentation
    " must not write to the database as it goes - see the saver.
    zcl_instru_event_class=>gv_defer = abap_true.

    " HANA equivalent: get_data( ir_belnr ir_fkdat ir_erdat ir_vbeln
    "                            ir_fkart ir_user ir_blart ir_gjahr )
    "                  followed by consolidate_data( ).
    "
    " There, the worklist lived only in the ALV (GT_FINAL) and vanished
    " when the report ended. Here the relevant documents are materialised
    " as pending ZTEINV_DOC rows, which is what makes a Fiori list report,
    " a background job and an audit trail all possible over one model.
    DATA lt_create TYPE TABLE FOR CREATE zcds_int_einv_doc.

    " Each created row gets its own %cid, unique across the whole request
    " (a running counter, not sy-tabix, because the outer loop runs once
    " per action row). This map keeps the link from a created instance back
    " to the action row that asked for it, so a message raised against the
    " CREATE can be reported against the right action row further down.
    TYPES: BEGIN OF ty_cid_map,
             create_cid TYPE abp_behv_cid,
             action_cid TYPE abp_behv_cid,
           END OF ty_cid_map.
    DATA lt_cid_map TYPE SORTED TABLE OF ty_cid_map WITH UNIQUE KEY create_cid.
    DATA lv_seq     TYPE i.
    DATA lv_submit  TYPE abap_bool.

    LOOP AT keys INTO DATA(ls_key).
      DATA(ls_par) = ls_key-%param.

      " /CLR/ZCL_EINV_BASE~get_data returned immediately when both date
      " ranges were empty; the report raised e015 beforehand.
      IF     ls_par-PostingDateFrom  IS INITIAL
         AND ls_par-CreationDateFrom IS INITIAL
         AND ls_par-BillingDocument  IS INITIAL
         AND ls_par-AccountingDocument IS INITIAL.
        APPEND VALUE #( %cid = ls_key-%cid
                        %msg = new_message( id       = 'ZEINV_MSG'
                                            number   = '015'
                                            severity = if_abap_behv_message=>severity-error ) )
               TO reported-einvoice.
        CONTINUE.
      ENDIF.

      DATA(lt_relevant) = NEW zcl_einv_worklist( )->select_relevant(
                            iv_projectid          = ls_par-ProjectId
                            iv_bukrs              = ls_par-CompanyCode
                            iv_posting_date_from  = ls_par-PostingDateFrom
                            iv_posting_date_to    = ls_par-PostingDateTo
                            iv_creation_date_from = ls_par-CreationDateFrom
                            iv_creation_date_to   = ls_par-CreationDateTo
                            iv_vbeln              = ls_par-BillingDocument
                            iv_belnr              = ls_par-AccountingDocument
                            iv_gjahr              = ls_par-FiscalYear ).

      " Any single action row asking for it turns the whole run into a
      " submit run; the flag is per request, not per document.
      IF ls_par-SubmitImmediately = abap_true.
        lv_submit = abap_true.
      ENDIF.

      " ABP_BEHV_CID is itself STRING, so CONV abp_behv_cid( |...| ) is a
      " string-to-string conversion and the tenant rejects it as redundant.
      " Declared and assigned instead.
      DATA lv_cid TYPE abp_behv_cid.

      LOOP AT lt_relevant INTO DATA(ls_rel).
        lv_seq += 1.
        lv_cid = |PICK{ lv_seq }|.
        INSERT VALUE #( create_cid = lv_cid action_cid = ls_key-%cid ) INTO TABLE lt_cid_map.
        APPEND VALUE #(
            %cid               = lv_cid
            BillingDocument    = ls_rel-vbeln
            AccountingDocument = ls_rel-belnr
            CompanyCode        = ls_rel-bukrs
            FiscalYear         = ls_rel-gjahr
            DocumentTypeCode   = ls_rel-doc_type
            EInvoiceDate       = ls_rel-bldat
            IsB2C              = ls_rel-b2c
            SyncStatus         = gc_status-not_processed )
          TO lt_create.
      ENDLOOP.
    ENDLOOP.

    IF lt_create IS INITIAL.
      RETURN.
    ENDIF.

    " Existing rows must not be overwritten - a document that was
    " already submitted keeps its status. The HANA version relied on
    " /CLR/ZCL_ELT_EINVOICE~einv_ewb_create doing this check; here the
    " duplicate filter is explicit.
    DATA(lt_keep) = NEW zcl_einv_worklist( )->keep_new(
                      CORRESPONDING #( lt_create ) ).

    DATA lt_new LIKE lt_create.
    LOOP AT lt_create INTO DATA(ls_cand).
      CHECK line_exists( lt_keep[ BillingDocument    = ls_cand-BillingDocument
                                  AccountingDocument = ls_cand-AccountingDocument
                                  CompanyCode        = ls_cand-CompanyCode
                                  FiscalYear         = ls_cand-FiscalYear ] ).
      APPEND ls_cand TO lt_new.
    ENDLOOP.

    MODIFY ENTITIES OF zcds_int_einv_doc IN LOCAL MODE
      ENTITY einvoice
        CREATE FIELDS ( BillingDocument AccountingDocument CompanyCode
                        FiscalYear DocumentTypeCode EInvoiceDate
                        IsB2C SyncStatus )
        WITH lt_new
      MAPPED   DATA(ls_mapped)
      REPORTED DATA(ls_rep)
      FAILED   DATA(ls_fail).

    " The inner CREATE reports against the synthetic create %cid. This is a
    " STATIC action, so its own failed/reported rows are addressed by the
    " %cid of the ACTION row - translate, or the caller is handed a failure
    " it cannot match to anything it sent.
    reported-einvoice = VALUE #( BASE reported-einvoice
                                 FOR ls_r IN ls_rep-einvoice
                                 ( VALUE #( BASE CORRESPONDING #( ls_r )
                                            %cid = VALUE #( lt_cid_map[ create_cid = ls_r-%cid ]-action_cid
                                                            OPTIONAL ) ) ) ).
    failed-einvoice   = VALUE #( BASE failed-einvoice
                                 FOR ls_x IN ls_fail-einvoice
                                 ( VALUE #( BASE CORRESPONDING #( ls_x )
                                            %cid = VALUE #( lt_cid_map[ create_cid = ls_x-%cid ]-action_cid
                                                            OPTIONAL ) ) ) ).

    " P_SUBM of /CLR/ELT_EINVOICE_SEL was dead in the HANA report - it was
    " on the selection screen and never evaluated. Here it does what its
    " label promises: the freshly created rows go straight into
    " SubmitEInvoice, which is what makes an unattended APJ run possible.
    IF lv_submit = abap_true AND ls_mapped-einvoice IS NOT INITIAL.
      MODIFY ENTITIES OF zcds_int_einv_doc IN LOCAL MODE
        ENTITY einvoice
          EXECUTE SubmitEInvoice
          FROM VALUE #( FOR ls_m IN ls_mapped-einvoice ( %tky = ls_m-%tky ) )
        REPORTED DATA(ls_rep_sub)
        FAILED   DATA(ls_fail_sub).

      reported-einvoice = VALUE #( BASE reported-einvoice ( LINES OF ls_rep_sub-einvoice ) ).
      failed-einvoice   = VALUE #( BASE failed-einvoice   ( LINES OF ls_fail_sub-einvoice ) ).
    ENDIF.

    " The action used to read the created rows back and return them as its
    " result. It has none any more - see the comment on the action in
    " ZCDS_INT_EINV_DOC - so the read-back went with it. The rows are on the
    " database, the messages are in REPORTED, and the list report shows them
    " on its next refresh.
  ENDMETHOD.


**********************************************************************
* SubmitEInvoice
**********************************************************************

  METHOD submiteinvoice.
    " Everything below runs inside a RAP LUW, so the ELT instrumentation
    " must not write to the database as it goes - see the saver.
    zcl_instru_event_class=>gv_defer = abap_true.

    " HANA equivalent: submit_data / submit_data_batch, both of which
    " ended in
    "   CALL FUNCTION '/CLR/EINV_EWAY_TRIGGER_ELT'
    "     EXPORTING iv_bukrs iv_belnr iv_gjahr iv_vbeln iv_seq.
    "
    " That function module lived in /CLR/ELT and drove the command/pull
    " flow of /CLR/ZCL_ELT. Function modules cannot be created in ABAP
    " Cloud, so the entry point is now the class method
    " ZCL_EINV_SUBMIT~submit_document, which reuses the released
    " ZCL_ELT of package ZZCLR_ELT unchanged.
    READ ENTITIES OF zcds_int_einv_doc IN LOCAL MODE
      ENTITY einvoice
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_doc).

    DATA(lt_enr)    = read_enrichment( CORRESPONDING #( keys ) ).
    DATA(lo_submit) = NEW zcl_einv_submit( ).
    DATA(lo_config) = zcl_einv_config=>get_instance( ).
    DATA lt_update TYPE TABLE FOR UPDATE zcds_int_einv_doc.

    LOOP AT lt_doc INTO DATA(ls_doc).

      DATA(ls_enr) = VALUE #( lt_enr[ BillingDocument    = ls_doc-BillingDocument
                                      AccountingDocument = ls_doc-AccountingDocument
                                      CompanyCode        = ls_doc-CompanyCode
                                      FiscalYear         = ls_doc-FiscalYear ]
                              OPTIONAL ).

      " submit_data_batch re-read VBRK-FKSTO and BKPF-XREVERS* and
      " stamped an error under an exclusive lock when the source
      " document had meanwhile been cancelled. Same guard, but the
      " released views supply the flags and RAP owns the lock.
      " submit_data_batch re-read VBRK-FKSTO as well, but a cancelled
      " billing document posts an FI reversal, so IsReversed catches it.
      " I_BillingDocument has no released CancellationStatus element -
      " see the note in ZCDS_INT_EINV_DOC_ENR.
      IF ls_enr-IsReversed = abap_true OR ls_enr-IsReversal = abap_true.
        APPEND VALUE #( %tky = ls_doc-%tky
                        %msg = new_message( id       = 'ZEINV_MSG'
                                            number   = '020'
                                            severity = if_abap_behv_message=>severity-error
                                            v1       = ls_doc-AccountingDocument ) )
               TO reported-einvoice.
        APPEND VALUE #(
            %tky                  = ls_doc-%tky
            %control-SyncStatus   = if_abap_behv=>mk-on
            %control-ErrorText    = if_abap_behv=>mk-on
            SyncStatus            = gc_status-error
            ErrorText             = 'Source document is already cancelled or reversed' )
          TO lt_update.
        CONTINUE.
      ENDIF.

      " Eligibility rule of submit_data, unchanged: only documents
      " without a platform document id, or with an error, are sent.
      IF ls_doc-ClearDocumentId IS NOT INITIAL AND ls_doc-ErrorText IS INITIAL.
        APPEND VALUE #( %tky = ls_doc-%tky
                        %msg = new_message( id       = 'ZEINV_MSG'
                                            number   = '004'
                                            severity = if_abap_behv_message=>severity-warning ) )
               TO reported-einvoice.
        CONTINUE.
      ENDIF.

      DATA(ls_res) = lo_submit->submit_document(
                       iv_bukrs = ls_doc-CompanyCode
                       iv_belnr = ls_doc-AccountingDocument
                       iv_gjahr = ls_doc-FiscalYear
                       iv_vbeln = ls_doc-BillingDocument
                       iv_country = lo_config->get_country( ls_doc-CompanyCode ) ).

      " APPEND INITIAL LINE ... ASSIGNING, rather than APPEND VALUE #( )
      " and then looking the row up again: the write-back below fills the
      " same row, and reading it back with lt_update[ %tky = ... ] made the
      " tenant object that the derived table's secondary key ID was fully
      " covered but not named. Holding the field symbol is simpler than
      " naming the key, and it cannot go looking for the wrong row.
      APPEND INITIAL LINE TO lt_update ASSIGNING FIELD-SYMBOL(<ls_upd>).
      <ls_upd>-%tky                = ls_doc-%tky.
      <ls_upd>-%control-SyncStatus = if_abap_behv=>mk-on.
      <ls_upd>-%control-ErrorText  = if_abap_behv=>mk-on.
      <ls_upd>-%control-CommandId  = if_abap_behv=>mk-on.
      <ls_upd>-%control-IsSent     = if_abap_behv=>mk-on.
      <ls_upd>-SyncStatus          = ls_res-status.
      <ls_upd>-ErrorText           = ls_res-message.
      <ls_upd>-CommandId           = ls_res-command_id.
      <ls_upd>-IsSent              = COND #( WHEN ls_res-success = abap_true
                                             THEN 'X' ELSE space ).

      "---------------------------------------------------------------
      " THE INGESTION WRITE-BACK.
      "
      " /CLR/ZCL_ELT~ingestion_writeback_einvoice ends with
      "   MODIFY /CLR/ZT_EINV FROM TABLE
      " which is not available here - a direct table write in the
      " interaction phase is the BEHAVIOR_ILLEGAL_STATEMENT of section 50.
      " ZCL_EINV_ELT_INGEST~parse_writeback therefore does the dynamic
      " mapping and the backfill and hands back a filled ZTEINV_DOC row;
      " this is the behaviour pool, so this is where it may be written,
      " and it goes into the SAME LT_UPDATE and the SAME MODIFY ENTITIES
      " below rather than a second one. One row, one update, one LUW.
      "
      " The platform's own status wins over the submit result's: HANA
      " writes the payload's STATUS, and a platform that answers FAILURE
      " with a reason is more informative than SUBMITTED. The submit
      " status set above stays for the case where no write-back arrives.
      "---------------------------------------------------------------
      IF ls_res-has_wb = abap_true.
        DATA(ls_wb) = ls_res-writeback.

        <ls_upd>-%control-SyncStatus         = if_abap_behv=>mk-on.
        <ls_upd>-SyncStatus                  = ls_wb-status.

        <ls_upd>-%control-ErrorText          = if_abap_behv=>mk-on.
        <ls_upd>-ErrorText                   = ls_wb-error.

        <ls_upd>-%control-ClearDocumentId    = if_abap_behv=>mk-on.
        <ls_upd>-ClearDocumentId             = ls_wb-invid.

        <ls_upd>-%control-EInvoiceNumber     = if_abap_behv=>mk-on.
        <ls_upd>-EInvoiceNumber              = ls_wb-invno.

        <ls_upd>-%control-EInvoiceDate       = if_abap_behv=>mk-on.
        <ls_upd>-EInvoiceDate                = ls_wb-invdt.

        <ls_upd>-%control-PlatformUuid       = if_abap_behv=>mk-on.
        <ls_upd>-PlatformUuid                = ls_wb-uuid.

        <ls_upd>-%control-SignedQrCode       = if_abap_behv=>mk-on.
        <ls_upd>-SignedQrCode                = ls_wb-zsigned_qrcode.

        <ls_upd>-%control-SignedInvoice      = if_abap_behv=>mk-on.
        <ls_upd>-SignedInvoice               = ls_wb-zsigned_inv.

        <ls_upd>-%control-EInvoiceIdentifier = if_abap_behv=>mk-on.
        <ls_upd>-EInvoiceIdentifier          = ls_wb-einv_identifier.

        <ls_upd>-%control-EInvoiceType       = if_abap_behv=>mk-on.
        <ls_upd>-EInvoiceType                = ls_wb-einv_type.

        <ls_upd>-%control-DocumentTypeCode   = if_abap_behv=>mk-on.
        <ls_upd>-DocumentTypeCode            = ls_wb-doc_type.

        <ls_upd>-%control-IsB2C              = if_abap_behv=>mk-on.
        <ls_upd>-IsB2C                       = ls_wb-b2c.

        " CRDAT / CRTIME / CRUSER are NOT carried over. HANA sets them
        " on every write-back, which makes "created" mean "last
        " answered". Here the row already exists with its real creation
        " stamp from PickUpDocuments, and overwriting it would lose the
        " only record of when the document entered the worklist.
        " LocalLastChangedAt covers "when did this last change".
      ENDIF.

      IF ls_res-success = abap_false.
        APPEND VALUE #( %tky = ls_doc-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = CONV string( ls_res-message ) ) )
               TO reported-einvoice.
      ENDIF.
    ENDLOOP.

    " The field list has to name every field any row might carry, not
    " just the four the submit result fills: a field left out of UPDATE
    " FIELDS is ignored even when its %control flag is on, which is a
    " silent way to lose the whole write-back.
    MODIFY ENTITIES OF zcds_int_einv_doc IN LOCAL MODE
      ENTITY einvoice
        UPDATE FIELDS ( SyncStatus ErrorText CommandId IsSent
                        ClearDocumentId EInvoiceNumber EInvoiceDate
                        PlatformUuid SignedQrCode SignedInvoice
                        EInvoiceIdentifier EInvoiceType
                        DocumentTypeCode IsB2C )
        WITH lt_update
      REPORTED DATA(ls_rep)
      FAILED   DATA(ls_fail).

    " What the inner EML call reports has to be carried into this handler's
    " own REPORTED/FAILED. Declaring it and dropping it on the floor is how
    " a failed write ends up looking like a successful action.
    reported-einvoice = VALUE #( BASE reported-einvoice ( LINES OF ls_rep-einvoice ) ).
    failed-einvoice   = VALUE #( BASE failed-einvoice   ( LINES OF ls_fail-einvoice ) ).

    READ ENTITIES OF zcds_int_einv_doc IN LOCAL MODE
      ENTITY einvoice
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_final).

    result = VALUE #( FOR ls_f IN lt_final
                      ( %tky = ls_f-%tky %param = ls_f ) ).
  ENDMETHOD.


**********************************************************************
* RefreshStatus
**********************************************************************

  METHOD refreshstatus.
    " Everything below runs inside a RAP LUW, so the ELT instrumentation
    " must not write to the database as it goes - see the saver.
    zcl_instru_event_class=>gv_defer = abap_true.

    " HANA equivalent: get_status -> call_get_status.
    "
    " get_status derived the transaction type with a LEFT OUTER JOIN of
    " /CLR/ZT_EINV to /CLR/EINV_DOCTYP and appended '_B2C' when the B2C
    " flag was set; call_get_status then did the HTTP GET with
    " cl_http_client and wrote the result back with a direct
    " UPDATE /clr/zt_einv. Both steps are kept, but the derivation lives
    " in ZCL_EINV_CONFIG and the write-back goes through EML.
    READ ENTITIES OF zcds_int_einv_doc IN LOCAL MODE
      ENTITY einvoice
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_doc).

    DATA(lo_config) = zcl_einv_config=>get_instance( ).
    DATA(lo_api)    = NEW zcl_einv_api_client( ).
    DATA lt_update     TYPE TABLE FOR UPDATE zcds_int_einv_doc.
    DATA lt_err_create TYPE TABLE FOR CREATE zcds_int_einv_doc\_Error.
    " No DATA lv_idx here: the `INDEX INTO lv_idx` of the FOR expression
    " below declares it itself, and declaring it twice is an error.

    " The documents that actually got an answer from the platform. Only
    " these are written, and only their old error rows are cleared - see
    " the guard inside the loop. Section 80.
    DATA lt_refreshed LIKE lt_doc.

    " The government reporting history. LT_PPF_CLEAR holds the documents
    " whose history is being REPLACED - a response with no government
    " block leaves the stored history alone, so those keys stay out of it.
    " Section 81.
    DATA lt_ppf_create TYPE TABLE FOR CREATE zcds_int_einv_doc\_Ppf.
    DATA lt_ppf_clear  LIKE lt_doc.

    LOOP AT lt_doc INTO DATA(ls_doc).

      IF ls_doc-ClearDocumentId IS INITIAL.
        " /CLR/ZME_EINV 018 "Select at least one document" became a
        " per-row precondition, since Fiori selection is per row.
        APPEND VALUE #( %tky = ls_doc-%tky
                        %msg = new_message( id       = 'ZEINV_MSG'
                                            number   = '005'
                                            severity = if_abap_behv_message=>severity-error ) )
               TO reported-einvoice.
        CONTINUE.
      ENDIF.

      DATA(lv_trans_type) = lo_config->get_transaction_type(
                              iv_bukrs    = ls_doc-CompanyCode
                              iv_doc_type = ls_doc-DocumentTypeCode
                              iv_b2c      = ls_doc-IsB2C ).

      DATA(ls_status) = lo_api->get_status(
                          iv_bukrs     = ls_doc-CompanyCode
                          iv_doc_id    = CONV string( ls_doc-ClearDocumentId )
                          iv_doc_type  = lv_trans_type ).

      " ---- DO NOT OVERWRITE A GOOD STATUS WITH A BAD CALL --------------
      " /CLR/ZCL_EINV_BASE~call_get_status wrapped its
      "   UPDATE /clr/zt_einv SET status = ... error = ...
      " in three nested guards:
      "
      "   IF lv_status = 200.                 " HTTP 200 only
      "     IF ls_response IS NOT INITIAL.    " a body that parsed
      "       IF sy-subrc IS INITIAL.         " the row was found
      "
      " The first conversion dropped all three and wrote unconditionally.
      " GET_STATUS returns an EMPTY status on a transport error, on an
      " empty body and on a non-200 response - so one unreachable endpoint
      " turned a stored VALID into blank, for every row the user had
      " selected. The status column is the one thing this screen exists to
      " show, and pressing Refresh was enough to erase it.
      "
      " Nothing is written unless the platform actually answered. The user
      " is told why instead. Section 80.
      IF ls_status-success = abap_false OR ls_status-status IS INITIAL.
        APPEND VALUE #(
            %tky = ls_doc-%tky
            %msg = new_message_with_text(
                     severity = if_abap_behv_message=>severity-warning
                     text     = COND #(
                       WHEN ls_status-message IS NOT INITIAL
                       THEN |Status not refreshed: { ls_status-message }|
                       ELSE |Status not refreshed: no status in the | &&
                            |platform response (HTTP { ls_status-http })| ) ) )
          TO reported-einvoice.
        CONTINUE.
      ENDIF.

      APPEND ls_doc TO lt_refreshed.

      " ---- the government (PPF) reporting block ------------------------
      " HANA's second deserialize pass, save_ppf_details, and the three
      " GOVT_ fields of /CLR/ZT_EINV. Section 81.
      flatten_ppf(
        EXPORTING it_govt       = ls_status-govt
                  is_key        = CORRESPONDING #( ls_doc )
                  iv_doc_id     = ls_doc-ClearDocumentId
        IMPORTING et_rows       = DATA(lt_ppf_rows)
                  ev_ppf_status = DATA(lv_ppf_status)
                  ev_ppf_action = DATA(lv_ppf_action) ).

      IF lt_ppf_rows IS NOT INITIAL.
        APPEND ls_doc TO lt_ppf_clear.
        APPEND VALUE #(
            %tky   = ls_doc-%tky
            %target = VALUE #( FOR ls_p IN lt_ppf_rows
                               ( %cid = |PPF{ ls_doc-CompanyCode }| &&
                                        |{ ls_doc-AccountingDocument }| &&
                                        |{ ls_doc-FiscalYear }| &&
                                        |{ ls_p-SequenceNumber }| &&
                                        |{ ls_p-ReasonNumber }|
                                 BillingDocument      = ls_doc-BillingDocument
                                 AccountingDocument   = ls_doc-AccountingDocument
                                 CompanyCode          = ls_doc-CompanyCode
                                 FiscalYear           = ls_doc-FiscalYear
                                 SequenceNumber       = ls_p-SequenceNumber
                                 ReasonNumber         = ls_p-ReasonNumber
                                 ClearDocumentId      = ls_p-ClearDocumentId
                                 TransactionId        = ls_p-TransactionId
                                 PpfAction            = ls_p-PpfAction
                                 PpfActionType        = ls_p-PpfActionType
                                 PpfStatus            = ls_p-PpfStatus
                                 ReceivedDate         = ls_p-ReceivedDate
                                 ReceivedTime         = ls_p-ReceivedTime
                                 ReceivedMilliseconds = ls_p-ReceivedMilliseconds
                                 ReasonCode           = ls_p-ReasonCode
                                 ReasonText           = ls_p-ReasonText
                                 CreatedOn            = zcl_einv_util=>get_system_date( )
                                 CreatedAt            = zcl_einv_util=>get_system_time( )
                                 CreatedBy            = zcl_einv_util=>get_user_name( ) ) ) )
          TO lt_ppf_create.
      ENDIF.

      " call_get_status concatenated every _error_details-_error_message
      " into one string; the detail rows are now persisted as children
      " so the object page can list them individually.
      "
      " The QR code is written only when the response carried one -
      " HANA's `IF ls_response-_qr_code IS NOT INITIAL` - and the three
      " GOVT_ fields only when a government block came back.
      "
      " HANA writes the GOVT_ fields unconditionally, which blanks a
      " previously reported government status whenever the platform
      " answers without a GovtReportingDetails array. Its own
      " save_ppf_details header says an empty array "leaves the stored
      " history untouched", and the commented-out
      " `IF lv_ppf_status IS NOT INITIAL.` still sits above that UPDATE,
      " so the intent is not in doubt. Guarded here, for the same reason
      " as section 80.
      APPEND VALUE #(
          %tky                      = ls_doc-%tky
          %control-SyncStatus       = if_abap_behv=>mk-on
          %control-ErrorText        = if_abap_behv=>mk-on
          %control-SignedQrCode     = COND #( WHEN ls_status-qr_code IS NOT INITIAL
                                              THEN if_abap_behv=>mk-on
                                              ELSE if_abap_behv=>mk-off )
          %control-GovernmentStatus = COND #( WHEN lv_ppf_status IS NOT INITIAL
                                              THEN if_abap_behv=>mk-on
                                              ELSE if_abap_behv=>mk-off )
          %control-PpfStatus        = COND #( WHEN lv_ppf_status IS NOT INITIAL
                                              THEN if_abap_behv=>mk-on
                                              ELSE if_abap_behv=>mk-off )
          %control-PpfAction        = COND #( WHEN lv_ppf_status IS NOT INITIAL
                                              THEN if_abap_behv=>mk-on
                                              ELSE if_abap_behv=>mk-off )
          SyncStatus                = ls_status-status
          ErrorText                 = ls_status-message
          SignedQrCode              = ls_status-qr_code
          GovernmentStatus          = lv_ppf_status
          PpfStatus                 = lv_ppf_status
          PpfAction                 = lv_ppf_action )
        TO lt_update.

      IF ls_status-errors IS NOT INITIAL.
        APPEND VALUE #(
            %tky    = ls_doc-%tky
            %target = VALUE #( FOR ls_err IN ls_status-errors INDEX INTO lv_idx
                               ( %cid               = |ERR{ ls_doc-CompanyCode }{ ls_doc-AccountingDocument }{ ls_doc-FiscalYear }{ lv_idx }|
                                 BillingDocument    = ls_doc-BillingDocument
                                 AccountingDocument = ls_doc-AccountingDocument
                                 CompanyCode        = ls_doc-CompanyCode
                                 FiscalYear         = ls_doc-FiscalYear
                                 EInvoiceNumber     = ls_doc-EInvoiceNumber
                                 ErrorNumber        = lv_idx
                                 ErrorDate          = zcl_einv_util=>get_system_date( )
                                 ErrorTime          = zcl_einv_util=>get_system_time( )
                                 ErrorCode          = ls_err-error_code
                                 ErrorSource        = ls_err-error_source
                                 ErrorMessage       = ls_err-error_message ) ) )
          TO lt_err_create.
      ENDIF.
    ENDLOOP.

    " ERRORNO is part of the key of ZTEINV_ERR, so numbering the details of
    " one refresh 1..n would collide with the details the previous refresh
    " left behind. call_get_status had no such problem because it kept the
    " messages in one concatenated string; here the old detail rows are
    " cleared first and the new ones are numbered from scratch.
    "
    " Cleared for the REFRESHED documents only. This used to run before
    " the loop, against every selected key, so a document whose status
    " call failed lost the error detail it already had and got nothing in
    " return - the same destruction as the status overwrite above, one
    " level down. Section 80.
    IF lt_refreshed IS NOT INITIAL.
      READ ENTITIES OF zcds_int_einv_doc IN LOCAL MODE
        ENTITY einvoice BY \_Error
          FIELDS ( ErrorNumber ) WITH CORRESPONDING #( lt_refreshed )
        RESULT DATA(lt_old_err).

      IF lt_old_err IS NOT INITIAL.
        MODIFY ENTITIES OF zcds_int_einv_doc IN LOCAL MODE
          ENTITY einvoiceerror
            DELETE FROM VALUE #( FOR ls_o IN lt_old_err ( %tky = ls_o-%tky ) )
          REPORTED DATA(ls_rep_del)
          FAILED   DATA(ls_fail_del).

        reported-einvoiceerror = VALUE #( BASE reported-einvoiceerror
                                          ( LINES OF ls_rep_del-einvoiceerror ) ).
        failed-einvoiceerror   = VALUE #( BASE failed-einvoiceerror
                                          ( LINES OF ls_fail_del-einvoiceerror ) ).
      ENDIF.
    ENDIF.

    " One CREATE for every refreshed document, after the delete. It used to
    " sit inside the loop, which was correct only because LT_ERR_CREATE was
    " CLEARed on each pass; the table now accumulates, so the statement
    " belongs here.
    IF lt_err_create IS NOT INITIAL.
      MODIFY ENTITIES OF zcds_int_einv_doc IN LOCAL MODE
        ENTITY einvoice
          CREATE BY \_Error
            FIELDS ( BillingDocument AccountingDocument CompanyCode FiscalYear
                     EInvoiceNumber ErrorNumber ErrorDate ErrorTime
                     ErrorCode ErrorSource ErrorMessage )
            WITH lt_err_create
        REPORTED DATA(ls_rep_err)
        FAILED   DATA(ls_fail_err).

      reported-einvoiceerror = VALUE #( BASE reported-einvoiceerror
                                        ( LINES OF ls_rep_err-einvoiceerror ) ).
      failed-einvoiceerror   = VALUE #( BASE failed-einvoiceerror
                                        ( LINES OF ls_fail_err-einvoiceerror ) ).
    ENDIF.

    " ---- the government reporting history ------------------------------
    " HANA: DELETE FROM /clr/zt_einv_ppf WHERE <document> + INSERT FROM
    " TABLE ACCEPTING DUPLICATE KEYS - a full replace per document.
    " Neither statement is legal in the RAP interaction phase, so the
    " replace runs through the composition: delete the children, create
    " the new set. ACCEPTING DUPLICATE KEYS has no equivalent and needs
    " none, because the delete has already cleared the key range.
    " Section 81.
    IF lt_ppf_clear IS NOT INITIAL.
      READ ENTITIES OF zcds_int_einv_doc IN LOCAL MODE
        ENTITY einvoice BY \_Ppf
          FIELDS ( SequenceNumber ReasonNumber )
          WITH CORRESPONDING #( lt_ppf_clear )
        RESULT DATA(lt_old_ppf).

      IF lt_old_ppf IS NOT INITIAL.
        MODIFY ENTITIES OF zcds_int_einv_doc IN LOCAL MODE
          ENTITY einvoiceppf
            DELETE FROM VALUE #( FOR ls_op IN lt_old_ppf ( %tky = ls_op-%tky ) )
          REPORTED DATA(ls_rep_pdel)
          FAILED   DATA(ls_fail_pdel).

        reported-einvoiceppf = VALUE #( BASE reported-einvoiceppf
                                        ( LINES OF ls_rep_pdel-einvoiceppf ) ).
        failed-einvoiceppf   = VALUE #( BASE failed-einvoiceppf
                                        ( LINES OF ls_fail_pdel-einvoiceppf ) ).
      ENDIF.
    ENDIF.

    IF lt_ppf_create IS NOT INITIAL.
      MODIFY ENTITIES OF zcds_int_einv_doc IN LOCAL MODE
        ENTITY einvoice
          CREATE BY \_Ppf
            FIELDS ( BillingDocument AccountingDocument CompanyCode FiscalYear
                     SequenceNumber ReasonNumber ClearDocumentId TransactionId
                     PpfAction PpfActionType PpfStatus
                     ReceivedDate ReceivedTime ReceivedMilliseconds
                     ReasonCode ReasonText CreatedOn CreatedAt CreatedBy )
            WITH lt_ppf_create
        REPORTED DATA(ls_rep_pcre)
        FAILED   DATA(ls_fail_pcre).

      reported-einvoiceppf = VALUE #( BASE reported-einvoiceppf
                                      ( LINES OF ls_rep_pcre-einvoiceppf ) ).
      failed-einvoiceppf   = VALUE #( BASE failed-einvoiceppf
                                      ( LINES OF ls_fail_pcre-einvoiceppf ) ).
    ENDIF.

    IF lt_update IS NOT INITIAL.
      MODIFY ENTITIES OF zcds_int_einv_doc IN LOCAL MODE
        ENTITY einvoice
          UPDATE FIELDS ( SyncStatus ErrorText SignedQrCode
                          GovernmentStatus PpfStatus PpfAction )
          WITH lt_update
        REPORTED DATA(ls_rep)
        FAILED   DATA(ls_fail).

      reported-einvoice = VALUE #( BASE reported-einvoice ( LINES OF ls_rep-einvoice ) ).
      failed-einvoice   = VALUE #( BASE failed-einvoice   ( LINES OF ls_fail-einvoice ) ).
    ENDIF.

    READ ENTITIES OF zcds_int_einv_doc IN LOCAL MODE
      ENTITY einvoice
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_final).

    result = VALUE #( FOR ls_f IN lt_final
                      ( %tky = ls_f-%tky %param = ls_f ) ).
  ENDMETHOD.


**********************************************************************
* RequestPrintout
**********************************************************************

  METHOD requestprintout.
    " Everything below runs inside a RAP LUW, so the ELT instrumentation
    " must not write to the database as it goes - see the saver.
    zcl_instru_event_class=>gv_defer = abap_true.

    " HANA equivalent: print_pdf -> call_print_pdf, which ended in
    "   SCMS_XSTRING_TO_BINARY
    "   cl_gui_frontend_services=>file_save_dialog
    "   SCMS_DOWNLOAD ... frontend = 'X'
    " i.e. it wrote the PDF straight onto the user's workstation.
    "
    " None of that exists in Public Cloud. The PDF is stored in
    " ZTEINV_PDF with @Semantics.largeObject, and the Fiori app offers
    " it as a stream download - which also means the printout is
    " reproducible and auditable instead of living in a user's
    " Downloads folder.
    READ ENTITIES OF zcds_int_einv_doc IN LOCAL MODE
      ENTITY einvoice
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_doc).

    DATA(lo_config) = zcl_einv_config=>get_instance( ).
    DATA(lo_api)    = NEW zcl_einv_api_client( ).

    LOOP AT lt_doc INTO DATA(ls_doc).

      IF ls_doc-ClearDocumentId IS INITIAL.
        APPEND VALUE #( %tky = ls_doc-%tky
                        %msg = new_message( id       = 'ZEINV_MSG'
                                            number   = '005'
                                            severity = if_abap_behv_message=>severity-error ) )
               TO reported-einvoice.
        CONTINUE.
      ENDIF.

      DATA(lv_trans_type) = lo_config->get_transaction_type(
                              iv_bukrs    = ls_doc-CompanyCode
                              iv_doc_type = ls_doc-DocumentTypeCode
                              iv_b2c      = ls_doc-IsB2C ).

      DATA(ls_pdf) = lo_api->get_printout(
                       iv_bukrs    = ls_doc-CompanyCode
                       iv_doc_id   = CONV string( ls_doc-ClearDocumentId )
                       iv_doc_type = lv_trans_type ).

      IF ls_pdf-success = abap_false.
        APPEND VALUE #( %tky = ls_doc-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = ls_pdf-message ) )
               TO reported-einvoice.
        CONTINUE.
      ENDIF.

      " The store is a plain table, not part of the BO composition, so
      " it is written in the save phase of this LUW via a small helper
      " rather than with EML.
      NEW zcl_einv_pdf_store( )->stage(
        is_key     = VALUE #( vbeln = ls_doc-BillingDocument
                              belnr = ls_doc-AccountingDocument
                              bukrs = ls_doc-CompanyCode
                              gjahr = ls_doc-FiscalYear )
        iv_doc_id  = ls_doc-ClearDocumentId
        iv_filename = |EINV_{ ls_doc-AccountingDocument }.pdf|
        iv_content = ls_pdf-content ).

      APPEND VALUE #( %tky = ls_doc-%tky
                      %msg = new_message( id       = 'ZEINV_MSG'
                                          number   = '021'
                                          severity = if_abap_behv_message=>severity-success
                                          v1       = ls_doc-AccountingDocument ) )
             TO reported-einvoice.
    ENDLOOP.

    READ ENTITIES OF zcds_int_einv_doc IN LOCAL MODE
      ENTITY einvoice
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_final).

    result = VALUE #( FOR ls_f IN lt_final
                      ( %tky = ls_f-%tky %param = ls_f ) ).
  ENDMETHOD.


**********************************************************************
* SellerAction
**********************************************************************

  METHOD selleraction.
    " Everything below runs inside a RAP LUW, so the ELT instrumentation
    " must not write to the database as it goes - see the saver.
    zcl_instru_event_class=>gv_defer = abap_true.

    " HANA equivalent: dynpro 0200 (include
    " /CLR/ELT_EINVOICE_COCKPIT_SO01) plus call_seller_action.
    "
    " The old code hand-assembled the JSON body with string templates:
    "   '{"documentId":"' && iv_doc_id && '","actionType":...'
    " and escaped only some values. Here the payload is a typed
    " structure (ZSTR_EINV_ACT_REQ) that the serializer renders, so
    " quoting and escaping cannot be got wrong.
    READ ENTITIES OF zcds_int_einv_doc IN LOCAL MODE
      ENTITY einvoice
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_doc).

    DATA(lo_api) = NEW zcl_einv_api_client( ).
    DATA lt_update TYPE TABLE FOR UPDATE zcds_int_einv_doc.
    DATA lt_split  TYPE zstr_einv_vatsplit_tt.
    " The error detail rows of a REJECTED seller action. Section 84.
    DATA lt_sa_err TYPE TABLE FOR CREATE zcds_int_einv_doc\_Error.

    LOOP AT keys INTO DATA(ls_key).
      DATA(ls_doc) = VALUE #( lt_doc[ KEY entity
                                      BillingDocument    = ls_key-BillingDocument
                                      AccountingDocument = ls_key-AccountingDocument
                                      CompanyCode        = ls_key-CompanyCode
                                      FiscalYear         = ls_key-FiscalYear ]
                              OPTIONAL ).
      DATA(ls_par) = ls_key-%param.

      IF ls_doc-CompanyCode IS INITIAL.
        APPEND VALUE #( %tky = ls_key-%tky ) TO failed-einvoice.
        APPEND VALUE #( %tky = ls_key-%tky
                        %msg = new_message( id       = 'ZEINV_MSG'
                                            number   = '037'
                                            severity = if_abap_behv_message=>severity-error ) )
               TO reported-einvoice.
        CONTINUE.
      ENDIF.

      IF ls_doc-ClearDocumentId IS INITIAL.
        APPEND VALUE #( %tky = ls_key-%tky
                        %msg = new_message( id       = 'ZEINV_MSG'
                                            number   = '005'
                                            severity = if_abap_behv_message=>severity-error ) )
               TO reported-einvoice.
        CONTINUE.
      ENDIF.

      " f_submit_seller_action insisted on a collection date for
      " CONFIRM_PAYMENT; keep the rule but state it as a message.
      IF ls_par-ActionType = zcl_einv_api_client=>gc_action-confirm_payment
         AND ls_par-CollectionDate IS INITIAL.
        APPEND VALUE #( %tky = ls_key-%tky
                        %msg = new_message( id       = 'ZEINV_MSG'
                                            number   = '022'
                                            severity = if_abap_behv_message=>severity-error ) )
               TO reported-einvoice.
        CONTINUE.
      ENDIF.

      " Four flat rate/amount pairs rather than the composition the
      " abstract entity used to declare: the generated %param structure
      " carries no child table, so `ls_par-_VatSplit` does not exist.
      " See CONVERSION_DESIGN.md §19.4 - four covers every VAT regime this
      " add-on has met, and a child entity on the business object is the
      " way to lift the limit.
      CLEAR lt_split.
      IF ls_par-VatRate1 IS NOT INITIAL OR ls_par-VatAmount1 IS NOT INITIAL.
        APPEND VALUE #( rate                        = ls_par-VatRate1
                        amountcollectedincludingvat = ls_par-VatAmount1 ) TO lt_split.
      ENDIF.
      IF ls_par-VatRate2 IS NOT INITIAL OR ls_par-VatAmount2 IS NOT INITIAL.
        APPEND VALUE #( rate                        = ls_par-VatRate2
                        amountcollectedincludingvat = ls_par-VatAmount2 ) TO lt_split.
      ENDIF.
      IF ls_par-VatRate3 IS NOT INITIAL OR ls_par-VatAmount3 IS NOT INITIAL.
        APPEND VALUE #( rate                        = ls_par-VatRate3
                        amountcollectedincludingvat = ls_par-VatAmount3 ) TO lt_split.
      ENDIF.
      IF ls_par-VatRate4 IS NOT INITIAL OR ls_par-VatAmount4 IS NOT INITIAL.
        APPEND VALUE #( rate                        = ls_par-VatRate4
                        amountcollectedincludingvat = ls_par-VatAmount4 ) TO lt_split.
      ENDIF.

      DATA(ls_res) = lo_api->post_seller_action(
                       iv_bukrs       = ls_doc-CompanyCode
                       iv_doc_id      = CONV string( ls_doc-ClearDocumentId )
                       iv_action_type = ls_par-ActionType
                       iv_coll_date   = ls_par-CollectionDate
                       iv_comment     = CONV string( ls_par-CommentText )
                       it_vat_split   = lt_split ).

      APPEND VALUE #(
          %tky                = ls_key-%tky
          %control-SyncStatus = if_abap_behv=>mk-on
          %control-ErrorText  = if_abap_behv=>mk-on
          SyncStatus          = ls_res-status
          ErrorText           = ls_res-message )
        TO lt_update.

      IF ls_res-success = abap_true.
        " call_seller_action deleted the stale error rows on success
        "   DELETE FROM /clr/zt_einv_err WHERE checkbox = '' AND ...
        " Same intent, expressed as EML on the child entity.
        READ ENTITIES OF zcds_int_einv_doc IN LOCAL MODE
          ENTITY einvoice BY \_Error
            FIELDS ( ErrorNumber ) WITH VALUE #( ( %tky = ls_key-%tky ) )
          RESULT DATA(lt_old_err).

        IF lt_old_err IS NOT INITIAL.
          MODIFY ENTITIES OF zcds_int_einv_doc IN LOCAL MODE
            ENTITY einvoiceerror
              DELETE FROM VALUE #( FOR ls_o IN lt_old_err ( %tky = ls_o-%tky ) )
            REPORTED DATA(ls_rep_del)
            FAILED   DATA(ls_fail_del).

          reported-einvoiceerror = VALUE #( BASE reported-einvoiceerror
                                            ( LINES OF ls_rep_del-einvoiceerror ) ).
          failed-einvoiceerror   = VALUE #( BASE failed-einvoiceerror
                                            ( LINES OF ls_fail_del-einvoiceerror ) ).
        ENDIF.
      ELSE.
        APPEND VALUE #( %tky = ls_key-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = CONV string( ls_res-message ) ) )
               TO reported-einvoice.

        " THE FAILURE BRANCH WRITES THE ERROR ROWS TOO.
        " call_seller_action has both halves:
        "
        "   IF success.  DELETE FROM /clr/zt_einv_err WHERE ...
        "   ELSE.        LOOP AT _error_details ... MODIFY FROM TABLE
        "
        " The conversion kept only the DELETE, so a rejected seller
        " action left the API Errors tab empty and the whole explanation
        " collapsed into the one-line ErrorText. The detail rows are what
        " the tab is for. Section 84.
        IF ls_res-errors IS NOT INITIAL.
          APPEND VALUE #(
              %tky    = ls_key-%tky
              %target = VALUE #( FOR ls_e IN ls_res-errors INDEX INTO lv_eidx
                                 ( %cid               = |SAERR{ ls_doc-CompanyCode }| &&
                                                        |{ ls_doc-AccountingDocument }| &&
                                                        |{ ls_doc-FiscalYear }{ lv_eidx }|
                                   BillingDocument    = ls_doc-BillingDocument
                                   AccountingDocument = ls_doc-AccountingDocument
                                   CompanyCode        = ls_doc-CompanyCode
                                   FiscalYear         = ls_doc-FiscalYear
                                   EInvoiceNumber     = ls_doc-EInvoiceNumber
                                   ErrorNumber        = lv_eidx
                                   ErrorDate          = zcl_einv_util=>get_system_date( )
                                   ErrorTime          = zcl_einv_util=>get_system_time( )
                                   ErrorCode          = ls_e-error_code
                                   ErrorSource        = ls_e-error_source
                                   ErrorMessage       = ls_e-error_message ) ) )
            TO lt_sa_err.
        ENDIF.
      ENDIF.
    ENDLOOP.

    " ERRORNO is part of the key, so the previous attempt's rows are
    " cleared before the new ones are numbered from 1 - the same reasoning
    " as refreshstatus, and the reason the success branch above deletes
    " rather than leaving them.
    IF lt_sa_err IS NOT INITIAL.
      READ ENTITIES OF zcds_int_einv_doc IN LOCAL MODE
        ENTITY einvoice BY \_Error
          FIELDS ( ErrorNumber )
          WITH VALUE #( FOR ls_c IN lt_sa_err ( %tky = ls_c-%tky ) )
        RESULT DATA(lt_prev_err).

      IF lt_prev_err IS NOT INITIAL.
        MODIFY ENTITIES OF zcds_int_einv_doc IN LOCAL MODE
          ENTITY einvoiceerror
            DELETE FROM VALUE #( FOR ls_p IN lt_prev_err ( %tky = ls_p-%tky ) )
          REPORTED DATA(ls_rep_pdel)
          FAILED   DATA(ls_fail_pdel).

        reported-einvoiceerror = VALUE #( BASE reported-einvoiceerror
                                          ( LINES OF ls_rep_pdel-einvoiceerror ) ).
        failed-einvoiceerror   = VALUE #( BASE failed-einvoiceerror
                                          ( LINES OF ls_fail_pdel-einvoiceerror ) ).
      ENDIF.

      MODIFY ENTITIES OF zcds_int_einv_doc IN LOCAL MODE
        ENTITY einvoice
          CREATE BY \_Error
            FIELDS ( BillingDocument AccountingDocument CompanyCode FiscalYear
                     EInvoiceNumber ErrorNumber ErrorDate ErrorTime
                     ErrorCode ErrorSource ErrorMessage )
            WITH lt_sa_err
        REPORTED DATA(ls_rep_sae)
        FAILED   DATA(ls_fail_sae).

      reported-einvoiceerror = VALUE #( BASE reported-einvoiceerror
                                        ( LINES OF ls_rep_sae-einvoiceerror ) ).
      failed-einvoiceerror   = VALUE #( BASE failed-einvoiceerror
                                        ( LINES OF ls_fail_sae-einvoiceerror ) ).
    ENDIF.

    MODIFY ENTITIES OF zcds_int_einv_doc IN LOCAL MODE
      ENTITY einvoice
        UPDATE FIELDS ( SyncStatus ErrorText )
        WITH lt_update
      REPORTED DATA(ls_rep)
      FAILED   DATA(ls_fail).

    reported-einvoice = VALUE #( BASE reported-einvoice ( LINES OF ls_rep-einvoice ) ).
    failed-einvoice   = VALUE #( BASE failed-einvoice   ( LINES OF ls_fail-einvoice ) ).

    READ ENTITIES OF zcds_int_einv_doc IN LOCAL MODE
      ENTITY einvoice
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_final).

    result = VALUE #( FOR ls_f IN lt_final
                      ( %tky = ls_f-%tky %param = ls_f ) ).
  ENDMETHOD.


**********************************************************************
* CancelEInvoice
**********************************************************************

  METHOD canceleinvoice.
    " Everything below runs inside a RAP LUW, so the ELT instrumentation
    " must not write to the database as it goes - see the saver.
    zcl_instru_event_class=>gv_defer = abap_true.

    " /CLR/ZCL_EINV_BASE~cancel and ~call_cancel were EMPTY, and none of
    " /CLR/ZCL_EINV_AE, _FR, _OM overrode them - so in the HANA package
    " the "Cancel e-Invoice" button did nothing at all. This is the
    " first working implementation; the rules come from the message
    " texts of /CLR/ZME_EINV (074, 075, 078, 089, 090) and are enforced
    " by the country handler, which can tighten them per country.
    READ ENTITIES OF zcds_int_einv_doc IN LOCAL MODE
      ENTITY einvoice
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_doc).

    DATA(lt_enr) = read_enrichment( CORRESPONDING #( keys ) ).
    DATA(lo_api) = NEW zcl_einv_api_client( ).
    DATA lt_update TYPE TABLE FOR UPDATE zcds_int_einv_doc.

    LOOP AT keys INTO DATA(ls_key).
      DATA(ls_doc) = VALUE #( lt_doc[ KEY entity
                                      BillingDocument    = ls_key-BillingDocument
                                      AccountingDocument = ls_key-AccountingDocument
                                      CompanyCode        = ls_key-CompanyCode
                                      FiscalYear         = ls_key-FiscalYear ]
                              OPTIONAL ).

      " A key the READ did not return no longer exists or is not visible to
      " this user. Without the check the cancellation would be sent to the
      " platform with an empty document id and an empty company code.
      IF ls_doc-CompanyCode IS INITIAL.
        APPEND VALUE #( %tky = ls_key-%tky ) TO failed-einvoice.
        APPEND VALUE #( %tky = ls_key-%tky
                        %msg = new_message( id       = 'ZEINV_MSG'
                                            number   = '037'
                                            severity = if_abap_behv_message=>severity-error ) )
               TO reported-einvoice.
        CONTINUE.
      ENDIF.

      IF ls_doc-ClearDocumentId IS INITIAL.
        APPEND VALUE #( %tky = ls_key-%tky
                        %msg = new_message( id       = 'ZEINV_MSG'
                                            number   = '005'
                                            severity = if_abap_behv_message=>severity-error ) )
               TO reported-einvoice.
        CONTINUE.
      ENDIF.

      DATA(ls_enr) = VALUE #( lt_enr[ BillingDocument    = ls_key-BillingDocument
                                      AccountingDocument = ls_key-AccountingDocument
                                      CompanyCode        = ls_key-CompanyCode
                                      FiscalYear         = ls_key-FiscalYear ]
                              OPTIONAL ).

      DATA(lo_country) = zcl_einv_country_factory=>get_handler( iv_bukrs = ls_doc-CompanyCode ).

      DATA(lv_reason) = lo_country->check_cancel_allowed(
                          iv_bukrs      = ls_doc-CompanyCode
                          iv_created_on = ls_doc-CreatedOn
                          iv_created_at = ls_doc-CreatedAt
                          iv_status     = ls_enr-EffectiveStatus ).

      IF lv_reason IS NOT INITIAL.
        APPEND VALUE #( %tky = ls_key-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = lv_reason ) )
               TO reported-einvoice.
        CONTINUE.
      ENDIF.

      DATA(ls_res) = lo_api->post_cancel(
                       iv_bukrs       = ls_doc-CompanyCode
                       iv_doc_id      = CONV string( ls_doc-ClearDocumentId )
                       iv_doc_type    = CONV string( ls_doc-DocumentTypeCode )
                       iv_reason_code = ls_key-%param-ReasonCode
                       iv_comment     = CONV string( ls_key-%param-CommentText ) ).

      APPEND VALUE #(
          %tky                = ls_key-%tky
          %control-SyncStatus = if_abap_behv=>mk-on
          %control-ErrorText  = if_abap_behv=>mk-on
          SyncStatus          = COND #( WHEN ls_res-success = abap_true
                                        THEN gc_status-cancelled
                                        ELSE gc_status-error )
          ErrorText           = ls_res-message )
        TO lt_update.

      IF ls_res-success = abap_false.
        APPEND VALUE #( %tky = ls_key-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = CONV string( ls_res-message ) ) )
               TO reported-einvoice.
      ENDIF.
    ENDLOOP.

    MODIFY ENTITIES OF zcds_int_einv_doc IN LOCAL MODE
      ENTITY einvoice
        UPDATE FIELDS ( SyncStatus ErrorText )
        WITH lt_update
      REPORTED DATA(ls_rep)
      FAILED   DATA(ls_fail).

    reported-einvoice = VALUE #( BASE reported-einvoice ( LINES OF ls_rep-einvoice ) ).
    failed-einvoice   = VALUE #( BASE failed-einvoice   ( LINES OF ls_fail-einvoice ) ).

    READ ENTITIES OF zcds_int_einv_doc IN LOCAL MODE
      ENTITY einvoice
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_final).

    result = VALUE #( FOR ls_f IN lt_final
                      ( %tky = ls_f-%tky %param = ls_f ) ).
  ENDMETHOD.


**********************************************************************
* Helpers
**********************************************************************

  METHOD flatten_ppf.

    CLEAR: et_rows, ev_ppf_status, ev_ppf_action.

    " HANA: IF it_govt IS INITIAL. RETURN. ENDIF.
    " "nothing reported to PPF yet" - and an empty array must leave the
    " stored history alone rather than wipe it.
    IF it_govt IS INITIAL.
      RETURN.
    ENDIF.

    DATA lv_max_key TYPE string.
    DATA lv_max_seq TYPE i.

    LOOP AT it_govt INTO DATA(ls_govt).
      DATA(lv_seq) = sy-tabix.

      zcl_einv_api_client=>iso_ts_split(
        EXPORTING iv_iso  = ls_govt-received_at
        IMPORTING ev_date = DATA(lv_date)
                  ev_time = DATA(lv_time)
                  ev_msec = DATA(lv_msec)
                  ev_key  = DATA(lv_key) ).

      " ---- latest entry: highest instant, tie-break = last array index -
      " An unparsable ReceivedAt gives LV_KEY = SPACE and therefore never
      " wins over a real timestamp. Verbatim from HANA, including the
      " >= on the tie-break, which is what makes "last index" win.
      IF lv_key > lv_max_key OR
       ( lv_key = lv_max_key AND lv_seq >= lv_max_seq ).
        lv_max_key    = lv_key.
        lv_max_seq    = lv_seq.
        ev_ppf_status = ls_govt-status.
        ev_ppf_action = ls_govt-action.
      ENDIF.

      " ---- header part of the row -------------------------------------
      DATA ls_row TYPE ty_ppf_row.
      CLEAR ls_row.
      ls_row-SequenceNumber       = lv_seq.
      ls_row-ClearDocumentId      = iv_doc_id.
      ls_row-TransactionId        = ls_govt-transaction_id.
      ls_row-PpfAction            = ls_govt-action.
      ls_row-PpfActionType        = ls_govt-action_type.
      ls_row-PpfStatus            = ls_govt-status.
      ls_row-ReceivedDate         = lv_date.    " UTC, as stamped by PPF
      ls_row-ReceivedTime         = lv_time.    " UTC, as stamped by PPF
      ls_row-ReceivedMilliseconds = lv_msec.

      IF ls_govt-status_reasons IS INITIAL.
        " RSNNO 000 keeps the reporting entry itself when the authority
        " gave no reason for it. Without this row the entry would vanish
        " from the history for the most ordinary case there is: success.
        ls_row-ReasonNumber = 0.
        APPEND ls_row TO et_rows.
      ELSE.
        LOOP AT ls_govt-status_reasons INTO DATA(ls_rsn).
          ls_row-ReasonNumber = sy-tabix.
          ls_row-ReasonCode   = ls_rsn-code.

          DATA lv_text TYPE string.
          CLEAR lv_text.
          LOOP AT ls_rsn-messages INTO DATA(lv_msg).
            IF lv_text IS INITIAL.
              lv_text = lv_msg.
            ELSE.
              lv_text = |{ lv_text }; { lv_msg }|.
            ENDIF.
          ENDLOOP.
          ls_row-ReasonText = lv_text.

          APPEND ls_row TO et_rows.
        ENDLOOP.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD read_enrichment.
    IF it_keys IS INITIAL.
      RETURN.
    ENDIF.

    SELECT BillingDocument, AccountingDocument, CompanyCode, FiscalYear,
           EffectiveStatus, EffectiveMessage, TransactionCurrency,
           IsReversed, IsReversal
      FROM zcds_int_einv_doc_enr
      FOR ALL ENTRIES IN @it_keys
      WHERE BillingDocument    = @it_keys-BillingDocument
        AND AccountingDocument = @it_keys-AccountingDocument
        AND CompanyCode        = @it_keys-CompanyCode
        AND FiscalYear         = @it_keys-FiscalYear
      INTO CORRESPONDING FIELDS OF TABLE @rt_enr.
  ENDMETHOD.


ENDCLASS.

**********************************************************************
* Additional save
*
* abapGit's class serializer recognises exactly four local includes:
*   .clas.locals_def.abap  .clas.locals_imp.abap
*   .clas.macros.abap      .clas.testclasses.abap
* A file named .clas.locals_saver_imp.abap is silently ignored on pull,
* so the saver class has to live here or `with additional save` finds no
* LSC_* class and the behaviour definition does not activate.
**********************************************************************

*"* Additional save of the Sales e-Invoice business object.
*"*
*"* Its only job is to flush the printout buffer of ZCL_EINV_PDF_STORE.
*"* ZTEINV_PDF holds a raw binary and is deliberately NOT part of the BO
*"* composition, so it cannot be written with EML - but it must still be
*"* written inside the same unit of work as the status update.
*"*
*"* This is what replaces the explicit COMMIT WORK statements of the
*"* HANA package. /CLR/AP_EINVOICE~get_documents committed once per
*"* inserted row (inside an ENQUEUE_E_TABLE / DEQUEUE_E_TABLE bracket),
*"* and call_seller_action had its COMMIT WORK commented out entirely,
*"* relying on the implicit commit at the next screen change. Neither is
*"* permitted from a RAP handler; here the framework owns the commit.

CLASS lsc_zcds_int_einv_doc DEFINITION INHERITING FROM cl_abap_behavior_saver.

  PROTECTED SECTION.

    METHODS save_modified REDEFINITION.
    METHODS cleanup_finalize REDEFINITION.

ENDCLASS.


CLASS lsc_zcds_int_einv_doc IMPLEMENTATION.

  METHOD save_modified.
    NEW zcl_einv_pdf_store( )->save( ).

    " The extract archive kept for the DATA_ZIP diagnostic. Same reasoning
    " and same shape as the printout above - a binary too large for the BO
    " composition, staged during the action and written here.
    NEW zcl_einv_zip_store( )->save( ).

    " The ELT instrumentation buffers its event-log rows while a RAP LUW is
    " active - INSERT and COMMIT WORK are both forbidden there, and the
    " first submit from the Fiori cockpit terminated with
    " BEHAVIOR_ILLEGAL_STATEMENT inside ZCL_INSTRU_EVENT_CLASS. The save
    " phase is where a database write is legal, so this is where they go.
    zcl_instru_event_class=>flush( ).
  ENDMETHOD.

  METHOD cleanup_finalize.
    " The staging buffer of ZCL_EINV_PDF_STORE is CLASS-DATA, so a LUW that
    " requested a printout and was then discarded would leave the PDF bytes
    " in the session and the next save would write them out.
    NEW zcl_einv_pdf_store( )->discard( ).
    NEW zcl_einv_zip_store( )->discard( ).

    " Same reasoning for the held-back telemetry. Note the consequence: a
    " LUW that is rolled back loses its event-log rows. The HANA version
    " committed them immediately and so kept the diagnostics of a failed
    " call. That is a real loss, and the price of the RAP contract - if the
    " failure diagnostics matter more than consistency, they need a second
    " LUW rather than a COMMIT inside this one.
    zcl_instru_event_class=>discard( ).
  ENDMETHOD.

ENDCLASS.
