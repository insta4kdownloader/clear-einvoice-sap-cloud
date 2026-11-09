@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Cunsumption View for Event Log Table'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
@Metadata.allowExtensions: true
define view entity ZCDS_CUN_EVENT_LOG as select from ZCDS_INT_EVENT_LOG
{
@EndUserText.label: 'Pan'
    key Pan,
    @EndUserText.label: 'Company'
    key Company,
    @UI: { selectionField: [{ position: 20 }] }
    @EndUserText.label: 'Guid'
    key Guid,
    @EndUserText.label: 'EventCounter'
    key EventCounter,
    @EndUserText.label: 'Timestamp'
    key Timestamp,
    @EndUserText.label: 'EntryDate'
    @UI: { selectionField: [{ position: 10 }] }
    @Consumption.valueHelpDefinition: [{entity: {element: 'EntryDate' , name: 'ZVH_ENTRY_DATE' }}]
    key EntryDate,
    @EndUserText.label: 'EntryTime'
    key EntryTime,
    @UI: { selectionField: [{ position: 30 }] }
    @EndUserText.label: 'WorkflowId'
    WorkflowId,
    @EndUserText.label: 'Response'
    Response,
    @EndUserText.label: 'Category'
    Category,
    @EndUserText.label: 'Action'
    Action,
    @EndUserText.label: 'ErrorDescription'
    ErrorDescription,
    @EndUserText.label: 'DocCount'
    DocCount,
    @EndUserText.label: 'Value'
    Value,
    @EndUserText.label: 'EventData'
    EventData,
    @EndUserText.label: 'SentFlag'
    SentFlag,
    @EndUserText.label: 'UserId'
    UserId,
    @EndUserText.label: 'BackgroundFlag'
    BackgroundFlag,
    @EndUserText.label: 'ClassName'
    ProgramName,
    @EndUserText.label: 'SendErrorCode'
    SendErrorCode,
    @EndUserText.label: 'SendErrorReason'
    SendErrorReason
}
