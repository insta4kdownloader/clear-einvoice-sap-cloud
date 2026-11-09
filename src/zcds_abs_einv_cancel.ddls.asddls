/* =====================================================================
   Parameters of the CancelEInvoice action.

   /CLR/ZCL_EINV_BASE~cancel and ~call_cancel were empty in the base
   class and in all three country subclasses (_AE, _FR, _OM), so there
   is no reference implementation to port. The intended rules are
   documented only in message class /CLR/ZME_EINV:

     074  not authorized for cancellation
     075  cancel the document first
     078  ...
     089  cannot be cancelled after 72 hours
     090  ...

   ZCL_EINV_API_CLIENT~post_cancel implements the call against the
   EINV_CANCEL endpoint; the 72-hour rule is enforced in
   ZCL_EINV_COUNTRY_DEFAULT~check_cancel_allowed, where a country
   handler can override it.
   ===================================================================== */
@EndUserText.label: 'e-Invoice Cancellation Parameters'
define abstract entity ZCDS_ABS_EINV_CANCEL
{
      @EndUserText.label: 'Reason Code'
      @Consumption.valueHelpDefinition: [ { entity: { name: 'ZVH_EINV_REASONCODE', element: 'ReasonCode' } } ]
      ReasonCode  : zde_einv_reason;

      @EndUserText.label: 'Remarks'
      CommentText : zde_einv_errmsg;
}
