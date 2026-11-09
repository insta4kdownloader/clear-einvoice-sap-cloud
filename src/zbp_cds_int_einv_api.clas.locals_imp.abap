CLASS lhc_EINV_API DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR API
      RESULT result.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR API
      RESULT result.

ENDCLASS.

CLASS lhc_EINV_API IMPLEMENTATION.

  METHOD get_instance_authorizations.
    " Configuration tables: access is governed by the business
    " catalog assigned to the service binding, so every instance is
    " granted here. RESULT must be filled - an instance
    " authorization handler that returns nothing denies everything.
    " Add company-code or country restrictions here once a
    " restriction field is defined in the IAM business role.
    result = VALUE #( FOR ls_key IN keys
                      ( %tky    = ls_key-%tky
                        %update = if_abap_behv=>auth-allowed
                        %delete = if_abap_behv=>auth-allowed ) ).
  ENDMETHOD.


  METHOD get_global_authorizations.
    " Covers CREATE, which has no instance to authorize.
    result-%create = if_abap_behv=>auth-allowed.
    result-%update = if_abap_behv=>auth-allowed.
    result-%delete = if_abap_behv=>auth-allowed.
  ENDMETHOD.

ENDCLASS.
