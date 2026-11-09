@EndUserText.label: 'Seller Action VAT Rate Split'
define abstract entity ZCDS_ABS_EINV_VATSPLIT
{
      @EndUserText.label: 'Rate'
  key Rate                        : abap.dec( 5, 2 );

      @EndUserText.label: 'Amount Collected Incl. VAT'
      AmountCollectedIncludingVat : abap.dec( 15, 2 );

      _SellerAction               : association to parent ZCDS_ABS_EINV_SELLACT;
}
