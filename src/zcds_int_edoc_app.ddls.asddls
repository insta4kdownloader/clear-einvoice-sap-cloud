@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interface View for Inbound e-Invoice Par'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #L,
    dataClass: #TRANSACTIONAL
}
define view entity ZCDS_INT_EDOC_APP as select from ztedoc_app
  /* Both key fields, not just Uuid. A to-parent association has to
     determine exactly one parent row, and the parent's key is now
     UUID + DOCUMENTNUMBER - naming only half of it is rejected. */
  association to parent ZCDS_INT_EDOC_APH as _Document
    on  $projection.Uuid           = _Document.Uuid
    and $projection.DocumentNumber = _Document.DocumentNumber
{
      @EndUserText.label: 'E-Invoice unique document ID'
      /* /StandardBusinessDocument/StandardBusinessDocumentHeader/DocumentIdentification/InstanceIdentifier */
  key uuid as Uuid,
      @EndUserText.label: 'Invoice line ID (BT-126); blank = docume'
      /* /Invoice/cac:InvoiceLine/cbc:ID */
  key line_id as LineId,
      @EndUserText.label: 'Party role'
  key party_role as PartyRole,
      @EndUserText.label: 'Invoice number (BT-1)'
      /* /Invoice/cbc:ID */
  key documentnumber as DocumentNumber,
      @EndUserText.label: 'Party role code'
      /* <party>/cbc:IndustryClassificationCode */
      role_code as RoleCode,
      @EndUserText.label: 'Party role code list ID'
      /* <party>/cbc:IndustryClassificationCode/@listID */
      role_code_list as RoleCodeList,
      @EndUserText.label: 'Party role name'
      /* <party>/cbc:IndustryClassificationCode/@name */
      role_name as RoleName,
      @EndUserText.label: 'Electronic address (BT-34/49)'
      /* <party>/cbc:EndpointID */
      endpoint_id as EndpointId,
      @EndUserText.label: 'Electronic address scheme'
      /* <party>/cbc:EndpointID/@schemeID */
      endpoint_sch as EndpointScheme,
      @EndUserText.label: 'Party identifier (BT-29/46/60)'
      /* <party>/cac:PartyIdentification/cbc:ID */
      party_id as PartyId,
      @EndUserText.label: 'Identifier scheme ID'
      /* <party>/cac:PartyIdentification/cbc:ID/@schemeID */
      party_id_sch as PartyIdScheme,
      @EndUserText.label: 'Identifier scheme name'
      /* <party>/cac:PartyIdentification/cbc:ID/@schemeName */
      party_id_sch_name as PartyIdSchemeName,
      @EndUserText.label: 'Party trading name (BT-28/45)'
      /* <party>/cac:PartyName/cbc:Name */
      party_name as PartyName,
      @EndUserText.label: 'Address line 1 / street name'
      /* <party>/cac:PostalAddress/cbc:StreetName */
      street as Street,
      @EndUserText.label: 'Address line 2 / additional street'
      /* <party>/cac:PostalAddress/cbc:AdditionalStreetName */
      add_street as AdditionalStreet,
      @EndUserText.label: 'Address line 3'
      /* <party>/cac:PostalAddress/cac:AddressLine/cbc:Line */
      addr_line as AddressLine,
      @EndUserText.label: 'City'
      /* <party>/cac:PostalAddress/cbc:CityName */
      city as City,
      @EndUserText.label: 'Post code'
      /* <party>/cac:PostalAddress/cbc:PostalZone */
      postal_zone as PostalZone,
      @EndUserText.label: 'Country subdivision'
      /* <party>/cac:PostalAddress/cbc:CountrySubentity */
      subdiv as Subdivision,
      @EndUserText.label: 'Country subdivision code'
      /* <party>/cac:PostalAddress/cbc:CountrySubentityCode */
      subdiv_code as SubdivisionCode,
      @EndUserText.label: 'Country code'
      /* <party>/cac:PostalAddress/cac:Country/cbc:IdentificationCode */
      country as Country,
      @EndUserText.label: 'VAT identifier (BT-31/48/63)'
      /* <party>/cac:PartyTaxScheme/cbc:CompanyID */
      vat_id as VatId,
      @EndUserText.label: 'Identifier scheme ID'
      /* <party>/cac:PartyTaxScheme/cbc:CompanyID/@schemeID */
      vat_id_sch as VatIdScheme,
      @EndUserText.label: 'Tax scheme ID'
      /* <party>/cac:PartyTaxScheme/cac:TaxScheme/cbc:ID */
      tax_scheme as TaxScheme,
      @EndUserText.label: 'Party legal registration name (BT-27/44)'
      /* <party>/cac:PartyLegalEntity/cbc:RegistrationName */
      reg_name as RegistrationName,
      @EndUserText.label: 'Legal registration identifier (BT-30/47)'
      /* <party>/cac:PartyLegalEntity/cbc:CompanyID */
      legal_id as LegalId,
      @EndUserText.label: 'Identifier scheme ID'
      /* <party>/cac:PartyLegalEntity/cbc:CompanyID/@schemeID */
      legal_id_sch as LegalIdScheme,
      @EndUserText.label: 'Legal registration scheme agency ID'
      /* <party>/cac:PartyLegalEntity/cbc:CompanyID/@schemeAgencyID */
      legal_agency_id as LegalAgencyId,
      @EndUserText.label: 'Legal registration scheme agency name'
      /* <party>/cac:PartyLegalEntity/cbc:CompanyID/@schemeAgencyName */
      legal_agency_name as LegalAgencyName,
      @EndUserText.label: 'Additional legal information (BT-33)'
      /* <party>/cac:PartyLegalEntity/cbc:CompanyLegalForm */
      legal_form as LegalForm,
      @EndUserText.label: 'Contact point'
      /* <party>/cac:Contact/cbc:Name */
      contact_name as ContactName,
      @EndUserText.label: 'Contact telephone number'
      /* <party>/cac:Contact/cbc:Telephone */
      contact_tel as ContactTelephone,
      @EndUserText.label: 'Contact e-mail address'
      /* <party>/cac:Contact/cbc:ElectronicMail */
      contact_mail as ContactMail,

      _Document
}
