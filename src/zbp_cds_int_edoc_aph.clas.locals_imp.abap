*"* Behaviour implementation of the Inbound e-Invoice (AP) business object.
*"*
*"* All the real work sits in ZCL_EINV_EDOC_ACTION, which this BO and its
*"* sibling share - the HANA originals (FORM send_action_data /
*"* self_send_action_data and FORM call_action_api / self_call_action_api)
*"* were two near-identical copies of the same ~200 lines, differing only in
*"* the EINV_TYPE literal, the endpoint and which party's VAT ID is sent as
*"* the taxpayer identifier.

CLASS lhc_edocument DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR edocument RESULT result.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR edocument RESULT result.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR edocument RESULT result.

    METHODS checkaction FOR VALIDATE ON SAVE
      IMPORTING keys FOR edocument~checkaction.

    METHODS sendaction FOR MODIFY
      IMPORTING keys FOR ACTION edocument~sendaction RESULT result.

ENDCLASS.


CLASS lhc_edocument IMPLEMENTATION.

  METHOD get_instance_authorizations.
    " The HANA cockpit checked nothing here; access to the transaction was the
    " whole authorization. In Public Cloud that is the business catalog on the
    " service binding, so every instance is granted.
    "
    " RESULT must be filled. An instance-authorization handler that returns an
    " empty table denies every operation on every row, which would leave this
    " business object activated but completely inert.
    result = VALUE #( FOR ls_auth IN keys
                      ( %tky = ls_auth-%tky %update = if_abap_behv=>auth-allowed ) ).
  ENDMETHOD.


  METHOD get_global_authorizations.
    result-%update = if_abap_behv=>auth-allowed.
  ENDMETHOD.


  METHOD get_instance_features.
    " The HANA cockpit drove button visibility from /CLR/EINV_APALV, whose
    " EINV_TYPE key field was added precisely so PURCHASE and SELF_BILLED could
    " have different toolbars. FORM get_excluded_fcodes was never updated to
    " filter on it, so deactivating a button for one variant hid it for both.
    " Feature control per instance replaces the whole mechanism and cannot have
    " that bug.
    READ ENTITIES OF zcds_int_edoc_aph IN LOCAL MODE
      ENTITY edocument FIELDS ( ActionType Status ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_doc).

    result = VALUE #( FOR ls IN lt_doc
      ( %tky = ls-%tky
        %action-SendAction = COND #( WHEN ls-ActionType IS NOT INITIAL
                                     THEN if_abap_behv=>fc-o-enabled
                                     ELSE if_abap_behv=>fc-o-disabled ) ) ).
  ENDMETHOD.


  METHOD checkaction.
    " Ported from FORM send_action_data: the action type is mandatory, and if
    " the action has any reason codes in /CLR/YT_REASON then the reason code is
    " mandatory AND must be one of the codes configured for that action.
    READ ENTITIES OF zcds_int_edoc_aph IN LOCAL MODE
      ENTITY edocument FIELDS ( ActionType ReasonCode ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_doc).

    DATA(lo_action) = NEW zcl_einv_edoc_action( iv_einv_type = 'PURCHASE' ).

    LOOP AT lt_doc INTO DATA(ls_doc).
      DATA(lv_msg) = lo_action->validate_action( iv_action_type = ls_doc-ActionType
                                                 iv_reason_code = ls_doc-ReasonCode ).
      IF lv_msg IS NOT INITIAL.
        APPEND VALUE #( %tky = ls_doc-%tky ) TO failed-edocument.
        APPEND VALUE #( %tky = ls_doc-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = lv_msg )
                        %element-ActionType = if_abap_behv=>mk-on )
               TO reported-edocument.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD sendaction.
    READ ENTITIES OF zcds_int_edoc_aph IN LOCAL MODE
      ENTITY edocument ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_doc).

    " The taxpayer identifier the platform expects is the VAT ID of the seller
    " for an inbound document and of the buyer for a self-billed one. Both now
    " live as rows of the party table rather than as header columns, so they
    " are read once for the whole request.
    " Document-level parties only (LINE_ID blank). A line-level party is an
    " item manufacturer, never the taxpayer. This was a helper method until
    " the tenant rejected its signature: a RAP derived type is not permitted
    " on a RETURNING parameter, and TABLE FOR ACTION IMPORT on the importing
    " parameter made the class fail to compile whenever the behaviour
    " definition was not yet active. Inlined, it needs neither.
    READ ENTITIES OF zcds_int_edoc_aph IN LOCAL MODE
      ENTITY edocument BY \_Party
        FIELDS ( Uuid LineId PartyRole PartyName VatId ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_all_party).

    DATA(lt_party) = lt_all_party.
    DELETE lt_party WHERE LineId IS NOT INITIAL.

    DATA(lo_action) = NEW zcl_einv_edoc_action( iv_einv_type = 'PURCHASE' ).
    DATA lt_update TYPE TABLE FOR UPDATE zcds_int_edoc_aph.

    LOOP AT keys INTO DATA(ls_key).
      DATA(ls_doc) = VALUE #( lt_doc[ KEY entity Uuid = ls_key-Uuid ] OPTIONAL ).

      " A key the READ did not return is one the user may not see or that was
      " deleted meanwhile. Without this check the action would be sent to the
      " platform with an all-initial document.
      IF ls_doc-Uuid IS INITIAL.
        APPEND VALUE #( %tky = ls_key-%tky ) TO failed-edocument.
        APPEND VALUE #( %tky = ls_key-%tky
                        %msg = new_message( id       = 'ZEINV_MSG'
                                            number   = '037'
                                            severity = if_abap_behv_message=>severity-error ) )
               TO reported-edocument.
        CONTINUE.
      ENDIF.

      DATA(ls_res) = lo_action->send(
        is_document  = VALUE #( documentid     = ls_doc-DocumentId
                                documentnumber = ls_doc-DocumentNumber
                                issue_dt       = ls_doc-IssueDate
                                inv_typ_code   = ls_doc-InvoiceTypeCode
                                seller_vat     = VALUE #( lt_party[ Uuid      = ls_doc-Uuid
                                                                    PartyRole = 'SELLER' ]-VatId OPTIONAL )
                                buyer_vat      = VALUE #( lt_party[ Uuid      = ls_doc-Uuid
                                                                    PartyRole = 'BUYER' ]-VatId OPTIONAL ) )
        iv_action_type = COND #( WHEN ls_key-%param-ActionType IS NOT INITIAL
                                 THEN ls_key-%param-ActionType ELSE ls_doc-ActionType )
        iv_reason_code = COND #( WHEN ls_key-%param-ReasonCode IS NOT INITIAL
                                 THEN ls_key-%param-ReasonCode ELSE ls_doc-ReasonCode )
        iv_comment     = COND #( WHEN ls_key-%param-CommentText IS NOT INITIAL
                                 THEN ls_key-%param-CommentText ELSE ls_doc-CommentText ) ).

      " API_MESSAGE was in-memory only in the HANA grid and lost on exit.
      " Persisting it is the point of having a business object.
      APPEND VALUE #( %tky                = ls_key-%tky
                      %control-Status     = if_abap_behv=>mk-on
                      %control-ApiMessage = if_abap_behv=>mk-on
                      Status              = ls_res-status
                      ApiMessage          = ls_res-message )
             TO lt_update.

      IF ls_res-success = abap_false.
        APPEND VALUE #( %tky = ls_key-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = CONV string( ls_res-message ) ) )
               TO reported-edocument.
      ENDIF.
    ENDLOOP.

    MODIFY ENTITIES OF zcds_int_edoc_aph IN LOCAL MODE
      ENTITY edocument UPDATE FIELDS ( Status ApiMessage ) WITH lt_update
      REPORTED DATA(ls_rep)
      FAILED   DATA(ls_fail).

    " Whatever the inner EML call reported has to be carried into this
    " handler's own REPORTED/FAILED, otherwise it is discarded and the caller
    " is told the action succeeded.
    reported-edocument = VALUE #( BASE reported-edocument ( LINES OF ls_rep-edocument ) ).
    failed-edocument   = VALUE #( BASE failed-edocument   ( LINES OF ls_fail-edocument ) ).

    READ ENTITIES OF zcds_int_edoc_aph IN LOCAL MODE
      ENTITY edocument ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_final).

    result = VALUE #( FOR ls_f IN lt_final ( %tky = ls_f-%tky %param = ls_f ) ).
  ENDMETHOD.


ENDCLASS.
