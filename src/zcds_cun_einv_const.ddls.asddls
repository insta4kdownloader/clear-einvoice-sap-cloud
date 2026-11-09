@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Consumption View for e-Invoice Generic C'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #CUSTOMIZING
}
@Metadata.allowExtensions: true
define root view entity ZCDS_CUN_EINV_CONST
  provider contract transactional_query
  as projection on ZCDS_INT_EINV_CONST
{
      @EndUserText.label: 'Project ID'
      @UI.selectionField: [ { position: 10 } ]
      key ProjectId,
      @EndUserText.label: 'System ID'
      @UI.selectionField: [ { position: 20 } ]
      key SystemId,
      @EndUserText.label: 'Product'
      @UI.selectionField: [ { position: 30 } ]
      key Product,
      @EndUserText.label: 'Country'
      @UI.selectionField: [ { position: 40 } ]
      @Consumption.valueHelpDefinition: [ { entity: { name: 'ZVH_EINV_COUNTRY', element: 'Country' } } ]
      key Country,
      @EndUserText.label: 'Company Code'
      @UI.selectionField: [ { position: 50 } ]
      @Consumption.valueHelpDefinition: [ { entity: { name: 'ZVH_EINV_COMPANYCODE', element: 'CompanyCode' } } ]
      key CompanyCode,
      @EndUserText.label: 'Label'
      @UI.selectionField: [ { position: 60 } ]
      key LabelCode,
      @EndUserText.label: 'Sequence'
      @UI.selectionField: [ { position: 70 } ]
      key Sequence,
      @EndUserText.label: 'Low'
      LowValue,
      @EndUserText.label: 'High'
      HighValue
}
