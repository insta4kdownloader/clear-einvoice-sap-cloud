"! <p class="shorttext synchronized">e-Invoice: status criticality (virtual element)</p>
"!
"! Fills the virtual element StatusCriticality of ZCDS_CUN_EINV_DOC.
"!
"! Replaces two pieces of SAP GUI machinery at once:
"!
"!  1. /CLR/ZCL_EINV_BASE~set_status_colors, which per row did
"!       READ TABLE gt_einv_status WITH KEY sync_status = status.
"!       APPEND VALUE lvc_s_scol( fname = 'STATUS'
"!                                color-col = color_code ) TO cellcolor.
"!     together with GWA_LAYOUT-CTAB_FNAME = 'CELLCOLOR'.
"!
"!  2. The icon columns /CLR/EINV_STATUS-SYNC_ICON / ASYNC_ICON and
"!     /CLR/EINV_FCAT-ICON, which held SAP GUI icon literals
"!     (@5B@ green, @5C@ red, @5D@ pending, @02@ cancelled, @BZ@ not
"!     processed) - meaningless outside SAP GUI.
"!
"! In Fiori a numeric criticality (0 neutral, 1 negative, 2 critical,
"! 3 positive) drives the colour and the icon, so the configuration
"! shrinks to one column and the presentation is the client's job.
CLASS zcl_einv_ve_criticality DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_sadl_exit_calc_element_read.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_einv_ve_criticality IMPLEMENTATION.


  METHOD if_sadl_exit_calc_element_read~get_calculation_info.
    " Tell the framework which real fields the virtual element needs.
    APPEND 'COMPANYCODE'     TO et_requested_orig_elements.
    APPEND 'EFFECTIVESTATUS' TO et_requested_orig_elements.
  ENDMETHOD.


  METHOD if_sadl_exit_calc_element_read~calculate.
    DATA lt_data TYPE STANDARD TABLE OF zcds_cun_einv_doc WITH EMPTY KEY.

    lt_data = CORRESPONDING #( it_original_data ).

    LOOP AT lt_data ASSIGNING FIELD-SYMBOL(<ls_row>).
      <ls_row>-StatusCriticality =
        zcl_einv_country_factory=>get_handler( <ls_row>-CompanyCode
          )->map_criticality( iv_bukrs  = <ls_row>-CompanyCode
                              iv_status = <ls_row>-EffectiveStatus ).
    ENDLOOP.

    ct_calculated_data = CORRESPONDING #( lt_data ).
  ENDMETHOD.


ENDCLASS.
