/* =====================================================================
   Inbound e-Invoice (AP) - derived values.

   Everything computed rather than stored, kept out of the business object's
   root view so that view stays 1:1 with ZTEDOC_APH.
   ===================================================================== */
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Inbound e-Invoice - derived values'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #C,
    sizeCategory: #L,
    dataClass: #TRANSACTIONAL
}
define view entity ZCDS_INT_EDOC_APENR as select from ztedoc_aph
{
  key uuid as Uuid,
      /* Second key field: ZCDS_INT_EDOC_APH is now keyed on
         UUID + DOCUMENTNUMBER, and _Enrich is a [1..1] association onto
         it, so this view has to carry the same key or the join is not
         one-to-one. */
  key documentnumber as DocumentNumber,

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
