/* =====================================================================
   Action parameter for the Seller Action.

   Replaces classic dynpro 0200 of /CLR/ELT_EINVOICE_COCKPIT
   (include /CLR/ELT_EINVOICE_COCKPIT_SO01), which offered
   ACTIONTYPE + COLL_DATE plus an editable cl_gui_alv_grid VAT split
   table inside a cl_gui_custom_container.

   In RAP the same input becomes a deep action parameter: an abstract
   root entity with a composition to the VAT-split lines, so Fiori
   Elements renders it as a dialog with an editable table and no
   screen-painter object is needed.
   ===================================================================== */
@EndUserText.label: 'Seller Action Parameters'
define root abstract entity ZCDS_ABS_EINV_SELLACT
{
      /* The sales cockpit did NOT read /CLR/YT_ACTION. Dynpro 0200 offered
         exactly two values, hard-coded in MODULE status_0200:
             VRM_SET_VALUES ( COMPLETE / CONFIRM_PAYMENT )
         so the faithful port is the fixed-value list on the domain of
         ZDE_EINV_SELLER_ACT, not the configurable action-type value help,
         which belongs to the AP and self-billed cockpits. */
      @EndUserText.label: 'Action Type'
  key ActionType     : zde_einv_seller_act;

      @EndUserText.label: 'Collection Date'
      CollectionDate : abap.dats;

      @EndUserText.label: 'Comment'
      CommentText    : zde_einv_errmsg;

      /* The VAT split was a composition to ZCDS_ABS_EINV_VATSPLIT, so that
         Fiori Elements would render dynpro 0200's editable grid as a table
         inside the action dialog. The tenant does not materialise a
         composition in the generated %param structure - the handler's
         `ls_par-_VatSplit` is reported as a component that does not exist -
         so the split is four flat pairs instead. Four covers standard,
         reduced, zero and exempt, which is every regime this add-on has
         met. For an unbounded split, model it as a child entity of the
         business object and have SellerAction read it with EML; a deep
         action parameter is not the route. */
      @EndUserText.label: 'VAT Rate 1'
      VatRate1       : abap.dec( 5, 2 );
      @EndUserText.label: 'Amount Collected Incl. VAT 1'
      VatAmount1     : abap.dec( 15, 2 );

      @EndUserText.label: 'VAT Rate 2'
      VatRate2       : abap.dec( 5, 2 );
      @EndUserText.label: 'Amount Collected Incl. VAT 2'
      VatAmount2     : abap.dec( 15, 2 );

      @EndUserText.label: 'VAT Rate 3'
      VatRate3       : abap.dec( 5, 2 );
      @EndUserText.label: 'Amount Collected Incl. VAT 3'
      VatAmount3     : abap.dec( 15, 2 );

      @EndUserText.label: 'VAT Rate 4'
      VatRate4       : abap.dec( 5, 2 );
      @EndUserText.label: 'Amount Collected Incl. VAT 4'
      VatAmount4     : abap.dec( 15, 2 );
}
