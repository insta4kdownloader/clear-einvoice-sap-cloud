*"* Behaviour implementation of the live e-Invoice worklist.
*"*
*"* This business object owns no data. ZCDS_CUN_EINV_WORKLIST is a
*"* read-only view over live candidates - a row is there because a journal
*"* entry or billing document matches ZTEINV_INVMAP, not because anything
*"* was stored (section 39 of CONVERSION_DESIGN.md). Every action here
*"* therefore does one of two things and nothing else:
*"*
*"*   1. materialise the candidate as a ZTEINV_DOC row, if it has none,
*"*      by executing ZCDS_INT_EINV_DOC's own PickUpDocuments,
*"*   2. delegate to the matching action of ZCDS_INT_EINV_DOC with EML.
*"*
*"* No HTTP call, no status logic and no message text lives in this class.
*"* All of that stays in ZBP_CDS_INT_EINV_DOC, which is the only place it
*"* was ever implemented, so the worklist and the cockpit can never drift
*"* apart in behaviour.
*"*
*"* NO `IN LOCAL MODE` on any EML here. That addition is only legal inside
*"* the behaviour pool of the business object it names; from this class it
*"* produced "The operation can only be used in implementations of
*"* behavior definition ZCDS_INT_EINV_DOC". Going through the external
*"* layer is the right thing anyway: ZCDS_INT_EINV_DOC's own feature
*"* control and authorization are then evaluated, so the worklist cannot
*"* submit a document the cockpit itself would have refused. The called BO
*"* joins this LUW and is saved in the same save sequence, so there is no
*"* COMMIT ENTITIES here.
*"*
*"* That same external layer is why materialisation delegates to
*"* PickUpDocuments instead of issuing its own CREATE: SyncStatus is
*"* `field ( readonly )` on ZCDS_INT_EINV_DOC, and readonly is enforced
*"* from outside. PickUpDocuments sets it from inside its own pool, where
*"* it may. Delegating also means the duplicate filter, the field defaults
*"* and the selection logic stay in one place.
*"*
*"* Key translation: the worklist key has eight fields (the four document
*"* fields plus the four the join to ZTEINV_INVMAP contributes); the
*"* business object key has four. Going down is a projection; coming back
*"* up - mapping a message raised against a document onto the worklist row
*"* that asked for it - is a lookup in the action's own key table. That
*"* translation is why each action repeats the same ten lines instead of
*"* calling a shared helper: a RAP derived type (REPORTED / FAILED ...) is
*"* not accepted in a method signature.

CLASS lhc_worklist DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    CONSTANTS:
      BEGIN OF gc_status,
        cancelled TYPE zde_einv_status VALUE 'CANCELLED',
      END OF gc_status.

    " Typed off the VIEW, not off the data elements of ZTEINV_DOC. The
    " worklist's CompanyCode comes from I_JournalEntry and its type is not
    " necessarily ZDE_EINV_BUKRS; typing off the view keeps every
    " CORRESPONDING in this class lossless whatever the release does.
    TYPES:
      BEGIN OF ty_key,
        CompanyCode        TYPE zcds_cun_einv_worklist-companycode,
        AccountingDocument TYPE zcds_cun_einv_worklist-accountingdocument,
        FiscalYear         TYPE zcds_cun_einv_worklist-fiscalyear,
        BillingDocument    TYPE zcds_cun_einv_worklist-billingdocument,
        ProjectId          TYPE zcds_cun_einv_worklist-projectid,
        SystemId           TYPE zcds_cun_einv_worklist-systemid,
        Country            TYPE zcds_cun_einv_worklist-country,
        DocumentTypeCode   TYPE zcds_cun_einv_worklist-documenttypecode,
      END OF ty_key,
      ty_keys TYPE STANDARD TABLE OF ty_key WITH EMPTY KEY.

    " An explicit field list, NOT the whole view. SignedQrCode and
    " SignedInvoice are LOB columns, and selecting a LOB under
    " FOR ALL ENTRIES is rejected: the addition implies DISTINCT, which a
    " LOB cannot take part in. Nothing here needs either of them.
    TYPES:
      BEGIN OF ty_row,
        CompanyCode        TYPE zcds_cun_einv_worklist-companycode,
        AccountingDocument TYPE zcds_cun_einv_worklist-accountingdocument,
        FiscalYear         TYPE zcds_cun_einv_worklist-fiscalyear,
        BillingDocument    TYPE zcds_cun_einv_worklist-billingdocument,
        ProjectId          TYPE zcds_cun_einv_worklist-projectid,
        SystemId           TYPE zcds_cun_einv_worklist-systemid,
        Country            TYPE zcds_cun_einv_worklist-country,
        DocumentTypeCode   TYPE zcds_cun_einv_worklist-documenttypecode,
        DocumentDate       TYPE zcds_cun_einv_worklist-documentdate,
        PostingDate        TYPE zcds_cun_einv_worklist-postingdate,
        EInvoiceDocumentId TYPE zcds_cun_einv_worklist-einvoicedocumentid,
        EInvoiceNumber     TYPE zcds_cun_einv_worklist-einvoicenumber,
        EffectiveStatus    TYPE zcds_cun_einv_worklist-effectivestatus,
        EffectiveMessage   TYPE zcds_cun_einv_worklist-effectivemessage,
        IsProcessed        TYPE zcds_cun_einv_worklist-isprocessed,
        IsB2C              TYPE zcds_cun_einv_worklist-isb2c,
      END OF ty_row,
      ty_rows TYPE STANDARD TABLE OF ty_row WITH EMPTY KEY.

    METHODS lock FOR LOCK
      IMPORTING keys FOR LOCK worklist.

    METHODS read FOR READ
      IMPORTING keys FOR READ worklist
      RESULT result.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR worklist
      RESULT result.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR worklist
      RESULT result.

    METHODS worklistpickup FOR MODIFY
      IMPORTING keys FOR ACTION worklist~worklistpickup.

    METHODS worklistsubmiteinvoice FOR MODIFY
      IMPORTING keys FOR ACTION worklist~worklistsubmiteinvoice.

    METHODS worklistrefreshstatus FOR MODIFY
      IMPORTING keys FOR ACTION worklist~worklistrefreshstatus.

    METHODS worklistrequestprintout FOR MODIFY
      IMPORTING keys FOR ACTION worklist~worklistrequestprintout.

    METHODS worklistselleraction FOR MODIFY
      IMPORTING keys FOR ACTION worklist~worklistselleraction.

    METHODS worklistcanceleinvoice FOR MODIFY
      IMPORTING keys FOR ACTION worklist~worklistcanceleinvoice.

    "! The worklist rows behind a set of action keys. Plain ABAP SQL, not
    "! READ ENTITIES: the view IS the source, and reading the BO here would
    "! recurse into this class's own READ.
    METHODS read_rows
      IMPORTING it_keys        TYPE ty_keys
      RETURNING VALUE(rt_rows) TYPE ty_rows.

    "! Creates a ZTEINV_DOC row for every given candidate that has none, by
    "! executing ZCDS_INT_EINV_DOC's own PickUpDocuments once per document.
    METHODS materialise
      IMPORTING it_rows TYPE ty_rows.

ENDCLASS.


CLASS lhc_worklist IMPLEMENTATION.

**********************************************************************
* Lock, read and save - the three the framework insists on
**********************************************************************

  METHOD lock.
    " Deliberately empty. strict ( 2 ) requires every entity to be lock
    " master or lock dependent, so the behaviour definition says
    " `lock master` and RAP asks for this method - but there is nothing
    " here to lock. The worklist has no persistent state of its own: a row
    " is a live candidate computed from I_JournalEntry and ZTEINV_INVMAP.
    "
    " What does need locking is the ZTEINV_DOC row, and that is locked by
    " ZCDS_INT_EINV_DOC when an action's EML modify runs against it - the
    " managed business object owns its own lock, as it should. A second
    " lock here would widen the window and protect nothing.
  ENDMETHOD.


  METHOD read.
    " An unmanaged behaviour must implement READ even when the list itself
    " is served by the query engine rather than by the business object.
    " It is reached when an action returns and the framework refreshes the
    " instance, and it is one SELECT - the view already computes
    " everything.
    DATA(lt_row) = read_rows( CORRESPONDING #( keys ) ).

    LOOP AT keys INTO DATA(ls_key).
      DATA(ls_row) = VALUE #( lt_row[ companycode        = ls_key-CompanyCode
                                      accountingdocument = ls_key-AccountingDocument
                                      fiscalyear         = ls_key-FiscalYear
                                      billingdocument    = ls_key-BillingDocument ]
                              OPTIONAL ).

      " A candidate can disappear between two reads - the journal entry is
      " reversed, or the mapping row is deleted. That is NOT_FOUND, not an
      " empty row, or the UI shows a blank line where a document was.
      IF ls_row IS INITIAL.
        APPEND VALUE #( %tky        = ls_key-%tky
                        %fail-cause = if_abap_behv=>cause-not_found )
               TO failed-worklist.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( BASE CORRESPONDING #( ls_row )
                      %tky = ls_key-%tky )
             TO result.
    ENDLOOP.
  ENDMETHOD.


**********************************************************************
* Authorization and feature control
**********************************************************************

  METHOD get_instance_authorizations.
    " Nothing is restricted at instance level yet, exactly as on
    " ZCDS_INT_EINV_DOC: the company-code restriction belongs in the IAM
    " business role and is evaluated once that restriction field exists.
    " The authorization master is declared because strict ( 2 ) requires
    " one for a behaviour that has instance feature control.
    LOOP AT keys INTO DATA(ls_key).
      APPEND VALUE #( %tky                    = ls_key-%tky
                      %action-WorklistPickUp          = if_abap_behv=>auth-allowed
                      %action-WorklistSubmitEInvoice  = if_abap_behv=>auth-allowed
                      %action-WorklistRefreshStatus   = if_abap_behv=>auth-allowed
                      %action-WorklistRequestPrintout = if_abap_behv=>auth-allowed
                      %action-WorklistSellerAction    = if_abap_behv=>auth-allowed
                      %action-WorklistCancelEInvoice  = if_abap_behv=>auth-allowed )
             TO result.
    ENDLOOP.
  ENDMETHOD.


  METHOD get_instance_features.
    " The worklist's enablement rules differ from the cockpit's in exactly
    " one place: Submit is enabled on a row that has no document at all,
    " because Submit materialises it. In the cockpit such a row cannot
    " exist - it is there only once it has been picked up.
    DATA(lt_row) = read_rows( CORRESPONDING #( keys ) ).

    LOOP AT keys INTO DATA(ls_key).
      DATA(ls_row) = VALUE #( lt_row[ companycode        = ls_key-CompanyCode
                                      accountingdocument = ls_key-AccountingDocument
                                      fiscalyear         = ls_key-FiscalYear
                                      billingdocument    = ls_key-BillingDocument ]
                              OPTIONAL ).

      " Pick Up: only a candidate that has no row yet. On an already
      " materialised row the button would be a no-op.
      DATA(lv_pickup) = COND #( WHEN ls_row-isprocessed IS INITIAL
                                THEN if_abap_behv=>fc-o-enabled
                                ELSE if_abap_behv=>fc-o-disabled ).

      " Submit: no Clear document id yet, or an error to retry. Same
      " eligibility rule as submit_data, with "no row at all" folded in -
      " an unprocessed candidate has an initial document id too.
      DATA(lv_submit) = COND #(
        WHEN ls_row-einvoicedocumentid IS INITIAL
          OR ls_row-effectivemessage   IS NOT INITIAL
        THEN if_abap_behv=>fc-o-enabled
        ELSE if_abap_behv=>fc-o-disabled ).

      " Status / print / seller action need a document the platform knows.
      DATA(lv_has_id) = COND #( WHEN ls_row-einvoicedocumentid IS NOT INITIAL
                                THEN if_abap_behv=>fc-o-enabled
                                ELSE if_abap_behv=>fc-o-disabled ).

      DATA(lv_cancel) = COND #(
        WHEN ls_row-einvoicedocumentid IS NOT INITIAL
         AND ls_row-effectivestatus    <> gc_status-cancelled
        THEN if_abap_behv=>fc-o-enabled
        ELSE if_abap_behv=>fc-o-disabled ).

      APPEND VALUE #( %tky                    = ls_key-%tky
                      %action-WorklistPickUp          = lv_pickup
                      %action-WorklistSubmitEInvoice  = lv_submit
                      %action-WorklistRefreshStatus   = lv_has_id
                      %action-WorklistRequestPrintout = lv_has_id
                      %action-WorklistSellerAction    = lv_has_id
                      %action-WorklistCancelEInvoice  = lv_cancel )
             TO result.
    ENDLOOP.
  ENDMETHOD.


**********************************************************************
* Actions
**********************************************************************

  METHOD worklistpickup.
    " The explicit half of what Submit does implicitly: create the
    " ZTEINV_DOC row and stop there.
    materialise( read_rows( CORRESPONDING #( keys ) ) ).
  ENDMETHOD.


  METHOD worklistsubmiteinvoice.
    DATA(lt_key) = CORRESPONDING ty_keys( keys ).
    DATA(lt_row) = read_rows( lt_key ).

    " Materialise first. A candidate with no ZTEINV_DOC row cannot be
    " submitted, and refusing it here would make the button useless on
    " exactly the rows the worklist exists to show.
    materialise( lt_row ).

    MODIFY ENTITIES OF zcds_int_einv_doc
      ENTITY einvoice
        EXECUTE SubmitEInvoice
        FROM VALUE #( FOR r IN lt_row
                      ( %tky-BillingDocument    = r-billingdocument
                        %tky-AccountingDocument = r-accountingdocument
                        %tky-CompanyCode        = r-companycode
                        %tky-FiscalYear         = r-fiscalyear ) )
      REPORTED DATA(ls_rep)
      FAILED   DATA(ls_fail).

    " Relay the business object's messages onto the worklist rows that
    " asked for them. Without this the user sees a silent button: the
    " message exists but is addressed to a key the UI never sent.
    LOOP AT ls_rep-einvoice INTO DATA(ls_r).
      DATA(ls_k) = VALUE #( lt_key[ CompanyCode        = ls_r-CompanyCode
                                    AccountingDocument = ls_r-AccountingDocument
                                    FiscalYear         = ls_r-FiscalYear
                                    BillingDocument    = ls_r-BillingDocument ]
                            OPTIONAL ).
      CHECK ls_k IS NOT INITIAL.
      APPEND VALUE #( %tky = CORRESPONDING #( ls_k ) %msg = ls_r-%msg )
             TO reported-worklist.
    ENDLOOP.

    LOOP AT ls_fail-einvoice INTO DATA(ls_x).
      ls_k = VALUE #( lt_key[ CompanyCode        = ls_x-CompanyCode
                              AccountingDocument = ls_x-AccountingDocument
                              FiscalYear         = ls_x-FiscalYear
                              BillingDocument    = ls_x-BillingDocument ]
                      OPTIONAL ).
      CHECK ls_k IS NOT INITIAL.
      APPEND VALUE #( %tky = CORRESPONDING #( ls_k ) %fail = ls_x-%fail )
             TO failed-worklist.
    ENDLOOP.
  ENDMETHOD.


  METHOD worklistrefreshstatus.
    DATA(lt_key) = CORRESPONDING ty_keys( keys ).

    MODIFY ENTITIES OF zcds_int_einv_doc
      ENTITY einvoice
        EXECUTE RefreshStatus
        FROM VALUE #( FOR k IN lt_key
                      ( %tky-BillingDocument    = k-BillingDocument
                        %tky-AccountingDocument = k-AccountingDocument
                        %tky-CompanyCode        = k-CompanyCode
                        %tky-FiscalYear         = k-FiscalYear ) )
      REPORTED DATA(ls_rep)
      FAILED   DATA(ls_fail).

    LOOP AT ls_rep-einvoice INTO DATA(ls_r).
      DATA(ls_k) = VALUE #( lt_key[ CompanyCode        = ls_r-CompanyCode
                                    AccountingDocument = ls_r-AccountingDocument
                                    FiscalYear         = ls_r-FiscalYear
                                    BillingDocument    = ls_r-BillingDocument ]
                            OPTIONAL ).
      CHECK ls_k IS NOT INITIAL.
      APPEND VALUE #( %tky = CORRESPONDING #( ls_k ) %msg = ls_r-%msg )
             TO reported-worklist.
    ENDLOOP.

    LOOP AT ls_fail-einvoice INTO DATA(ls_x).
      ls_k = VALUE #( lt_key[ CompanyCode        = ls_x-CompanyCode
                              AccountingDocument = ls_x-AccountingDocument
                              FiscalYear         = ls_x-FiscalYear
                              BillingDocument    = ls_x-BillingDocument ]
                      OPTIONAL ).
      CHECK ls_k IS NOT INITIAL.
      APPEND VALUE #( %tky = CORRESPONDING #( ls_k ) %fail = ls_x-%fail )
             TO failed-worklist.
    ENDLOOP.
  ENDMETHOD.


  METHOD worklistrequestprintout.
    DATA(lt_key) = CORRESPONDING ty_keys( keys ).

    MODIFY ENTITIES OF zcds_int_einv_doc
      ENTITY einvoice
        EXECUTE RequestPrintout
        FROM VALUE #( FOR k IN lt_key
                      ( %tky-BillingDocument    = k-BillingDocument
                        %tky-AccountingDocument = k-AccountingDocument
                        %tky-CompanyCode        = k-CompanyCode
                        %tky-FiscalYear         = k-FiscalYear ) )
      REPORTED DATA(ls_rep)
      FAILED   DATA(ls_fail).

    LOOP AT ls_rep-einvoice INTO DATA(ls_r).
      DATA(ls_k) = VALUE #( lt_key[ CompanyCode        = ls_r-CompanyCode
                                    AccountingDocument = ls_r-AccountingDocument
                                    FiscalYear         = ls_r-FiscalYear
                                    BillingDocument    = ls_r-BillingDocument ]
                            OPTIONAL ).
      CHECK ls_k IS NOT INITIAL.
      APPEND VALUE #( %tky = CORRESPONDING #( ls_k ) %msg = ls_r-%msg )
             TO reported-worklist.
    ENDLOOP.

    LOOP AT ls_fail-einvoice INTO DATA(ls_x).
      ls_k = VALUE #( lt_key[ CompanyCode        = ls_x-CompanyCode
                              AccountingDocument = ls_x-AccountingDocument
                              FiscalYear         = ls_x-FiscalYear
                              BillingDocument    = ls_x-BillingDocument ]
                      OPTIONAL ).
      CHECK ls_k IS NOT INITIAL.
      APPEND VALUE #( %tky = CORRESPONDING #( ls_k ) %fail = ls_x-%fail )
             TO failed-worklist.
    ENDLOOP.
  ENDMETHOD.


  METHOD worklistselleraction.
    " Carries a parameter, so the action rows are built one by one and
    " %param is handed straight through to the business object.
    DATA(lt_key) = CORRESPONDING ty_keys( keys ).
    DATA lt_act TYPE TABLE FOR ACTION IMPORT zcds_int_einv_doc~SellerAction.

    LOOP AT keys INTO DATA(ls_key).
      APPEND VALUE #( %tky-BillingDocument    = ls_key-BillingDocument
                      %tky-AccountingDocument = ls_key-AccountingDocument
                      %tky-CompanyCode        = ls_key-CompanyCode
                      %tky-FiscalYear         = ls_key-FiscalYear
                      %param                  = ls_key-%param )
             TO lt_act.
    ENDLOOP.

    MODIFY ENTITIES OF zcds_int_einv_doc
      ENTITY einvoice
        EXECUTE SellerAction FROM lt_act
      REPORTED DATA(ls_rep)
      FAILED   DATA(ls_fail).

    LOOP AT ls_rep-einvoice INTO DATA(ls_r).
      DATA(ls_k) = VALUE #( lt_key[ CompanyCode        = ls_r-CompanyCode
                                    AccountingDocument = ls_r-AccountingDocument
                                    FiscalYear         = ls_r-FiscalYear
                                    BillingDocument    = ls_r-BillingDocument ]
                            OPTIONAL ).
      CHECK ls_k IS NOT INITIAL.
      APPEND VALUE #( %tky = CORRESPONDING #( ls_k ) %msg = ls_r-%msg )
             TO reported-worklist.
    ENDLOOP.

    LOOP AT ls_fail-einvoice INTO DATA(ls_x).
      ls_k = VALUE #( lt_key[ CompanyCode        = ls_x-CompanyCode
                              AccountingDocument = ls_x-AccountingDocument
                              FiscalYear         = ls_x-FiscalYear
                              BillingDocument    = ls_x-BillingDocument ]
                      OPTIONAL ).
      CHECK ls_k IS NOT INITIAL.
      APPEND VALUE #( %tky = CORRESPONDING #( ls_k ) %fail = ls_x-%fail )
             TO failed-worklist.
    ENDLOOP.
  ENDMETHOD.


  METHOD worklistcanceleinvoice.
    DATA(lt_key) = CORRESPONDING ty_keys( keys ).
    DATA lt_act TYPE TABLE FOR ACTION IMPORT zcds_int_einv_doc~CancelEInvoice.

    LOOP AT keys INTO DATA(ls_key).
      APPEND VALUE #( %tky-BillingDocument    = ls_key-BillingDocument
                      %tky-AccountingDocument = ls_key-AccountingDocument
                      %tky-CompanyCode        = ls_key-CompanyCode
                      %tky-FiscalYear         = ls_key-FiscalYear
                      %param                  = ls_key-%param )
             TO lt_act.
    ENDLOOP.

    MODIFY ENTITIES OF zcds_int_einv_doc
      ENTITY einvoice
        EXECUTE CancelEInvoice FROM lt_act
      REPORTED DATA(ls_rep)
      FAILED   DATA(ls_fail).

    LOOP AT ls_rep-einvoice INTO DATA(ls_r).
      DATA(ls_k) = VALUE #( lt_key[ CompanyCode        = ls_r-CompanyCode
                                    AccountingDocument = ls_r-AccountingDocument
                                    FiscalYear         = ls_r-FiscalYear
                                    BillingDocument    = ls_r-BillingDocument ]
                            OPTIONAL ).
      CHECK ls_k IS NOT INITIAL.
      APPEND VALUE #( %tky = CORRESPONDING #( ls_k ) %msg = ls_r-%msg )
             TO reported-worklist.
    ENDLOOP.

    LOOP AT ls_fail-einvoice INTO DATA(ls_x).
      ls_k = VALUE #( lt_key[ CompanyCode        = ls_x-CompanyCode
                              AccountingDocument = ls_x-AccountingDocument
                              FiscalYear         = ls_x-FiscalYear
                              BillingDocument    = ls_x-BillingDocument ]
                      OPTIONAL ).
      CHECK ls_k IS NOT INITIAL.
      APPEND VALUE #( %tky = CORRESPONDING #( ls_k ) %fail = ls_x-%fail )
             TO failed-worklist.
    ENDLOOP.
  ENDMETHOD.


**********************************************************************
* Helpers
**********************************************************************

  METHOD read_rows.
    IF it_keys IS INITIAL.
      RETURN.
    ENDIF.

    " The mandatory-filter annotations on ZCDS_CUN_EINV_WORKLIST are a
    " consumption contract for the list report; ABAP SQL is not bound by
    " them, so selecting by key alone is correct here.
    "
    " An explicit field list, not SELECT *: SignedQrCode and SignedInvoice
    " are LOB columns and FOR ALL ENTRIES implies DISTINCT, which a LOB
    " cannot take part in. Nothing in this class reads either of them.
    SELECT companycode, accountingdocument, fiscalyear, billingdocument,
           projectid, systemid, country, documenttypecode,
           documentdate, postingdate,
           einvoicedocumentid, einvoicenumber,
           effectivestatus, effectivemessage, isprocessed, isb2c
      FROM zcds_cun_einv_worklist
      FOR ALL ENTRIES IN @it_keys
      WHERE companycode        = @it_keys-CompanyCode
        AND accountingdocument = @it_keys-AccountingDocument
        AND fiscalyear         = @it_keys-FiscalYear
        AND billingdocument    = @it_keys-BillingDocument
      INTO CORRESPONDING FIELDS OF TABLE @rt_rows.
  ENDMETHOD.


  METHOD materialise.
    IF it_rows IS INITIAL.
      RETURN.
    ENDIF.

    " Delegate to ZCDS_INT_EINV_DOC's own PickUpDocuments rather than
    " issuing a CREATE here. Two reasons, and the first one is binding:
    "
    "   SyncStatus is `field ( readonly )` on ZCDS_INT_EINV_DOC, and
    "   readonly is enforced on the external layer - which is the only
    "   layer this class can use. PickUpDocuments sets it from inside its
    "   own behaviour pool, where it may.
    "
    "   And the duplicate filter (ZCL_EINV_WORKLIST~keep_new), the field
    "   defaults and the relevance selection then stay in one place
    "   instead of being copied here and left to drift.
    "
    " One action row per document: the parameters are a selection range,
    " and naming the document exactly is what makes it select that one.
    " PickUpDocuments refuses a call with no date range AND no document
    " number, so AccountingDocument or BillingDocument being filled is
    " what gets this past its own guard.
    DATA lt_act TYPE TABLE FOR ACTION IMPORT zcds_int_einv_doc~PickUpDocuments.
    DATA lv_seq TYPE i.

    LOOP AT it_rows INTO DATA(ls_row).
      lv_seq += 1.
      APPEND VALUE #( %cid                      = |WL{ lv_seq }|
                      %param-ProjectId          = ls_row-projectid
                      %param-CompanyCode        = ls_row-companycode
                      %param-BillingDocument    = ls_row-billingdocument
                      %param-AccountingDocument = ls_row-accountingdocument
                      %param-FiscalYear         = ls_row-fiscalyear )
             TO lt_act.
    ENDLOOP.

    " Messages are not relayed: PickUpDocuments reports against its own
    " action %cid, which no caller of this helper can address, and a
    " candidate that is already materialised is silently skipped by
    " keep_new rather than reported. The caller's own EXECUTE reports what
    " the user needs to see.
    MODIFY ENTITIES OF zcds_int_einv_doc
      ENTITY einvoice
        EXECUTE PickUpDocuments FROM lt_act
      REPORTED DATA(ls_rep)
      FAILED   DATA(ls_fail).
  ENDMETHOD.

ENDCLASS.


**********************************************************************
* Saver
**********************************************************************
*"* An unmanaged behaviour must have a saver class even when it saves
*"* nothing. This one saves nothing: the worklist has no persistent state.
*"* Everything the actions change is written by ZCDS_INT_EINV_DOC, which
*"* is a managed business object with its own save sequence and joins this
*"* LUW through the EML calls above.
CLASS lsc_zcds_cun_einv_worklist DEFINITION INHERITING FROM cl_abap_behavior_saver.

  PROTECTED SECTION.

    METHODS save REDEFINITION.

ENDCLASS.

CLASS lsc_zcds_cun_einv_worklist IMPLEMENTATION.

  METHOD save.
  ENDMETHOD.

ENDCLASS.
