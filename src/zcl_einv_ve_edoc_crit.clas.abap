"! <p class="shorttext synchronized">e-Document: status criticality (virtual element)</p>
"!
"! Fills StatusCriticality on ZCDS_CUN_EINV_APH and ZCDS_CUN_EINV_SBH.
"!
"! The two HANA cockpits had no status colouring at all on the inbound and
"! self-billed grids - `set_status_colors` exists only on the sales side.
"! Adding it here costs nothing (the status mapping table is already there)
"! and makes a long list actually scannable.
CLASS zcl_einv_ve_edoc_crit DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_sadl_exit_calc_element_read.

  PROTECTED SECTION.
  PRIVATE SECTION.

    TYPES: BEGIN OF ty_row,
             status             TYPE zde_elt_status,
             statuscriticality  TYPE zde_einv_crit,
           END OF ty_row.

ENDCLASS.



CLASS zcl_einv_ve_edoc_crit IMPLEMENTATION.


  METHOD if_sadl_exit_calc_element_read~get_calculation_info.
    APPEND 'STATUS' TO et_requested_orig_elements.
  ENDMETHOD.


  METHOD if_sadl_exit_calc_element_read~calculate.
    DATA lt_data TYPE STANDARD TABLE OF ty_row WITH EMPTY KEY.

    lt_data = CORRESPONDING #( it_original_data ).

    LOOP AT lt_data ASSIGNING FIELD-SYMBOL(<ls>).
      <ls>-statuscriticality = SWITCH #( to_upper( <ls>-status )
        WHEN 'ACCEPTED'  THEN 3
        WHEN 'APPROVED'  THEN 3
        WHEN 'CLEARED'   THEN 3
        WHEN 'SENT'      THEN 3
        WHEN 'REJECTED'  THEN 1
        WHEN 'ERROR'     THEN 1
        WHEN 'FAILED'    THEN 1
        WHEN 'PENDING'   THEN 2
        WHEN 'IN_PROGRESS' THEN 2
        ELSE 0 ).
    ENDLOOP.

    ct_calculated_data = CORRESPONDING #( lt_data ).
  ENDMETHOD.


ENDCLASS.
