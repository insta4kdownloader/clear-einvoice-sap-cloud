@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Consumption View for e-Invoice API Endpo'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #CUSTOMIZING
}
@Metadata.allowExtensions: true
define root view entity ZCDS_CUN_EINV_API
  provider contract transactional_query
  as projection on ZCDS_INT_EINV_API
{
      @EndUserText.label: 'Project ID'
      @UI.selectionField: [ { position: 10 } ]
      key ProjectId,
      @EndUserText.label: 'System ID'
      @UI.selectionField: [ { position: 20 } ]
      key SystemId,
      @EndUserText.label: 'Country'
      @UI.selectionField: [ { position: 30 } ]
      @Consumption.valueHelpDefinition: [ { entity: { name: 'ZVH_EINV_COUNTRY', element: 'Country' } } ]
      key Country,
      @EndUserText.label: 'Company Code'
      @UI.selectionField: [ { position: 40 } ]
      @Consumption.valueHelpDefinition: [ { entity: { name: 'ZVH_EINV_COMPANYCODE', element: 'CompanyCode' } } ]
      key CompanyCode,
      @EndUserText.label: 'Functionality'
      @UI.selectionField: [ { position: 50 } ]
      key Functionality,
      @EndUserText.label: 'Sequence'
      @UI.selectionField: [ { position: 60 } ]
      key Sequence,
      @EndUserText.label: 'Endpoint URL'
      EndpointUrl,
      @EndUserText.label: 'Header Name'
      ParameterName,
      @EndUserText.label: 'Header Value'
      ParameterValue
}
