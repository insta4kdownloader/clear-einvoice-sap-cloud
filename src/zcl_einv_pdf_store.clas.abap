"! <p class="shorttext synchronized">e-Invoice: printout store</p>
"!
"! Replaces the front-end download tail of
"! /CLR/ZCL_EINV_BASE~call_print_pdf:
"!
"!   CALL FUNCTION 'SCMS_XSTRING_TO_BINARY' ...
"!   cl_gui_frontend_services=>file_save_dialog( ... )
"!   CALL FUNCTION 'SCMS_DOWNLOAD' EXPORTING filename = ... frontend = 'X'.
"!
"! None of those exist in Public Cloud, and writing straight to a
"! user's workstation is not something a cloud service can do anyway.
"! The PDF is stored in ZTEINV_PDF instead, which the Fiori app offers
"! as a stream download - so the printout is reproducible and the
"! retrieval is auditable.
CLASS zcl_einv_pdf_store DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES: BEGIN OF ty_key,
             vbeln TYPE zde_einv_billdoc,
             belnr TYPE zde_einv_accdoc,
             bukrs TYPE zde_einv_bukrs,
             gjahr TYPE zde_einv_gjahr,
           END OF ty_key.

    "! Queues a printout for saving.
    "!
    "! ZTEINV_PDF is not part of the BO composition (a large binary has
    "! no business on the list report), so it cannot be written with
    "! EML. It is buffered here and written by the additional save of
    "! the BO, so nothing issues its own COMMIT WORK - which is what
    "! call_seller_action and /CLR/AP_EINVOICE~get_documents did, the
    "! latter once per inserted row.
    METHODS stage
      IMPORTING is_key      TYPE ty_key
                iv_doc_id   TYPE zde_einv_docid
                iv_filename TYPE string
                iv_content  TYPE xstring.

    "! Called from the additional save of ZBP_CDS_INT_EINV_DOC.
    METHODS save.

    "! Discards anything staged but not saved. The buffer is CLASS-DATA and
    "! an ABAP session serves many requests, so a LUW that stages a printout
    "! and is then rolled back would otherwise keep the PDF bytes alive and
    "! let the next successful save write them under the wrong document.
    METHODS discard.

    METHODS has_pending
      RETURNING VALUE(rv_result) TYPE abap_boolean.

  PROTECTED SECTION.
  PRIVATE SECTION.

    CLASS-DATA gt_buffer TYPE STANDARD TABLE OF zteinv_pdf WITH EMPTY KEY.

ENDCLASS.



CLASS zcl_einv_pdf_store IMPLEMENTATION.


  METHOD stage.
    DELETE gt_buffer WHERE vbeln = is_key-vbeln
                       AND belnr = is_key-belnr
                       AND bukrs = is_key-bukrs
                       AND gjahr = is_key-gjahr.

    APPEND VALUE #( vbeln    = is_key-vbeln
                    belnr    = is_key-belnr
                    bukrs    = is_key-bukrs
                    gjahr    = is_key-gjahr
                    invid    = iv_doc_id
                    filename = iv_filename
                    mimetype = 'application/pdf'
                    content  = iv_content
                    crdat    = zcl_einv_util=>get_system_date( )
                    crtime   = zcl_einv_util=>get_system_time( ) )
           TO gt_buffer.
  ENDMETHOD.


  METHOD discard.
    CLEAR gt_buffer.
  ENDMETHOD.


  METHOD save.
    IF gt_buffer IS INITIAL.
      RETURN.
    ENDIF.

    " No COMMIT WORK: this runs inside the RAP save sequence, so the
    " framework commits. That is the whole point of moving the write
    " out of the action.
    MODIFY zteinv_pdf FROM TABLE @gt_buffer.

    CLEAR gt_buffer.
  ENDMETHOD.


  METHOD has_pending.
    rv_result = xsdbool( gt_buffer IS NOT INITIAL ).
  ENDMETHOD.


ENDCLASS.
