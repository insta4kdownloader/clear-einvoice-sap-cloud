"! <p class="shorttext synchronized">e-Invoice: default country handler</p>
"!
"! The behaviour every country gets unless ZTEINV_CNTRY-HANDLER_CLASS
"! names something else. It is the first place where the hooks that
"! /CLR/ZCL_EINV_AE, _FR and _OM left empty actually do something.
CLASS zcl_einv_country_default DEFINITION
  PUBLIC
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_einv_country.

    CONSTANTS:
      "! Label under which the exclusion list is maintained in
      "! ZTEINV_CONST - the same 'EXCLUDE_DOC' label the HANA package
      "! read from /CLR/EINV_CONST.
      gc_label_exclude      TYPE zde_einv_label VALUE 'EXCLUDE_DOC',
      "! Label for the cancellation window in hours. Defaults to 72,
      "! the value implied by message /CLR/ZME_EINV 089.
      gc_label_cancel_hours TYPE zde_einv_label VALUE 'CANCEL_WINDOW_H'.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_einv_country_default IMPLEMENTATION.


  METHOD zif_einv_country~is_document_excluded.
    " The HANA base class had an empty body here and always answered
    " "not eligible", which meant that as soon as anyone maintained the
    " EXCLUDE_DOC constant, consolidate_data skipped every document.
    "
    " The rule implemented here is the one the configuration was
    " obviously meant to express: a document is excluded when its
    " accounting or billing document type appears in an EXCLUDE_DOC row
    " for the company code (LOW = type). Nothing maintained means
    " nothing excluded.
    rv_excluded = abap_false.

    DATA(lt_const) = zcl_einv_config=>get_instance( )->get_constants(
                       iv_bukrs  = iv_bukrs
                       iv_label  = gc_label_exclude ).

    LOOP AT lt_const INTO DATA(ls_const).
      IF ( iv_blart IS NOT INITIAL AND ls_const-low = iv_blart )
      OR ( iv_fkart IS NOT INITIAL AND ls_const-low = iv_fkart ).
        rv_excluded = abap_true.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_einv_country~check_cancel_allowed.
    " /CLR/ZME_EINV 089: "cannot be cancelled after 72 hours".
    CLEAR rv_reason.

    IF iv_status = 'CANCELLED'.
      rv_reason = 'e-Invoice is already cancelled'.
      RETURN.
    ENDIF.

    IF iv_created_on IS INITIAL.
      RETURN.
    ENDIF.

    " 89 of /CLR/ZME_EINV: "cannot be cancelled after 72 hours". The window
    " is configurable per country through ZTEINV_CONST, which is why the
    " company code has to reach this method - get_constants derives the
    " country from it.
    DATA(lv_hours) = 72.
    DATA(lt_const) = zcl_einv_config=>get_instance( )->get_constants(
                       iv_bukrs = iv_bukrs
                       iv_label = gc_label_cancel_hours ).
    IF lt_const IS NOT INITIAL.
      DATA(lv_conf) = condense( CONV string( lt_const[ 1 ]-low ) ).
      " A blank value must not pass: CONV i( '   ' ) is 0, and a zero-hour
      " window would block every cancellation.
      IF lv_conf IS NOT INITIAL AND lv_conf CO '0123456789' AND lv_conf <> '0'.
        lv_hours = CONV i( lv_conf ).
      ENDIF.
    ENDIF.

    DATA lv_created TYPE timestamp.
    DATA lv_now     TYPE timestamp.

    CONVERT DATE iv_created_on TIME iv_created_at
            INTO TIME STAMP lv_created TIME ZONE 'UTC'.
    CONVERT DATE zcl_einv_util=>get_system_date( )
            TIME zcl_einv_util=>get_system_time( )
            INTO TIME STAMP lv_now TIME ZONE 'UTC'.

    DATA(lv_elapsed) = cl_abap_tstmp=>subtract( tstmp1 = lv_now
                                                tstmp2 = lv_created ).

    IF lv_elapsed > ( lv_hours * 3600 ).
      rv_reason = |e-Invoice cannot be cancelled more than { lv_hours } hours after creation|.
    ENDIF.
  ENDMETHOD.


  METHOD zif_einv_country~map_criticality.
    " Replaces /CLR/EINV_STATUS-COLOR_CODE plus the icon SWITCH of
    " call_seller_action:
    "   VALID              -> @5B@ (green)
    "   INVALID / ERROR    -> @5C@ (red)
    "   COMPLETED/COLLECTED-> @01@
    "   else               -> @BZ@ (not yet processed)
    "
    " Configuration wins when a ZTEINV_STATUS row exists, so the mapping
    " stays customizable exactly as it was.
    rv_criticality = zcl_einv_config=>get_instance( )->get_criticality(
                       iv_bukrs  = iv_bukrs
                       iv_status = iv_status ).

    IF rv_criticality IS NOT INITIAL.
      RETURN.
    ENDIF.

    rv_criticality = SWITCH #( to_upper( iv_status )
      WHEN 'VALID'          THEN 3
      WHEN 'COMPLETED'      THEN 3
      WHEN 'COLLECTED'      THEN 3
      WHEN 'ERROR'          THEN 1
      WHEN 'INVALID'        THEN 1
      WHEN 'CANCELLED'      THEN 1
      WHEN 'SUBMITTED'      THEN 2
      WHEN 'PENDING'        THEN 2
      WHEN 'NOT PROCESSED'  THEN 0
      ELSE 0 ).
  ENDMETHOD.


  METHOD zif_einv_country~enrich_headers.
    " Nothing computed by default. A country handler that has to sign a
    " request or add a nonce overrides this and appends to CT_HEADER.
    RETURN.
  ENDMETHOD.


ENDCLASS.
