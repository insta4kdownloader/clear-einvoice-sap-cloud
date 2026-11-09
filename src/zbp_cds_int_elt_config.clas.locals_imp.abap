CLASS lhc_zcds_int_elt_config DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR zcds_int_elt_config RESULT result.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR zcds_int_elt_config RESULT result.

ENDCLASS.

CLASS lhc_zcds_int_elt_config IMPLEMENTATION.

  METHOD get_instance_authorizations.
    " Access to this configuration table is governed by the business catalog
    " on the service binding, as it was by the transaction code in the HANA
    " package. Every instance is granted here.
    "
    " RESULT has to be filled: an instance-authorization handler that returns
    " an empty table denies every operation on every row, which leaves the
    " business object activated but inert.
    result = VALUE #( FOR ls_key IN keys
                      ( %tky    = ls_key-%tky
                        %update = if_abap_behv=>auth-allowed
                        %delete = if_abap_behv=>auth-allowed ) ).
  ENDMETHOD.

  METHOD get_global_authorizations.
    " CREATE has no instance to authorize, so it is covered here.
    result-%create = if_abap_behv=>auth-allowed.
    result-%update = if_abap_behv=>auth-allowed.
    result-%delete = if_abap_behv=>auth-allowed.
  ENDMETHOD.

  " The `updsysid` determination is gone, with the determination that
  " triggered it. It read the row and, when Sysid was blank, wrote back
  "
  "   MODIFY ... UPDATE FIELDS ( Sysid )
  "     WITH VALUE #( ( %tky = <row>-%tky Sysid = 'CXS' ) )
  "
  " which the tenant rejects with "Component SYSID multiply specified by
  " named include via %TKY": Sysid is one of the four key fields, so %tky
  " already carries it and the explicit assignment duplicates the component.
  " Removing the duplicate would not have helped - RAP does not let a
  " determination change a key field at all. A default for Sysid belongs on
  " the create payload instead: a UI default value, or
  " cl_abap_context_info=>get_system_id( ) in whatever creates the row.

ENDCLASS.
