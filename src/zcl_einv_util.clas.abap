"! <p class="shorttext synchronized">e-Invoice: cloud-safe system information</p>
"!
"! Replaces the system-field reads that /CLR/EINVOICE_ELT used
"! throughout and that are meaningless or unavailable in ABAP Cloud:
"!
"!   sy-datum / sy-uzeit  -> cl_abap_context_info=>get_system_date/time
"!   sy-uname             -> cl_abap_context_info=>get_user_technical_name
"!   sy-sysid             -> ZTEINV_CNTRY-SYSID configuration (see note)
"!   sy-mandt             -> implicit, never written into a table
"!   GUID_CREATE          -> cl_system_uuid
"!
"! On SYSID: in the HANA package sy-sysid was a KEY FIELD of nine
"! configuration tables and was compared against sy-sysid at runtime.
"! A Public Cloud tenant has no meaningful transport-landscape system
"! id to branch on, so SYSID here is a plain configured value that
"! identifies the Clear-side ERP instance, resolved from configuration
"! and never from a system field.
CLASS zcl_einv_util DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.

    CLASS-METHODS get_system_date
      RETURNING VALUE(rv_date) TYPE d.

    CLASS-METHODS get_system_time
      RETURNING VALUE(rv_time) TYPE t.

    CLASS-METHODS get_user_name
      RETURNING VALUE(rv_user) TYPE zde_einv_user.

    CLASS-METHODS get_uuid
      RETURNING VALUE(rv_uuid) TYPE string.

    "! Formats a date as the ClearTax API expects it in a seller-action
    "! payload. call_seller_action built 'DD/MM/YYYY' by hand with
    "! offsets; the format lives in one place now.
    CLASS-METHODS format_date_ddmmyyyy
      IMPORTING iv_date        TYPE d
      RETURNING VALUE(rv_text) TYPE string.

    "! ISO 8601 date, used by the AP get-document-list query string.
    CLASS-METHODS format_date_iso
      IMPORTING iv_date        TYPE d
      RETURNING VALUE(rv_text) TYPE string.

ENDCLASS.



CLASS zcl_einv_util IMPLEMENTATION.


  METHOD get_system_date.
    TRY.
        rv_date = cl_abap_context_info=>get_system_date( ).
      CATCH cx_abap_context_info_error.
        CLEAR rv_date.
    ENDTRY.
  ENDMETHOD.


  METHOD get_system_time.
    TRY.
        rv_time = cl_abap_context_info=>get_system_time( ).
      CATCH cx_abap_context_info_error.
        CLEAR rv_time.
    ENDTRY.
  ENDMETHOD.


  METHOD get_user_name.
    TRY.
        rv_user = cl_abap_context_info=>get_user_technical_name( ).
      CATCH cx_abap_context_info_error.
        CLEAR rv_user.
    ENDTRY.
  ENDMETHOD.


  METHOD get_uuid.
    TRY.
        rv_uuid = cl_system_uuid=>create_uuid_c36_static( ).
      CATCH cx_uuid_error.
        CLEAR rv_uuid.
    ENDTRY.
  ENDMETHOD.


  METHOD format_date_ddmmyyyy.
    IF iv_date IS INITIAL.
      RETURN.
    ENDIF.
    rv_text = |{ iv_date+6(2) }/{ iv_date+4(2) }/{ iv_date(4) }|.
  ENDMETHOD.


  METHOD format_date_iso.
    IF iv_date IS INITIAL.
      RETURN.
    ENDIF.
    rv_text = |{ iv_date(4) }-{ iv_date+4(2) }-{ iv_date+6(2) }|.
  ENDMETHOD.


ENDCLASS.
