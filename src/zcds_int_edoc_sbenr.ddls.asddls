/* =====================================================================
   Self-Billed e-Invoice - derived values.

   Everything computed rather than stored, kept out of the business object's
   root view so that view stays 1:1 with ZTEDOC_SBH.
   ===================================================================== */
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Self-Billed e-Invoice - derived values'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #C,
    sizeCategory: #L,
    dataClass: #TRANSACTIONAL
}
define view entity ZCDS_INT_EDOC_SBENR as select from ztedoc_sbh
{
  key uuid as Uuid,

      /* Replaces /CLR/EINV_STATUS-COLOR_CODE. The two HANA e-document
         cockpits had no status colouring at all - set_status_colors exists
         only on the sales side - so this is new, and it costs nothing. */
      case upper( status )
        when 'ACCEPTED'    then 3
        when 'APPROVED'    then 3
        when 'CLEARED'     then 3
        when 'SENT'        then 3
        when 'REJECTED'    then 1
        when 'ERROR'       then 1
        when 'FAILED'      then 1
        when 'PENDING'     then 2
        when 'IN_PROGRESS' then 2
        else 0
      end  as StatusCriticality
}
