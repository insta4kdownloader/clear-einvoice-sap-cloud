"! <p class="shorttext synchronized">e-Invoice: extract archive store</p>
"!
"! Replaces the download tail of /CLR/ZCL_ELT~create_files_einvoice:
"!
"!   READ TABLE gt_erp_config WITH KEY label_type = 'DATA_ZIP'.
"!   IF sy-subrc IS INITIAL AND lwa_confg-low IS NOT INITIAL.
"!     CALL FUNCTION 'SCMS_XSTRING_TO_BINARY' ...
"!     cl_gui_frontend_services=>gui_download( filename = lwa_confg-low ... ).
"!   ENDIF.
"!
"! That is a diagnostic: when the DATA_ZIP config row holds a path, the
"! extract archive that was about to be uploaded is also written to the
"! developer's own workstation so somebody can open it and see what the
"! platform was actually sent.
"!
"! WHY IT CANNOT BE A FILE ON A WORKSTATION
"!
"! `cl_gui_frontend_services` is SAP GUI, and there is no GUI. More to the
"! point there is no workstation: the extract runs in a batch job on a
"! server in a data centre, and `gui_download` in a background task raises
"! NO_BATCH even on HANA - so on the scheduled path this feature never
"! worked there either. It only ever fired for a developer running the
"! report in dialog.
"!
"! The archive is stored in ZTEINV_ZIP instead and offered as a download
"! from the Fiori app. That keeps the diagnostic, makes it work on the
"! scheduled path where it is most needed, and makes the retrieval
"! auditable.
"!
"! This is the same problem and the same answer as ZCL_EINV_PDF_STORE,
"! which replaced the `file_save_dialog` / `SCMS_DOWNLOAD` tail of
"! call_print_pdf. The two classes are deliberately near-identical: a
"! reader who has understood one has understood the other, and a defect
"! found in either should be looked for in the other.
CLASS zcl_einv_zip_store DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    "! Config label that switches the diagnostic on, verbatim from HANA,
    "! where the value is a full path on the developer's PC:
    "!
    "!   C:\Users\...\Desktop\france\F2_1210021695_upd.zip
    "!
    "! The directory half means nothing in the cloud - there is no
    "! workstation to write to. The FILE NAME half does: an operator who
    "! typed F2_1210021695_upd.zip wanted the download called that, and
    "! throwing it away to treat the row as a yes/no flag would lose
    "! something the config already says. So the last path segment becomes
    "! the stored file name, and a value with no file name in it - 'X', or
    "! a bare directory - is read as the flag it then is.
    "!
    "! The label is kept because the two systems share a config table
    "! layout and an operator who knows to set DATA_ZIP on HANA should not
    "! have to learn a second name.
    CONSTANTS gc_cfg_data_zip TYPE string VALUE 'DATA_ZIP' ##NO_TEXT.

    TYPES: BEGIN OF ty_key,
             vbeln TYPE zde_einv_billdoc,
             belnr TYPE zde_einv_accdoc,
             bukrs TYPE zde_einv_bukrs,
             gjahr TYPE zde_einv_gjahr,
           END OF ty_key.

    "! Is the diagnostic switched on for this system?
    "!
    "! @parameter io_elt | the ELT engine whose GT_ERP_CONFIG is read -
    "!   the same buffer ZCL_EINV_ELT_COMMAND and ZCL_EINV_ELT_INGEST read,
    "!   so all three agree about which rows are current.
    METHODS is_enabled
      IMPORTING io_elt           TYPE REF TO zcl_elt
      RETURNING VALUE(rv_result) TYPE abap_boolean.

    "! The file name to store the archive under.
    "!
    "! The last segment of whatever DATA_ZIP holds, when that segment looks
    "! like a file name; otherwise IV_DEFAULT. Separators are taken as both
    "! \ and / - the HANA value is a Windows path, but nothing stops an
    "! operator typing a POSIX one.
    "!
    "! @parameter iv_default | the name to fall back to, normally the
    "!   timestamp name ZCL_ELT~create_files already generated.
    METHODS file_name
      IMPORTING io_elt         TYPE REF TO zcl_elt
                iv_default     TYPE string
      RETURNING VALUE(rv_name) TYPE string.

    "! Queues an archive for saving.
    "!
    "! ZTEINV_ZIP is not part of the BO composition - a multi-megabyte
    "! binary has no business on a list report - so it cannot be written
    "! with EML. It is buffered here and written by the additional save of
    "! the BO, so nothing issues its own COMMIT WORK.
    METHODS stage
      IMPORTING is_key        TYPE ty_key
                iv_command_id TYPE zde_einv_cmdid
                iv_filename   TYPE string
                iv_content    TYPE xstring.

    "! Called from the additional save of ZBP_CDS_INT_EINV_DOC.
    METHODS save.

    "! Discards anything staged but not saved. The buffer is CLASS-DATA and
    "! an ABAP session serves many requests, so a LUW that staged an
    "! archive and was then rolled back would otherwise keep the bytes
    "! alive and let the next successful save write them under the wrong
    "! document.
    METHODS discard.

    METHODS has_pending
      RETURNING VALUE(rv_result) TYPE abap_boolean.

  PRIVATE SECTION.

    CLASS-DATA gt_buffer TYPE STANDARD TABLE OF zteinv_zip WITH EMPTY KEY.

ENDCLASS.



CLASS zcl_einv_zip_store IMPLEMENTATION.

  METHOD is_enabled.
    IF io_elt IS NOT BOUND.
      RETURN.
    ENDIF.
    rv_result = xsdbool( line_exists( io_elt->gt_erp_config[
                           labeltype = CONV ztelt_config-labeltype( gc_cfg_data_zip ) ] )
                     AND io_elt->gt_erp_config[
                           labeltype = CONV ztelt_config-labeltype( gc_cfg_data_zip ) ]-low
                           IS NOT INITIAL ).
  ENDMETHOD.


  METHOD file_name.
    rv_name = iv_default.

    IF io_elt IS NOT BOUND.
      RETURN.
    ENDIF.

    DATA(lv_cfg) = VALUE string( io_elt->gt_erp_config[
                       labeltype = CONV ztelt_config-labeltype( gc_cfg_data_zip ) ]-low OPTIONAL ).
    IF lv_cfg IS INITIAL.
      RETURN.
    ENDIF.

    " Last segment, taking either separator.
    REPLACE ALL OCCURRENCES OF '\' IN lv_cfg WITH '/'.
    DATA(lt_part) = VALUE string_table( ).
    SPLIT lv_cfg AT '/' INTO TABLE lt_part.

    DATA(lv_last) = COND string( WHEN lt_part IS NOT INITIAL
                                 THEN lt_part[ lines( lt_part ) ]
                                 ELSE lv_cfg ).
    CONDENSE lv_last.

    " A segment with no dot in it is not a file name - it is 'X', or a
    " directory the operator left trailing. Fall back rather than store an
    " extensionless archive the browser will not know what to do with.
    IF lv_last CS '.'.
      rv_name = lv_last.
    ENDIF.
  ENDMETHOD.


  METHOD stage.
    " One archive per document. A resubmission replaces the previous one
    " rather than accumulating: the point of the diagnostic is "what was
    " sent for this document", and keeping every attempt would turn a
    " debugging aid into a storage problem on a table holding zips.
    DELETE gt_buffer WHERE vbeln = is_key-vbeln
                       AND belnr = is_key-belnr
                       AND bukrs = is_key-bukrs
                       AND gjahr = is_key-gjahr.

    APPEND VALUE #( vbeln      = is_key-vbeln
                    belnr      = is_key-belnr
                    bukrs      = is_key-bukrs
                    gjahr      = is_key-gjahr
                    command_id = iv_command_id
                    filename   = iv_filename
                    mimetype   = 'application/zip'
                    content    = iv_content
                    crdat      = zcl_einv_util=>get_system_date( )
                    crtime     = zcl_einv_util=>get_system_time( ) )
           TO gt_buffer ##NO_TEXT.
  ENDMETHOD.


  METHOD discard.
    CLEAR gt_buffer.
  ENDMETHOD.


  METHOD save.
    IF gt_buffer IS INITIAL.
      RETURN.
    ENDIF.

    " No COMMIT WORK: this runs inside the RAP save sequence, so the
    " framework commits. That is the whole point of moving the write out
    " of the action - see section 50.
    MODIFY zteinv_zip FROM TABLE @gt_buffer.

    CLEAR gt_buffer.
  ENDMETHOD.


  METHOD has_pending.
    rv_result = xsdbool( gt_buffer IS NOT INITIAL ).
  ENDMETHOD.

ENDCLASS.
