"! <p class="shorttext synchronized">e-Invoice: worklist selection</p>
"!
"! Replaces the data-collection half of /CLR/ZCL_EINV_BASE:
"!   get_data, get_billing_docs, get_accounting_docs,
"!   select_partner_data, select_einvoice_data, consolidate_data,
"!   add_final_entry, fill_partner_data, fill_einv_status,
"!   fill_async_status, fill_sales_status.
"!
"! Those eleven methods existed because the worklist had to be
"! assembled in ABAP from six direct table reads (VBRK, BKPF, BSEG,
"! KNA1, LFA1 plus three status tables) and three overlay passes, then
"! held in the public attribute GT_FINAL for the ALV.
"!
"! In the cloud model the joins and the status precedence live in CDS
"! (ZCDS_INT_EINV_RELEVANT and the COALESCE in ZCDS_INT_EINV_DOC), so
"! all that remains here is: read the candidate list, apply the
"! country exclusion hook, and drop what already has a row.
CLASS zcl_einv_worklist DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    "! Reads e-invoice-relevant documents for the given selection.
    "!
    "! The parameters are the selection-screen fields of
    "! /CLR/ELT_EINVOICE_SEL that get_data actually evaluated. Range
    "! tables became from/to pairs because a RAP action parameter is a
    "! flat structure; widen to real ranges if interval selection is
    "! needed on the Fiori side.
    METHODS select_relevant
      IMPORTING iv_projectid          TYPE zde_einv_projectid OPTIONAL
                iv_bukrs              TYPE zde_einv_bukrs
                iv_posting_date_from  TYPE d OPTIONAL
                iv_posting_date_to    TYPE d OPTIONAL
                iv_creation_date_from TYPE d OPTIONAL
                iv_creation_date_to   TYPE d OPTIONAL
                iv_vbeln              TYPE zde_einv_billdoc OPTIONAL
                iv_belnr              TYPE zde_einv_accdoc OPTIONAL
                iv_gjahr              TYPE zde_einv_gjahr OPTIONAL
      RETURNING VALUE(rt_result)      TYPE zstr_einv_relevant_tt.

    " The four key fields of a worklist candidate. A plain comment, not
    " ABAP Doc: `"!` attaches only to the declaration it precedes, and a
    " chained TYPES: is not one of them.
    TYPES:
      BEGIN OF ty_cand,
        BillingDocument    TYPE zde_einv_billdoc,
        AccountingDocument TYPE zde_einv_accdoc,
        CompanyCode        TYPE zde_einv_bukrs,
        FiscalYear         TYPE zde_einv_gjahr,
      END OF ty_cand,
      ty_cand_tab TYPE STANDARD TABLE OF ty_cand WITH EMPTY KEY.

    "! The subset of the given candidate keys that should actually be
    "! created: no ZTEINV_DOC row yet, and not a repeat of an earlier key
    "! in the same batch.
    "!
    "! /CLR/ZCL_ELT_EINVOICE~einv_ewb_create did this check inline:
    "!   SELECT SINGLE * FROM /clr/zt_einv WHERE ...
    "!   IF sy-subrc = 0 AND ls_einv-status IS NOT INITIAL. skip.
    "! Same rule, applied to the whole batch in one read.
    "!
    "! Takes and returns plain keys rather than a TABLE FOR CREATE: a RAP
    "! derived type in the signature of a class outside the behaviour pool
    "! makes the class compile only once the behaviour definition is active,
    "! which turns a first-time import into a chicken-and-egg activation.
    METHODS keep_new
      IMPORTING it_candidates  TYPE ty_cand_tab
      RETURNING VALUE(rt_keep) TYPE ty_cand_tab.

    "! Documents that are waiting to be submitted - the selection the
    "! batch variant of the HANA cockpit made with sy-batch and
    "! submit_data_batch. Used by ZCL_EINV_SUBMIT_JOB.
    METHODS select_pending
      IMPORTING iv_bukrs         TYPE zde_einv_bukrs OPTIONAL
                iv_max_rows      TYPE i DEFAULT 500
      RETURNING VALUE(rt_result) TYPE zteinv_doc_tt.

    "! Documents with a platform document id whose status should be
    "! re-read. Used by ZCL_EINV_STATUS_JOB - the HANA package had no
    "! equivalent at all, status was only ever refreshed by a user
    "! pressing the &STATUS button.
    METHODS select_for_status_refresh
      IMPORTING iv_bukrs         TYPE zde_einv_bukrs OPTIONAL
                iv_max_rows      TYPE i DEFAULT 500
      RETURNING VALUE(rt_result) TYPE zteinv_doc_tt.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_einv_worklist IMPLEMENTATION.


  METHOD select_relevant.

    " get_data returned immediately when both date ranges were empty;
    " the caller (the RAP action) enforces that as a message, so here it
    " is only a safety net against an unbounded read.
    IF     iv_posting_date_from  IS INITIAL
       AND iv_creation_date_from IS INITIAL
       AND iv_vbeln              IS INITIAL
       AND iv_belnr              IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lv_post_to) = COND #( WHEN iv_posting_date_to IS INITIAL
                               THEN iv_posting_date_from
                               ELSE iv_posting_date_to ).
    DATA(lv_crea_to) = COND #( WHEN iv_creation_date_to IS INITIAL
                               THEN iv_creation_date_from
                               ELSE iv_creation_date_to ).

    " DISTINCT is not cosmetic. /CLR/EINV_INVMAP is keyed on
    "   (PROJECTID, SYSID, LAND1, BUKRS, FKART, BLART, DOC_TYPE, SUP_TYPE)
    " and ZCDS_INT_EINV_REL_JRNL joins it on BUKRS + BLART alone, exactly as
    " the HANA SELECT did. One journal entry therefore matches every INVMAP
    " row configured for that company code and document type. The HANA
    " statement had SELECT DISTINCT over the BKPF columns for the same
    " reason; without it the fan-out reaches the worklist and the CREATE
    " below hits a duplicate key on ZTEINV_DOC.
    SELECT FROM ZCDS_INT_EINV_RELEVANT
      FIELDS DISTINCT
             BillingDocument, AccountingDocument, CompanyCode, FiscalYear,
             BillingDocumentType, AccountingDocumentType, Country,
             DocumentTypeCode, IsB2C, DocumentDate, PostingDate
      WHERE CompanyCode = @iv_bukrs
        AND ( @iv_projectid = '' OR ProjectId          = @iv_projectid )
        AND ( @iv_vbeln     = '' OR BillingDocument    = @iv_vbeln )
        AND ( @iv_belnr     = '' OR AccountingDocument = @iv_belnr )
        " '0000', not '': ZDE_EINV_GJAHR is NUMC(4), so an unsupplied
        " fiscal year arrives as '0000'. Comparing it to '' is always
        " false, which would turn the optional filter into
        " FiscalYear = '0000' and select nothing at all.
        AND ( @iv_gjahr     = '0000' OR FiscalYear     = @iv_gjahr )
        AND ( @iv_posting_date_from  = '00000000'
              OR PostingDate  BETWEEN @iv_posting_date_from  AND @lv_post_to )
        AND ( @iv_creation_date_from = '00000000'
              OR CreationDate BETWEEN @iv_creation_date_from AND @lv_crea_to )
      ORDER BY CompanyCode, FiscalYear, AccountingDocument
      INTO TABLE @DATA(lt_raw)
      UP TO 5000 ROWS.

    DATA(lo_country) = zcl_einv_country_factory=>get_handler( iv_bukrs ).

    LOOP AT lt_raw INTO DATA(ls_raw).

      " Replaces the exclude_doc call of consolidate_data. The HANA
      " version only invoked it when the EXCLUDE_DOC constant was
      " maintained, and the method itself was empty - so the effective
      " behaviour was "exclude everything as soon as the constant
      " exists". Here the handler decides and the safe default is
      " "do not exclude".
      IF lo_country->is_document_excluded( iv_bukrs = ls_raw-CompanyCode
                                           iv_belnr = ls_raw-AccountingDocument
                                           iv_gjahr = ls_raw-FiscalYear
                                           iv_vbeln = ls_raw-BillingDocument
                                           iv_blart = ls_raw-AccountingDocumentType
                                           iv_fkart = ls_raw-BillingDocumentType ) = abap_true.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( vbeln    = ls_raw-BillingDocument
                      belnr    = ls_raw-AccountingDocument
                      bukrs    = ls_raw-CompanyCode
                      gjahr    = ls_raw-FiscalYear
                      fkart    = ls_raw-BillingDocumentType
                      blart    = ls_raw-AccountingDocumentType
                      land1    = ls_raw-Country
                      doc_type = ls_raw-DocumentTypeCode
                      b2c      = ls_raw-IsB2C
                      bldat    = ls_raw-DocumentDate
                      budat    = ls_raw-PostingDate )
             TO rt_result.
    ENDLOOP.

    " DISTINCT above removes rows identical in all selected columns; two
    " INVMAP rows differing only in DOC_TYPE still produce two rows for one
    " document. ZTEINV_DOC is keyed on (VBELN, BELNR, BUKRS, GJAHR), so the
    " first configured mapping wins - which is what consolidate_data's
    " READ TABLE gt_invmap ... WITH KEY did.
    SORT rt_result BY bukrs gjahr belnr vbeln doc_type.
    DELETE ADJACENT DUPLICATES FROM rt_result COMPARING bukrs gjahr belnr vbeln.

  ENDMETHOD.


  METHOD keep_new.

    IF it_candidates IS INITIAL.
      RETURN.
    ENDIF.

    SELECT vbeln, belnr, bukrs, gjahr
      FROM zteinv_doc
      FOR ALL ENTRIES IN @it_candidates
      WHERE belnr = @it_candidates-AccountingDocument
        AND bukrs = @it_candidates-CompanyCode
        AND gjahr = @it_candidates-FiscalYear
      INTO TABLE @DATA(lt_existing).

    " Second guard, against duplicates inside one batch rather than against
    " rows already on the database. select_relevant removes them at source;
    " this keeps the guarantee even if a caller assembles the candidate
    " list itself.
    DATA lv_seen TYPE string.
    DATA lt_keys TYPE SORTED TABLE OF string WITH UNIQUE DEFAULT KEY.

    LOOP AT it_candidates INTO DATA(ls_cand).
      IF line_exists( lt_existing[ vbeln = ls_cand-BillingDocument
                                   belnr = ls_cand-AccountingDocument
                                   bukrs = ls_cand-CompanyCode
                                   gjahr = ls_cand-FiscalYear ] ).
        CONTINUE.
      ENDIF.

      lv_seen = |{ ls_cand-BillingDocument }/{ ls_cand-AccountingDocument }|
             && |/{ ls_cand-CompanyCode }/{ ls_cand-FiscalYear }|.
      INSERT lv_seen INTO TABLE lt_keys.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      APPEND ls_cand TO rt_keep.
    ENDLOOP.

  ENDMETHOD.


  METHOD select_pending.

    " Eligibility rule of submit_data / submit_data_batch: no platform
    " document id yet, or an error to retry.
    SELECT FROM zteinv_doc
      FIELDS *
      WHERE ( @iv_bukrs = '' OR bukrs = @iv_bukrs )
        AND ( invid = '' OR error <> '' )
      ORDER BY bukrs, gjahr, belnr
      INTO TABLE @rt_result
      UP TO @iv_max_rows ROWS.

  ENDMETHOD.


  METHOD select_for_status_refresh.

    SELECT FROM zteinv_doc
      FIELDS *
      WHERE ( @iv_bukrs = '' OR bukrs = @iv_bukrs )
        AND invid  <> ''
        AND status NOT IN ( 'VALID', 'CANCELLED', 'COMPLETED', 'COLLECTED' )
      ORDER BY bukrs, gjahr, belnr
      INTO TABLE @rt_result
      UP TO @iv_max_rows ROWS.

  ENDMETHOD.


ENDCLASS.
