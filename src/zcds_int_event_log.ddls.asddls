@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interface View for Event Log Table'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define root view entity ZCDS_INT_EVENT_LOG as select from ztevent_log
{
    key pan as Pan,
    key company as Company,
    key guid as Guid,
    key event_counter as EventCounter,
    key timestamp as Timestamp,
    key entry_date as EntryDate,
    key entry_time as EntryTime,
    workflow_id as WorkflowId,
    response as Response,
    category as Category,
    action as Action,
    error_description as ErrorDescription,
    doc_count as DocCount,
    value as Value,
    event_data as EventData,
    sent_flag as SentFlag,
    user_id as UserId,
    background_flag as BackgroundFlag,
    program_name as ProgramName,
    send_error_code as SendErrorCode,
    send_error_reason as SendErrorReason
}
