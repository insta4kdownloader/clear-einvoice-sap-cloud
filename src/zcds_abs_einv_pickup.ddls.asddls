/* =====================================================================
   Parameters of the PickUpDocuments static action.

   These are exactly the selection-screen fields of
   /CLR/ELT_EINVOICE_SEL that were actually evaluated by get_data.
   The dead ones (P_SUBM, P_CAN, P_LOG) are deliberately not carried
   over, and /CLR/EINV_SELSCR (show/hide per country) is obsolete -
   Fiori adaptation handles field visibility.

   As in the HANA version, at least one of the two date ranges must be
   supplied (message /CLR/ZME_EINV 015 -> ZEINV_MSG 015).
   ===================================================================== */
@EndUserText.label: 'e-Invoice Pick-Up Parameters'
define abstract entity ZCDS_ABS_EINV_PICKUP
{
      @EndUserText.label: 'Project ID'
      @Consumption.valueHelpDefinition: [ { entity: { name: 'ZVH_EINV_PROJECT', element: 'ProjectId' } } ]
      ProjectId          : zde_einv_projectid;

      @EndUserText.label: 'Company Code'
      @Consumption.valueHelpDefinition: [ { entity: { name: 'ZVH_EINV_COMPANYCODE', element: 'CompanyCode' } } ]
      CompanyCode        : zde_einv_bukrs;

      @EndUserText.label: 'Posting Date From'
      PostingDateFrom    : abap.dats;

      @EndUserText.label: 'Posting Date To'
      PostingDateTo      : abap.dats;

      @EndUserText.label: 'Creation Date From'
      CreationDateFrom   : abap.dats;

      @EndUserText.label: 'Creation Date To'
      CreationDateTo     : abap.dats;

      @EndUserText.label: 'Billing Document'
      BillingDocument    : zde_einv_billdoc;

      @EndUserText.label: 'Accounting Document'
      AccountingDocument : zde_einv_accdoc;

      @EndUserText.label: 'Fiscal Year'
      FiscalYear         : zde_einv_gjahr;

      @EndUserText.label: 'Submit Immediately'
      SubmitImmediately  : zde_einv_flag;
}
