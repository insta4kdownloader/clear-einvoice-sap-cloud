/* =====================================================================
   Parameters of the SendAction action of the Inbound e-Invoice (AP) business object.

   Replaces the editable ALV columns of the HANA cockpit. There, the action
   type and reason code were maintained inline in a cl_gui_alv_grid with two
   dropdown handle mechanisms:

     - ACTION_TYPE  a static handle loaded from
                    /CLR/YT_ACTION WHERE EINV_TYPE = 'PURCHASE'
     - REASON_CODE  a per-row handle (DRDN_FIELD = 'REASON_HNDL') with
                    handles allocated one per distinct action type and
                    re-pointed by an ON_DATA_CHANGED_FINISHED event handler
                    whenever the user changed the action type

   In Fiori that entire apparatus is two value helps with a filter
   dependency, so the dropdown handles, the handle map and the event
   handler class all disappear.

   The parameters are optional: leaving one empty keeps whatever is already
   on the document, which is how the HANA grid behaved.
   ===================================================================== */
@EndUserText.label: 'Inbound e-Invoice Action Parameters'
define abstract entity ZCDS_ABS_EINV_APACT
{
      @EndUserText.label: 'Action Type'
      @Consumption.valueHelpDefinition: [ { entity: { name: 'ZVH_EINV_ACTTYPE_AP',
                                                      element: 'ActionType' } } ]
      ActionType  : zde_einv_action;

      @EndUserText.label: 'Reason Code'
      @Consumption.valueHelpDefinition: [ { entity: { name: 'ZVH_EINV_REASONCODE',
                                                      element: 'ReasonCode' },
                                            additionalBinding: [ { localElement: 'ActionType',
                                                                   element: 'ActionType',
                                                                   usage: #FILTER_AND_RESULT } ] } ]
      ReasonCode  : zde_einv_reason;

      @EndUserText.label: 'Comment'
      CommentText : zde_elt_comment;
}
