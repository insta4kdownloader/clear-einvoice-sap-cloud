@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Inbound e-Invoice Party'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #L,
    dataClass: #TRANSACTIONAL
}
@Metadata.allowExtensions: true
define view entity ZCDS_CUN_EDOC_APP
  as projection on ZCDS_INT_EDOC_APP
{
  key Uuid,
  key LineId,
  key PartyRole,
  key DocumentNumber,
      RoleCode,
      RoleCodeList,
      RoleName,
      EndpointId,
      EndpointScheme,
      PartyId,
      PartyIdScheme,
      PartyIdSchemeName,
      @Search.defaultSearchElement: true
      PartyName,
      Street,
      AdditionalStreet,
      AddressLine,
      City,
      PostalZone,
      Subdivision,
      SubdivisionCode,
      Country,
      @Search.defaultSearchElement: true
      VatId,
      VatIdScheme,
      TaxScheme,
      RegistrationName,
      LegalId,
      LegalIdScheme,
      LegalAgencyId,
      LegalAgencyName,
      LegalForm,
      ContactName,
      ContactTelephone,
      ContactMail,

      _Document : redirected to parent ZCDS_CUN_EDOC_APH
}
