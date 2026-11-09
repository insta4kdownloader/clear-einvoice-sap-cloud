"! <p class="shorttext synchronized">e-Invoice: country handler factory</p>
"!
"! Replaces /CLR/ZCL_EINV_FACTORY.
"!
"! What the HANA factory did, and why each part had to change:
"!
"!  1. Read the company code from ABAP memory
"!       IMPORT lv_comp FROM MEMORY ID '/CLR/EINV_COCKPIT'
"!     set by /CLR/ELT_EINVOICE_DASHBOARD before CALL TRANSACTION.
"!     -> Cross-transaction memory does not exist in Public Cloud. The
"!        company code is now an explicit parameter.
"!
"!  2. Derive the class name from the country code
"!       CREATE OBJECT ro_instance TYPE ('/CLR/ZCL_EINV_' && land1)
"!     -> Now a configured class name (ZTEINV_CNTRY-HANDLER_CLASS),
"!        validated against ZIF_EINV_COUNTRY before use.
"!
"!  3. Push all customizing into PUBLIC attributes of the instance
"!       ro_instance->gt_config = ...  gt_invmap = ...  gv_auth = ...
"!     -> Configuration is owned by ZCL_EINV_CONFIG and read through
"!        methods, so nothing mutates another object's state and the
"!        auth token never sits in a public attribute.
CLASS zcl_einv_country_factory DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.

    "! Returns the handler configured for the company code, or the
    "! default handler when none is configured or the configured class
    "! cannot be instantiated.
    CLASS-METHODS get_handler
      IMPORTING iv_bukrs         TYPE zde_einv_bukrs
      RETURNING VALUE(ro_result) TYPE REF TO zif_einv_country.

  PROTECTED SECTION.
  PRIVATE SECTION.

    TYPES: BEGIN OF ty_cache,
             bukrs   TYPE zde_einv_bukrs,
             handler TYPE REF TO zif_einv_country,
           END OF ty_cache.

    CLASS-DATA gt_cache TYPE SORTED TABLE OF ty_cache WITH UNIQUE KEY bukrs.

ENDCLASS.



CLASS zcl_einv_country_factory IMPLEMENTATION.


  METHOD get_handler.

    " One handler per company code per session - the HANA factory built
    " a fresh instance on every AT SELECTION-SCREEN OUTPUT.
    DATA(ls_cached) = VALUE #( gt_cache[ bukrs = iv_bukrs ] OPTIONAL ).
    IF ls_cached-handler IS BOUND.
      ro_result = ls_cached-handler.
      RETURN.
    ENDIF.

    DATA(lv_class) = zcl_einv_config=>get_instance( )->get_handler_class( iv_bukrs ).

    IF lv_class IS NOT INITIAL.
      TRY.
          DATA lo_obj TYPE REF TO object.
          CREATE OBJECT lo_obj TYPE (lv_class).
          " The cast is what makes the configured name safe: a class that
          " does not implement the contract is rejected here rather than
          " failing later with a method-not-found dump, which is what the
          " HANA string-concatenated class name risked.
          ro_result ?= lo_obj.
        CATCH cx_sy_create_object_error cx_sy_move_cast_error.
          CLEAR ro_result.
      ENDTRY.
    ENDIF.

    IF ro_result IS NOT BOUND.
      ro_result = NEW zcl_einv_country_default( ).
    ENDIF.

    INSERT VALUE #( bukrs = iv_bukrs handler = ro_result ) INTO TABLE gt_cache.

  ENDMETHOD.


ENDCLASS.
