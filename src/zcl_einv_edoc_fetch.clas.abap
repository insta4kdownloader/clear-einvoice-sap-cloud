"! <p class="shorttext synchronized">e-Document: inbound document fetch</p>
"!
"! Replaces `/CLR/AP_EINVOICE` and the four `/CLR/EINV_AP_GET_DOCUMENT*`
"! programs.
"!
"! >>> READ THIS BEFORE RELYING ON THE DETAIL FETCH. <<<
"!
"! The inbound retrieval layer is the least complete part of the HANA
"! package, and the 2026-09-25 drop made it less complete, not more:
"!
"!  * The four `/CLR/EINV_AP_GET_DOCUMENT*` programs were DELETED. The
"!    transaction `/CLR/EINV_AP_GETDOC` still points at the now-missing
"!    program, so it is a dangling tcode in that export.
"!  * Nothing calls `/CLR/AP_EINVOICE` any more - the cockpit's own
"!    `&GET_DOC` handler is commented out. The class is dead code.
"!  * `/CLR/AP_EINVOICE~get_document_info`, which is the ONLY specification
"!    that has ever existed for mapping the UBL response onto the 262
"!    header and 94 item columns, is 100% commented out (lines 344-818) and
"!    has never been active in any export.
"!  * Consequently the ~138 columns added to `/CLR/EINV_APHEAD` and
"!    `/CLR/EINV_APITEM` in this drop have NO PRODUCER anywhere.
"!  * `/CLR/EINV_ARHEAD` and `/CLR/EINV_ARITEM` are worse: no INSERT or
"!    MODIFY against them exists anywhere in the package. The self-billing
"!    cockpit only ever SELECTs and UPDATEs rows it assumes are already
"!    there.
"!
"! What this class therefore does:
"!
"!   get_document_list   IMPLEMENTED. Ports the live part of
"!                       `get_documents`: call GET_DOC_LIST, write the run
"!                       log, and upsert the document stub (DOCUMENTID,
"!                       DOCUMENTNUMBER, UUID, STATUS) - exactly the four
"!                       columns the HANA method actually wrote.
"!
"!   fetch_document_detail  A STUB. It calls nothing and writes nothing;
"!                       it returns a "not implemented" message and exists
"!                       so the call site and the endpoint configuration
"!                       are already in place.
"!
"!                       The UBL mapping is no longer a specification
"!                       problem: the 2026-10-01 drop ships the eight-table
"!                       model with a UBL 2.1 XPath for every one of its 227
"!                       columns, and each is carried into the CDS views as a
"!                       comment above the element. What is still missing is a
"!                       live payload to write and test the transformation
"!                       against; see CONVERSION_DESIGN.md section 13.
"!
"!                       When it is implemented, the raw JSON belongs in
"!                       ZTEDOC_APH/SBH-JSON_PAYLOAD (the column exists and is
"!                       empty today) so that a corrected mapping can be
"!                       back-applied without re-fetching.
CLASS zcl_einv_edoc_fetch DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES: BEGIN OF ty_run_result,
             run_uuid  TYPE zde_einv_uuid,
             fetched   TYPE i,
             created   TYPE i,
             success   TYPE abap_boolean,
             message   TYPE zde_elt_api_message,
           END OF ty_run_result.

    METHODS constructor
      IMPORTING iv_einv_type TYPE zde_einv_type.

    "! Fetches the document list for a date range and upserts the stubs.
    METHODS fetch_document_list
      IMPORTING iv_bukrs         TYPE zde_einv_bukrs
                iv_date_from     TYPE d
                iv_date_to       TYPE d
                iv_adhoc         TYPE zde_einv_flag DEFAULT 'X'
      RETURNING VALUE(rs_result) TYPE ty_run_result.

    "! STUB - returns a "not implemented" message and writes nothing.
    "! See the class documentation for why the UBL field mapping is
    "! deliberately not attempted and what implementing it needs.
    METHODS fetch_document_detail
      IMPORTING iv_bukrs         TYPE zde_einv_bukrs
                iv_documentno    TYPE zde_elt_docno
      RETURNING VALUE(rv_message) TYPE zde_elt_api_message.

  PROTECTED SECTION.
  PRIVATE SECTION.

    "! FOR ALL ENTRIES compares column to column: the driver table's line
    "! type has to match DOCUMENTNUMBER exactly, which a STRING_TABLE does not.
    TYPES ty_docno_tab TYPE STANDARD TABLE OF zde_elt_docno WITH EMPTY KEY.

    DATA mv_einv_type TYPE zde_einv_type.

    "! AP inbound lands in ZTEDOC_APH, self-billed in ZTEDOC_SBH. The two
    "! tables are structurally identical, so one routine serves both and the
    "! target is chosen here.
    METHODS is_self_billed
      RETURNING VALUE(rv_result) TYPE abap_boolean.

    "! Document numbers of this batch that already have a header row.
    "!
    "! The key of the new model is UUID, not DOCUMENTNUMBER, so
    "! INSERT ... ACCEPTING DUPLICATE KEYS no longer protects against
    "! re-fetching a document: a second run would mint a second UUID and
    "! insert a duplicate under a different key. The duplicate check has to be
    "! made on the business identifier instead.
    METHODS existing_documents
      IMPORTING it_docs          TYPE zstr_einv_apdoc_tt
      RETURNING VALUE(rt_result) TYPE ty_docno_tab.

ENDCLASS.



CLASS zcl_einv_edoc_fetch IMPLEMENTATION.


  METHOD constructor.
    mv_einv_type = iv_einv_type.
  ENDMETHOD.


  METHOD is_self_billed.
    rv_result = xsdbool( mv_einv_type = zcl_einv_edoc_action=>gc_type-self_billed ).
  ENDMETHOD.


  METHOD fetch_document_list.

    rs_result-run_uuid = zcl_einv_util=>get_uuid( ).

    DATA(lo_api) = NEW zcl_einv_api_client( ).

    DATA(ls_call) = lo_api->get_document_list( iv_bukrs     = iv_bukrs
                                               iv_einv_type = mv_einv_type
                                               iv_date_from = iv_date_from
                                               iv_date_to   = iv_date_to ).
    DATA(lt_docs) = ls_call-docs.

    rs_result-success = ls_call-success.
    rs_result-message = ls_call-message.
    rs_result-fetched = lines( lt_docs ).

    IF ls_call-success = abap_false.
      " The run is logged even when the call failed - that is the point of
      " a run log, and /CLR/EINV_AP_RUN never recorded the outcome at all.
      INSERT zteinv_run FROM @( VALUE #(
        run_uuid        = rs_result-run_uuid
        einv_type       = mv_einv_type
        run_date        = zcl_einv_util=>get_system_date( )
        run_time        = zcl_einv_util=>get_system_time( )
        run_by          = zcl_einv_util=>get_user_name( )
        start_date      = iv_date_from
        end_date        = iv_date_to
        adhoc_indicator = iv_adhoc
        doc_count       = 0
        message         = rs_result-message ) ).
      RETURN.
    ENDIF.

    " get_documents did one INSERT per document, each wrapped in its own
    " ENQUEUE_E_TABLE / DEQUEUE_E_TABLE bracket and followed by its own
    " COMMIT WORK. None of that is permitted here, and none of it is needed:
    " one set-based insert, committed once by the caller.
    "
    " The list endpoint returns a document id, a document number and a status.
    " It does NOT return the SBDH InstanceIdentifier that the new model keys
    " on - that lives in the payload, which only the detail fetch retrieves.
    " So the stub row gets a locally generated UUID and stays matched to the
    " platform by DOCUMENTNUMBER until the detail fetch can replace it with
    " the real one.
    DATA lt_head TYPE STANDARD TABLE OF ztedoc_aph WITH EMPTY KEY.
    DATA lt_self TYPE STANDARD TABLE OF ztedoc_sbh WITH EMPTY KEY.

    DATA(lt_known) = existing_documents( lt_docs ).

    LOOP AT lt_docs INTO DATA(ls_doc).
      IF ls_doc-document_number IS INITIAL.
        CONTINUE.
      ENDIF.

      " A document already on the database keeps the action type, reason code
      " and status a user has since set on it. The HANA INSERT simply dumped
      " on the duplicate.
      IF line_exists( lt_known[ table_line = ls_doc-document_number ] ).
        CONTINUE.
      ENDIF.

      DATA(ls_row) = VALUE ztedoc_aph(
        uuid           = zcl_einv_util=>get_uuid( )
        documentid     = ls_doc-document_id
        documentnumber = ls_doc-document_number
        status         = ls_doc-status
        created_on     = zcl_einv_util=>get_system_date( )
        created_at     = zcl_einv_util=>get_system_time( )
        created_by     = zcl_einv_util=>get_user_name( ) ).

      IF is_self_billed( ) = abap_true.
        APPEND CORRESPONDING #( ls_row ) TO lt_self.
      ELSE.
        APPEND ls_row TO lt_head.
      ENDIF.
    ENDLOOP.

    IF lt_head IS NOT INITIAL.
      INSERT ztedoc_aph FROM TABLE @lt_head.
      rs_result-created = sy-dbcnt.
    ENDIF.
    IF lt_self IS NOT INITIAL.
      INSERT ztedoc_sbh FROM TABLE @lt_self.
      rs_result-created = sy-dbcnt.
    ENDIF.

    INSERT zteinv_run FROM @( VALUE #(
      run_uuid        = rs_result-run_uuid
      einv_type       = mv_einv_type
      run_date        = zcl_einv_util=>get_system_date( )
      run_time        = zcl_einv_util=>get_system_time( )
      run_by          = zcl_einv_util=>get_user_name( )
      start_date      = iv_date_from
      end_date        = iv_date_to
      adhoc_indicator = iv_adhoc
      doc_count       = rs_result-fetched
      message         = |{ rs_result-created } new of { rs_result-fetched } fetched| ) ).

  ENDMETHOD.


  METHOD fetch_document_detail.

    " GET_DOC_DETAILS. The commented-out get_document_info built
    "   <url>?document-number=<no>&einvoice-type=<type>
    DATA(lo_config) = zcl_einv_config=>get_instance( ).

    lo_config->get_endpoint( EXPORTING iv_bukrs    = iv_bukrs
                                       iv_function = zcl_einv_config=>gc_function-get_doc_deta
                             IMPORTING ev_url      = DATA(lv_path) ).

    IF lv_path IS INITIAL.
      rv_message = 'GET_DOC_DETAILS is not maintained in ZTEINV_API'.
      RETURN.
    ENDIF.

    " Deliberately not mapped - see the class documentation. The target model
    " and the UBL XPath of every column now exist; what is missing is a live
    " payload to write and test the transformation against.
    rv_message = |Detail fetch for { iv_documentno } is not implemented. The |
              && |target model and its UBL XPaths are documented in |
              && |CONVERSION_DESIGN.md section 13.|.

  ENDMETHOD.


  METHOD existing_documents.

    IF it_docs IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lt_no) = VALUE ty_docno_tab( FOR ls IN it_docs
                                      WHERE ( document_number IS NOT INITIAL )
                                      ( CONV #( ls-document_number ) ) ).
    IF lt_no IS INITIAL.
      RETURN.
    ENDIF.

    IF is_self_billed( ) = abap_true.
      SELECT documentnumber FROM ztedoc_sbh
        FOR ALL ENTRIES IN @lt_no
        WHERE documentnumber = @lt_no-table_line
        INTO TABLE @rt_result.
    ELSE.
      SELECT documentnumber FROM ztedoc_aph
        FOR ALL ENTRIES IN @lt_no
        WHERE documentnumber = @lt_no-table_line
        INTO TABLE @rt_result.
    ENDIF.

  ENDMETHOD.


ENDCLASS.
