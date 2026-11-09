CLASS lhc_ZCDS_INT_EVENT_LOG DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR zcds_int_event_log RESULT result.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR zcds_int_event_log RESULT result.

ENDCLASS.

CLASS lhc_ZCDS_INT_EVENT_LOG IMPLEMENTATION.

  METHOD get_instance_authorizations.
    " Access to these configuration tables is governed by the business
    " catalog on the service binding, as it was by the transaction code in
    " the HANA package. Every instance is granted here.
    "
    " RESULT has to be filled: an instance-authorization handler that returns
    " an empty table denies every operation on every row, which leaves the
    " business object activated but inert.
    result = VALUE #( FOR ls_key IN keys
                      ( %tky      = ls_key-%tky
                        %update   = if_abap_behv=>auth-allowed
                        %delete   = if_abap_behv=>auth-allowed ) ).
  ENDMETHOD.

  METHOD get_global_authorizations.
    " CREATE has no instance to authorize, so it is covered here.
    result-%create = if_abap_behv=>auth-allowed.
    result-%update = if_abap_behv=>auth-allowed.
    result-%delete = if_abap_behv=>auth-allowed.
  ENDMETHOD.

ENDCLASS.
