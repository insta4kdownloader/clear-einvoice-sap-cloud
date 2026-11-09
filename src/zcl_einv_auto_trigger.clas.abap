"! <p class="shorttext synchronized">e-Invoice: automatic generation on posting</p>
"!
"! Replaces /CLR/ZCL_ELT_EINVOICE (BAdI implementation
"! /CLR/BADI_IMP_ELT_EINV on BAdI definition /CLR/BADI_ELT_EINVOICE)
"! and the two classic enhancement implementations that called it:
"!
"!   /CLR/ELT_EINVOICE_SD_CREATE
"!     \FU:RV_INVOICE_REFRESH\SE:BEGIN  ->  DATA(lt_xvbrk) = xvbrk[].
"!     \FU:RV_INVOICE_REFRESH\SE:END    ->  GET BADI ... CALL BADI per row
"!
"!   /CLR/ELT_EINVOICE_FI_CREATE
"!     \PR:SAPMF05A\FO:TRANSAKTION_VERLASSEN\SE:BEGIN
"!       -> read the dynpro program's global XBKPF and CALL BADI
"!
"! >>> THIS IS THE ONE PART OF THE CONVERSION WITH NO DIRECT
"!     REPLACEMENT, AND IT NEEDS A DECISION BEFORE IT CAN GO LIVE. <<<
"!
"! Source-code plug-ins into SAP's own function modules and dynpro
"! programs cannot exist in Public Cloud, and there is no way to read
"! SAPMF05A's global XBKPF from outside. The three ways to drive this
"! logic in the cloud, in order of preference:
"!
"!  1. BUSINESS EVENTS (recommended). Subscribe to the released
"!     billing-document and journal-entry events through Enterprise
"!     Event Enablement and call on_document_posted( ) from the event
"!     consumer class. Closest in spirit to the old hook, decoupled,
"!     and it survives upgrades.
"!
"!  2. A RELEASED BAdI, if one exists for the posting transaction in
"!     your release. Check the Extensibility Explorer; then call
"!     on_document_posted( ) from the BAdI implementation.
"!
"!  3. POLLING via ZCL_EINV_PICKUP_JOB with a short interval and
"!     P_SUBMIT = 'X'. No extension point needed at all, at the cost of
"!     latency between posting and submission. This is what the
"!     delivered package does by default, so nothing is left dangling.
"!
"! The relevance logic itself is fully ported below, so whichever
"! trigger you wire up, the decision rules are identical to
"! /CLR/ZCL_ELT_EINVOICE~einv_ewb_create.
CLASS zcl_einv_auto_trigger DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES: BEGIN OF ty_result,
             relevant TYPE abap_boolean,
             submitted TYPE abap_boolean,
             status   TYPE zde_einv_status,
             message  TYPE zde_einv_errmsg,
           END OF ty_result.

    "! Entry point for whichever extension mechanism you wire up.
    "!
    "! Signature deliberately mirrors
    "! /CLR/ZIF_ELT_EINVOICE~EINV_EWB_CREATE, minus the parameters that
    "! only made sense inside a dynpro program (I_TCODE, I_UCOMM):
    "! transaction codes do not exist in Fiori, and the AUTO_IRN
    "! whitelist that compared sy-tcode against ZTEINV_CONST-LOW has no
    "! meaning any more. See the note on the whitelist below.
    METHODS on_document_posted
      IMPORTING iv_bukrs         TYPE zde_einv_bukrs
                iv_belnr         TYPE zde_einv_accdoc OPTIONAL
                iv_gjahr         TYPE zde_einv_gjahr OPTIONAL
                iv_vbeln         TYPE zde_einv_billdoc OPTIONAL
      RETURNING VALUE(rs_result) TYPE ty_result.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_einv_auto_trigger IMPLEMENTATION.


  METHOD on_document_posted.

    DATA(lo_config) = zcl_einv_config=>get_instance( ).

    " Step 1 of einv_ewb_create:
    "   SELECT SINGLE land1, bukrs, sequence, auto_einv_generate,
    "                 auto_einv_cancel
    "     FROM /clr/einv_cntry
    "     WHERE bukrs = @i_bukrs AND sysid = @sy-sysid.
    "   IF auto_einv_generate <> 'X'. RETURN. ENDIF.
    IF lo_config->is_auto_generate_active( iv_bukrs ) = abap_false.
      RETURN.
    ENDIF.

    " Step 2 was the transaction-code whitelist:
    "   SELECT ... FROM /clr/einv_const
    "     WHERE product = 'EINV' AND zlabel = 'AUTO_IRN'
    "       AND low = @i_tcode AND high = 'EINV'.
    " sy-tcode does not exist in a Fiori/RAP world, so the whitelist is
    " not ported. If the intent was "only auto-generate for these entry
    " channels", express it as a document-type restriction in
    " ZTEINV_INVMAP instead - which the next step already evaluates.

    " Step 3 + 4: resolve the document pair and find the INVMAP row.
    " einv_ewb_create did the VBRK <-> BKPF resolution by hand via
    " AWKEY/AWTYP and then tried six INVMAP key combinations in
    " sequence. ZCDS_INT_EINV_RELEVANT already encodes both, so one
    " read answers "is this document e-invoice relevant".
    SELECT SINGLE FROM ZCDS_INT_EINV_RELEVANT
      FIELDS BillingDocument, AccountingDocument, CompanyCode, FiscalYear,
             AccountingDocumentType, BillingDocumentType,
             DocumentTypeCode, IsB2C, DocumentDate
      WHERE CompanyCode = @iv_bukrs
        AND ( @iv_belnr = '' OR AccountingDocument = @iv_belnr )
        " See ZCL_EINV_WORKLIST~select_relevant: GJAHR is NUMC(4) and its
        " initial value is '0000'.
        AND ( @iv_gjahr = '0000' OR FiscalYear     = @iv_gjahr )
        AND ( @iv_vbeln = '' OR BillingDocument    = @iv_vbeln )
      INTO @DATA(ls_rel).

    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    " Step 6: the country exclusion hook. In the HANA version this was
    " only called when the EXCLUDE_DOC constant existed, and the method
    " itself was empty - so it always answered "not eligible" and
    " suppressed everything. See ZIF_EINV_COUNTRY~is_document_excluded.
    IF zcl_einv_country_factory=>get_handler( iv_bukrs
         )->is_document_excluded( iv_bukrs = ls_rel-CompanyCode
                                  iv_belnr = ls_rel-AccountingDocument
                                  iv_gjahr = ls_rel-FiscalYear
                                  iv_vbeln = ls_rel-BillingDocument
                                  iv_blart = ls_rel-AccountingDocumentType
                                  iv_fkart = ls_rel-BillingDocumentType ) = abap_true.
      RETURN.
    ENDIF.

    rs_result-relevant = abap_true.

    " Step 5: skip when a row with a status already exists.
    "   SELECT SINGLE * FROM /clr/zt_einv WHERE ...
    "   IF sy-subrc = 0 AND ls_einv-status IS NOT INITIAL. RETURN. ENDIF.
    SELECT SINGLE status FROM zteinv_doc
      WHERE vbeln = @ls_rel-BillingDocument
        AND belnr = @ls_rel-AccountingDocument
        AND bukrs = @ls_rel-CompanyCode
        AND gjahr = @ls_rel-FiscalYear
      INTO @DATA(lv_status).

    IF sy-subrc = 0 AND lv_status IS NOT INITIAL AND lv_status <> 'NOT PROCESSED'.
      rs_result-status  = lv_status.
      rs_result-message = 'e-Invoice already processed for this document'.
      RETURN.
    ENDIF.

    " Create the worklist row through the business object if it is not
    " there yet, so determination and validation run.
    IF sy-subrc <> 0.
      MODIFY ENTITIES OF zcds_int_einv_doc
        ENTITY einvoice
          CREATE FIELDS ( BillingDocument AccountingDocument CompanyCode
                          FiscalYear DocumentTypeCode EInvoiceDate IsB2C )
          WITH VALUE #( ( %cid               = 'AUTO1'
                          BillingDocument    = ls_rel-BillingDocument
                          AccountingDocument = ls_rel-AccountingDocument
                          CompanyCode        = ls_rel-CompanyCode
                          FiscalYear         = ls_rel-FiscalYear
                          DocumentTypeCode   = ls_rel-DocumentTypeCode
                          EInvoiceDate       = ls_rel-DocumentDate
                          IsB2C              = ls_rel-IsB2C ) )
        REPORTED DATA(ls_rep_create)
        FAILED   DATA(ls_fail_create).

      IF ls_fail_create IS NOT INITIAL.
        rs_result-status  = 'ERROR'.
        rs_result-message = 'Could not create the e-invoice worklist entry'.
        RETURN.
      ENDIF.

      COMMIT ENTITIES.
    ENDIF.

    " Step 7: the actual hand-over, which in HANA was
    "   CALL FUNCTION '/CLR/EINV_EWAY_TRIGGER_ELT'.
    " Executes the business object's own action. Calling ZCL_EINV_SUBMIT
    " here and updating the row afterwards would not work: this is an
    " external EML write, so it is subject to the static field control of
    " the behaviour definition, and SyncStatus / ErrorText / CommandId /
    " IsSent are declared `field ( readonly )` there.
    MODIFY ENTITIES OF zcds_int_einv_doc
      ENTITY einvoice
        EXECUTE SubmitEInvoice
        FROM VALUE #( ( BillingDocument    = ls_rel-BillingDocument
                        AccountingDocument = ls_rel-AccountingDocument
                        CompanyCode        = ls_rel-CompanyCode
                        FiscalYear         = ls_rel-FiscalYear ) )
      RESULT   DATA(lt_sub)
      FAILED   DATA(ls_fail_sub)
      REPORTED DATA(ls_rep_sub).

    LOOP AT ls_rep_sub-einvoice INTO DATA(ls_msg_sub).
      IF ls_msg_sub-%msg IS BOUND.
        rs_result-message = ls_msg_sub-%msg->if_message~get_text( ).
      ENDIF.
    ENDLOOP.

    IF ls_fail_sub IS NOT INITIAL.
      ROLLBACK ENTITIES.
      rs_result-submitted = abap_false.
      rs_result-status    = 'ERROR'.
      IF rs_result-message IS INITIAL.
        rs_result-message = 'Submission was rejected by the business object'.
      ENDIF.
      RETURN.
    ENDIF.

    COMMIT ENTITIES RESPONSE OF zcds_int_einv_doc
      FAILED   DATA(ls_cfail_sub)
      REPORTED DATA(ls_crep_sub).

    IF ls_cfail_sub IS NOT INITIAL.
      rs_result-submitted = abap_false.
      rs_result-status    = 'ERROR'.
      rs_result-message   = 'The save of the submission result was rejected'.
      RETURN.
    ENDIF.

    DATA(ls_sub) = VALUE #( lt_sub[ 1 ]-%param OPTIONAL ).
    rs_result-submitted = xsdbool( ls_sub-CommandId IS NOT INITIAL ).
    rs_result-status    = ls_sub-SyncStatus.
    IF ls_sub-ErrorText IS NOT INITIAL.
      rs_result-message = CONV string( ls_sub-ErrorText ).
    ENDIF.

  ENDMETHOD.


ENDCLASS.
