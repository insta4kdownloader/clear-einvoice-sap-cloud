CLASS zcl_elt DEFINITION
PUBLIC
FINAL
CREATE PUBLIC .

PUBLIC SECTION.

TYPES : BEGIN OF ty_logs,
ex_log_no_command TYPE string,
ex_log_command_id TYPE string,
ex_event_count TYPE string,
ex_file_name TYPE string,
gc_extraction_empty_metadata TYPE string,
gc_extraction_empty_command_id TYPE string,
ex_send_api_fail_gen_prsi TYPE string,
ex_rcv_api_gen_prsi_ret_code TYPE string,
ex_rcv_api_gen_prsi_resp TYPE string,
ex_rcv_api_gen_prsi_resp_init TYPE string,
ex_rcv_api_gen_prsi_ret_code_f TYPE string,
ex_abap_response TYPE string,
ex_status_code TYPE string,
ex_reason TYPE string,
ex_pre_sign_url TYPE string,
ex_gen_pre_sign_url TYPE string,
ex_ingestfile_status_code TYPE string,
ex_ingestfile_reason TYPE string,
ex_rcv_api_upload_ret_code_f TYPE string,
ex_rcv_api_upload_ret_code TYPE string,
ex_send_api_fail_upload TYPE string,
ex_create_url_fail_upload TYPE string,
ex_postcomm_status_code TYPE string,
ex_postcomm_reason TYPE string,
ex_post_comm_url_not_maint TYPE string,
ex_create_url_fail_post_comm TYPE string,
ex_send_api_fail_post_comm TYPE string,
ex_rcv_api_post_com_ret_code_f TYPE string,
END OF ty_logs.

DATA : it_logs TYPE STANDARD TABLE OF ty_logs,
wa_logs TYPE ty_logs.

CONSTANTS: gc_auth TYPE string VALUE 'AUTH',
gc_http_success TYPE i VALUE '200',
gc_act_stat_succ TYPE string VALUE 'EXECUTION_COMPLETED',
gc_act_stat_fail TYPE string VALUE 'EXECUTION_FAILURE',
gc_auth_token TYPE string VALUE 'x-clear-auth-token',
gc_erp_instance_id TYPE string VALUE 'x-erp-instance-id',
gc_erp_id TYPE string VALUE 'ERP_INSTANCE_ID',
gc_clr_sdk_version TYPE string VALUE 'x-clear-sdk-version',
gc_content_type TYPE string VALUE 'Content-Type', "#EC NOTEXT
gc_erp_version TYPE string VALUE 'x-erp-version',
gc_erp_type TYPE string VALUE 'x-erp-type',
gc_appl_json TYPE string VALUE 'application/json',
gc_appl_zip TYPE string VALUE 'application/zip',
gc_workspace_id TYPE string VALUE 'x-workspace-id',
gc_org_id TYPE string VALUE 'x-cleartax-orgunit',
gc_product TYPE string VALUE 'x-cleartax-product',
gc_file_cont_type TYPE string VALUE 'filecontenttype',
gc_api_type_get_command TYPE string VALUE 'GET_COMMAND',
gc_presign TYPE string VALUE 'PRESIGN',
gc_ping TYPE string VALUE 'PING'.

DATA : im_erp_config TYPE string,
im_hostname TYPE string,
im_auth_token TYPE string,
im_erp_instance_config TYPE string.


TYPES: BEGIN OF ty_s_fae_ref_fields,
field TYPE string,
END OF ty_s_fae_ref_fields,
BEGIN OF ty_s_fae_index,
name TYPE string,
table_data TYPE REF TO data,
it_fcat TYPE zstr_fcat_tt,
union TYPE abap_boolean,
union_data TYPE REF TO data,
END OF ty_s_fae_index.

TYPES: ty_t_fae_ref_fields TYPE TABLE OF ty_s_fae_ref_fields .
DATA gt_fae_ref_fields TYPE ty_t_fae_ref_fields .
DATA: gt_erp_config TYPE TABLE OF ztelt_config,
gt_context_data TYPE TABLE OF ty_s_fae_index,
gt_fae_index TYPE TABLE OF ty_s_fae_index,
gv_url_retry_count TYPE i,
gv_url_retry_wait_min TYPE i,
gv_url_retry_wait_sec TYPE i.

DATA go_event_instance TYPE REF TO zcl_instru_event_class.
DATA:gv_event_counter TYPE zde_event_counter.

" The ZTELT_CONFIG profile this instance reads. /CLR/ZCL_ELT took it as
" IV_SEQ and passed it to GET_ERP_CONFIG; the conversion dropped the
" parameter and the WHERE condition with it. Section 77.
DATA gv_seq TYPE ztelt_config-sequence.
DATA: lr_http_client TYPE REF TO if_web_http_client.

DATA: struct_type TYPE REF TO cl_abap_structdescr, "Structure
table_type TYPE REF TO cl_abap_tabledescr, "Table type
dataref TYPE REF TO data.


DATA: gt_fi_data TYPE cl_abap_structdescr=>component_table,
gs_fi_data LIKE LINE OF gt_fi_data.

METHODS : generate_pre_sign EXPORTING es_abap_response TYPE zstr_elt_presigned_url
ev_status_code TYPE i
ev_reason TYPE string
ex_pre_sign_url TYPE string
ex_gen_pre_sign_url TYPE string
gc_send_api_fail_gen_prsi TYPE string
gc_rcv_api_gen_prsi_ret_code TYPE string
gc_rcv_api_gen_prsi_resp TYPE string
gc_rcv_api_gen_prsi_resp_init TYPE string
gc_rcv_api_gen_prsi_ret_code_f TYPE string
ex_send_api_fail_gen_prsi TYPE string
ex_rcv_api_gen_prsi_ret_code TYPE string
ex_rcv_api_gen_prsi_resp TYPE string
ex_rcv_api_gen_prsi_resp_init TYPE string
ex_rcv_api_gen_prsi_ret_code_f TYPE string.

METHODS : ingest_files IMPORTING iv_presigned_url TYPE zstr_elt_presigned_url-result-payload OPTIONAL
EXPORTING ev_status_code TYPE i
ev_reason TYPE string
gc_rcv_api_upload_ret_code_f TYPE string
gc_rcv_api_upload_ret_code TYPE string
gc_send_api_fail_upload TYPE string
gc_create_url_fail_upload TYPE string
ex_rcv_api_upload_ret_code_f TYPE string
ex_rcv_api_upload_ret_code TYPE string
ex_send_api_fail_upload TYPE string
ex_create_url_fail_upload TYPE string.
"""""""""""""""""Normal constructors
METHODS : constructor IMPORTING iv_date_from TYPE sydate OPTIONAL
iv_date_to TYPE sydate OPTIONAL
iv_tab_name TYPE zde_as4tab OPTIONAL
iv_guid TYPE zde_guid_22 OPTIONAL
iv_event_counter TYPE zde_event_counter OPTIONAL
iv_comm TYPE zstr_elt_comm_data-command_id OPTIONAL
"! The ZTELT_CONFIG profile to read. /CLR/ZCL_ELT declared this as
"! IV_SEQ TYPE /CLR/ZT_ELT_CNFG-SEQUENCE and every caller supplied it
"! from the Sequence field of its selection screen. Section 77.
iv_seq TYPE ztelt_config-sequence OPTIONAL.






METHODS : trigger_ingestion IMPORTING is_config TYPE zstr_elt_comm_data-metadata-erp_config
EXPORTING es_config TYPE zstr_elt_comm_data-metadata-erp_config
""""""""""""Create file
ex_file_name TYPE string
""""""""""""generate pre sign
ex_send_api_fail_gen_prsi TYPE string
ex_rcv_api_gen_prsi_ret_code TYPE string
ex_rcv_api_gen_prsi_resp TYPE string
ex_rcv_api_gen_prsi_resp_init TYPE string
ex_rcv_api_gen_prsi_ret_code_f TYPE string
ex_abap_response TYPE zstr_elt_presigned_url
ex_status_code TYPE string
ex_reason TYPE string
ex_pre_sign_url TYPE string
ex_gen_pre_sign_url TYPE string
""""""""""Ingest file
ex_ingestfile_status_code TYPE i
ex_ingestfile_reason TYPE string
ex_rcv_api_upload_ret_code_f TYPE string
ex_rcv_api_upload_ret_code TYPE string
ex_send_api_fail_upload TYPE string
ex_create_url_fail_upload TYPE string
""""""""""""Post command
ex_postcomm_status_code TYPE string
ex_postcomm_reason TYPE string
ex_post_comm_url_not_maint TYPE string
ex_create_url_fail_post_comm TYPE string
ex_send_api_fail_post_comm TYPE string
ex_rcv_api_post_com_ret_code_f TYPE string.



METHODS : get_command EXPORTING ev_status_code TYPE i
ev_elt_command TYPE zstr_elt_command
ev_reason TYPE string
gc_get_comm_url_not_maint TYPE string
gc_create_url_fail_get_com TYPE string
gc_send_api_fail_get_com TYPE string
gc_rcv_api_get_com_resp_init TYPE string
gc_rcv_api_get_com_ret_code TYPE string.

METHODS : get_exec_program IMPORTING is_elt_command TYPE zstr_elt_command.

METHODS : post_command IMPORTING is_metadata TYPE zstr_elt_meta_post_comm OPTIONAL
EXPORTING ev_status_code TYPE i
ev_reason TYPE string
gc_rcv_api_post_com_ret_code_f TYPE string
gc_send_api_fail_post_comm TYPE string
gc_create_url_fail_post_comm TYPE string
gc_post_comm_url_not_maint TYPE string
ex_post_comm_url_not_maint TYPE string
ex_create_url_fail_post_comm TYPE string
ex_send_api_fail_post_comm TYPE string
ex_rcv_api_post_com_ret_code_f TYPE string.

METHODS : ping_test EXPORTING ex_ping_url TYPE string
ex_ping_empty_response TYPE string
ex_ping_fail TYPE string.

METHODS : trigger_posting IMPORTING is_file_details TYPE zstr_elt_s3_detail_get.

METHODS : elt_exec_command
EXPORTING et_logs LIKE it_logs
ex_log_no_command TYPE string
ex_log_command_id TYPE string
ex_event_count TYPE string
ex_file_name TYPE string
gc_extraction_empty_metadata TYPE string
gc_extraction_empty_command_id TYPE string
ex_send_api_fail_gen_prsi TYPE string
ex_rcv_api_gen_prsi_ret_code TYPE string
ex_rcv_api_gen_prsi_resp TYPE string
ex_rcv_api_gen_prsi_resp_init TYPE string
ex_rcv_api_gen_prsi_ret_code_f TYPE string
ex_abap_response TYPE string
ex_status_code TYPE string
ex_reason TYPE string
ex_pre_sign_url TYPE string
ex_gen_pre_sign_url TYPE string
ex_ingestfile_status_code TYPE string
ex_ingestfile_reason TYPE string
ex_rcv_api_upload_ret_code_f TYPE string
ex_rcv_api_upload_ret_code TYPE string
ex_send_api_fail_upload TYPE string
ex_create_url_fail_upload TYPE string
ex_postcomm_status_code TYPE string
ex_postcomm_reason TYPE string
ex_post_comm_url_not_maint TYPE string
ex_create_url_fail_post_comm TYPE string
ex_send_api_fail_post_comm TYPE string
ex_rcv_api_post_com_ret_code_f TYPE string
.

METHODS : elt_ingestion IMPORTING im_elt_command TYPE zstr_elt_command
im_commid TYPE zstr_elt_command-result-command OPTIONAL
im_meta TYPE zstr_elt_command-result-metadata OPTIONAL
im_guid TYPE zde_guid_22 OPTIONAL
im_event_count TYPE zde_int4 OPTIONAL
EXPORTING ex_file_name TYPE string
gc_extraction_empty_metadata TYPE string
gc_extraction_empty_command_id TYPE string
ex_send_api_fail_gen_prsi TYPE string
ex_rcv_api_gen_prsi_ret_code TYPE string
ex_rcv_api_gen_prsi_resp TYPE string
ex_rcv_api_gen_prsi_resp_init TYPE string
ex_rcv_api_gen_prsi_ret_code_f TYPE string
ex_abap_response TYPE string
ex_status_code TYPE string
ex_reason TYPE string
ex_pre_sign_url TYPE string
ex_gen_pre_sign_url TYPE string
ex_ingestfile_status_code TYPE string
ex_ingestfile_reason TYPE string
ex_rcv_api_upload_ret_code_f TYPE string
ex_rcv_api_upload_ret_code TYPE string
ex_send_api_fail_upload TYPE string
ex_create_url_fail_upload TYPE string
ex_postcomm_status_code TYPE string
ex_postcomm_reason TYPE string
ex_post_comm_url_not_maint TYPE string
ex_create_url_fail_post_comm TYPE string
ex_send_api_fail_post_comm TYPE string
ex_rcv_api_post_com_ret_code_f TYPE string.

* PROTECTED SECTION.
* PRIVATE SECTION.

CONSTANTS: gc_hostname TYPE string VALUE 'HOSTNAME',
gc_post_command TYPE string VALUE 'POST_COMMAND',
gc_rfc TYPE string VALUE 'RFC',
gc_api_type_presign TYPE string VALUE 'GENERATE_PRESIGN'.
DATA: gv_hostname TYPE string,
gv_auth_token TYPE string,
gv_erp_instance_id TYPE string,
go_zip TYPE REF TO cl_abap_zip,
gt_config_tables TYPE zstr_dynamic_query_tt,
gv_command_id TYPE zstr_elt_comm_data-command_id.
DATA gt_table TYPE REF TO data.
DATA gv_zip_file_name TYPE string.
DATA gv_zip_file_data TYPE xstring .
TYPES: BEGIN OF ty_s_file_urls,
tabname TYPE string,
filename TYPE string,
presigned_url TYPE string,
actual_url TYPE string,
filedata TYPE xstring,
END OF ty_s_file_urls .
TYPES:ty_t_file_urls TYPE TABLE OF ty_s_file_urls .
DATA gt_file_urls TYPE ty_t_file_urls.

METHODS : get_auth_token "EXPORTING ex_erp_config TYPE string
RETURNING VALUE(ex_auth_token) TYPE string.

METHODS : create_files IMPORTING it_tables TYPE zstr_dynamic_query_tt OPTIONAL
EXPORTING ex_file_name TYPE string.

METHODS : prepare_query IMPORTING is_table TYPE zstr_dynamic_query
iv_header_flag TYPE ABAP_BOOLEAN OPTIONAL
EXPORTING et_fcat TYPE zstr_fcat_tt
ev_where TYPE string
ev_order_by TYPE string
ev_from TYPE string.

METHODS : execute_db_query IMPORTING iv_where TYPE string OPTIONAL
iv_order_by TYPE string OPTIONAL
iv_column_syntax TYPE string OPTIONAL
iv_from TYPE string
ir_header_table TYPE REF TO data OPTIONAL
it_fcat TYPE zstr_fcat_tt OPTIONAL
is_table TYPE zstr_dynamic_query OPTIONAL
iv_precondition_flag TYPE abap_boolean OPTIONAL
EXPORTING et_fieldcat_persist TYPE zstr_fcat_tt
ev_boolean TYPE abap_boolean
et_fieldcat TYPE zstr_fcat_tt.

METHODS : prepare_where_clause IMPORTING is_schema TYPE zstr_dynamic_query
RETURNING VALUE(rv_where_clause) TYPE string.

METHODS : prepare_single_cond_clause IMPORTING is_expr TYPE zstr_where
RETURNING VALUE(rv_expr_clause) TYPE string.

METHODS : get_erp_config RETURNING VALUE(ex_erp_config) TYPE string.

METHODS : get_erp_instance_id "RETURNING VALUE(ex_erp_config) TYPE string
RETURNING VALUE(ex_erp_instance_config) TYPE string.

METHODS : get_hostname "EXPORTING ex_erp_config TYPE string
RETURNING VALUE(ex_hostname) TYPE string.

METHODS : check_precondition IMPORTING is_schema TYPE zstr_elt_posting
iv_row_no TYPE sy-tabix
EXPORTING ev_error TYPE abap_boolean.

METHODS : store_table_data IMPORTING is_table TYPE zstr_dynamic_query
it_fieldcat_persist TYPE zstr_fcat_tt.

METHODS : get_context_data IMPORTING is_schema TYPE zstr_elt_posting.

METHODS : insert_table IMPORTING is_schema TYPE zstr_elt_posting.

METHODS : get_posting_file IMPORTING is_file_url TYPE zstr_elt_s3_detail_get
EXPORTING es_abap_response TYPE string.

METHODS : update_post_success IMPORTING is_elt_succ TYPE ztelt_success
EXPORTING ev_subrc TYPE sy-subrc
ev_dbcnt TYPE sy-dbcnt.

METHODS : update_post_failure IMPORTING is_elt_errs TYPE ztelt_errors
EXPORTING ev_subrc TYPE sy-subrc
ev_dbcnt TYPE sy-dbcnt.

PROTECTED SECTION.
PRIVATE SECTION.

ENDCLASS.



CLASS ZCL_ELT IMPLEMENTATION.


METHOD check_precondition.
DATA:ls_query_schema TYPE zstr_dynamic_query,
ls_posting_result TYPE zstr_elt_posting_result,
ls_metadata TYPE zstr_elt_meta_get_comm,
lv_cnt TYPE i.

DATA:ls_elt_errs TYPE ztelt_errors.
CLEAR ev_error.
LOOP AT is_schema-pre_condition ASSIGNING FIELD-SYMBOL(<lfs_precondition>).
DATA(lv_tabix) = sy-tabix.
go_event_instance->log_start(
EXPORTING
iv_action = zcl_instru_event_class=>gc_precheck_condition_start
iv_value = CONV #( lv_tabix )
).
prepare_query(
EXPORTING
is_table = <lfs_precondition>
IMPORTING
ev_from = DATA(lv_from)
ev_order_by = DATA(lv_order_by)
ev_where = DATA(lv_where)
).
execute_db_query(
EXPORTING
is_table = <lfs_precondition>
iv_where = lv_where
iv_order_by = lv_order_by
iv_from = lv_from
iv_precondition_flag = abap_true
IMPORTING
ev_boolean = DATA(lv_result)
).

go_event_instance->log_end(
EXPORTING
iv_action = zcl_instru_event_class=>gc_precheck_condition_end
iv_value = CONV #( lv_tabix )
).

IF lv_result = abap_false.
go_event_instance->log_error(
EXPORTING
iv_action = zcl_instru_event_class=>gc_precheck_condition_failed
).
ev_error = abap_true.
* GET TIME.
ls_elt_errs-entry_date = cl_abap_context_info=>get_system_date( ). "sy-datum.
ls_elt_errs-entry_time = cl_abap_context_info=>get_system_time( ). "sy-uzeit.
ls_elt_errs-command_id = gv_command_id.
ls_elt_errs-idem_key = is_schema-idempotency_key.
ls_elt_errs-row_no = iv_row_no.
lv_cnt = lv_cnt + 1.
ls_elt_errs-err_no = lv_cnt.
ls_elt_errs-status = 'PRECONDITION_FAILURE'.
ls_elt_errs-typemes = 'E'.
ls_elt_errs-numbermes = '062'.
* MESSAGE e062 INTO ls_elt_errs-messagemes WITH lv_tabix.
update_post_failure(
EXPORTING
is_elt_errs = ls_elt_errs " Log of document posted via ELT posting
IMPORTING
ev_subrc = DATA(lv_subrc) " ABAP System Field: Return Code of ABAP Statements
ev_dbcnt = DATA(lv_dbcnt) " ABAP System Field: Edited Database Table Rows
).
IF lv_subrc EQ 0 AND lv_dbcnt >= 1.
COMMIT WORK.
go_event_instance->log_telemetry(
EXPORTING
iv_action = zcl_instru_event_class=>gc_error_table_updated
iv_value = CONV #( lv_dbcnt )
).
ENDIF.
ELSE.
go_event_instance->log_telemetry(
EXPORTING
iv_action = zcl_instru_event_class=>gc_precheck_condition_passed
).
ENDIF.
CLEAR:lv_from,
lv_order_by,
lv_where,
ls_elt_errs,
lv_result,
lv_tabix.
ENDLOOP.

ENDMETHOD.


METHOD constructor.

" Set BEFORE get_erp_config, which reads it. /CLR/ZCL_ELT passed it as
" a parameter - get_erp_config( iv_seq = iv_seq ) - but that method is
" public here and already has callers that pass nothing, so the profile
" travels on the instance instead of through the signature.
gv_seq = iv_seq.

* get_erp_config( ).
get_erp_config(
RECEIVING
ex_erp_config = im_erp_config
).

* get_hostname( ).
get_hostname(
RECEIVING
* ex_erp_config =
ex_hostname = im_hostname
).

* get_auth_token( ).
get_auth_token(
RECEIVING
* ex_erp_config =
ex_auth_token = im_auth_token
).

* get_erp_instance_id( ).
get_erp_instance_id(
RECEIVING
* ex_erp_config =
ex_erp_instance_config = im_erp_instance_config
).


gv_command_id = iv_comm.
CREATE OBJECT go_zip.

go_event_instance = NEW zcl_instru_event_class( iv_guid = iv_guid
iv_event_counter = iv_event_counter ).

gv_url_retry_count = 3.
gv_url_retry_wait_min = 1.
gv_url_retry_wait_sec = gv_url_retry_wait_min * 60.

ENDMETHOD.


METHOD create_files.
*
DATA:lr_data TYPE REF TO data,
lv_timestampl TYPE timestampl.

DATA:lt_description TYPE string_table.

gt_config_tables = it_tables.
LOOP AT it_tables ASSIGNING FIELD-SYMBOL(<lfs_table>).

APPEND INITIAL LINE TO lt_description ASSIGNING FIELD-SYMBOL(<lfs_description>).
<lfs_description> = <lfs_table>-name.
go_event_instance->log_start(
iv_action = zcl_instru_event_class=>gc_start_file_creation
it_description = lt_description
).

prepare_query(
EXPORTING
is_table = <lfs_table>
IMPORTING
et_fcat = DATA(lt_fcat)
ev_from = DATA(lv_from)
ev_order_by = DATA(lv_order_by)
ev_where = DATA(lv_where)
).

execute_db_query(
EXPORTING
is_table = <lfs_table>
it_fcat = lt_fcat " Field Catalog for List Viewer Control
iv_where = lv_where
iv_order_by = lv_order_by
iv_from = lv_from
IMPORTING
et_fieldcat_persist = DATA(lt_fieldcat_persist)
).

store_table_data(
EXPORTING
is_table = <lfs_table>
it_fieldcat_persist = lt_fieldcat_persist
).

CLEAR lt_description.
APPEND INITIAL LINE TO lt_description ASSIGNING <lfs_description>.
<lfs_description> = <lfs_table>-name.
go_event_instance->log_end(
EXPORTING
iv_action = zcl_instru_event_class=>gc_end_file_creation
it_description = lt_description
).
CLEAR:lt_fcat,
lv_from,
lv_order_by,
lv_where,
lt_fieldcat_persist,
lt_description.
ENDLOOP.

IF gt_file_urls IS NOT INITIAL.
gv_zip_file_data = go_zip->save( ).
go_event_instance->log_telemetry(
EXPORTING
iv_action = zcl_instru_event_class=>gc_zip_file_saved
).
GET TIME STAMP FIELD lv_timestampl.
gv_zip_file_name = |{ lv_timestampl }| && |.zip|.
ex_file_name = gv_zip_file_name.

* MESSAGE s059 WITH gv_zip_file_name.
ENDIF.

ENDMETHOD.


METHOD elt_exec_command.

DATA:lv_cnt TYPE i.
GET TIME STAMP FIELD DATA(lv_start_timestamp).

"Continuous job execution till NO_COMMAND or 15min time
DO. """""by ashish instruction we uncommented here 25.04.2025

DATA(lo_elt) = NEW zcl_elt( )."->get_erp_config( ).


lo_elt->go_event_instance->log_measurement(
EXPORTING
iv_action = zcl_instru_event_class=>gc_get_comm_exec
).
"retrial of get command
DO 3 TIMES.
lv_cnt = lv_cnt + 1.
lo_elt->go_event_instance->log_measurement(
EXPORTING
iv_action = zcl_instru_event_class=>gc_get_com_event_cnt
iv_value = CONV #( lv_cnt )
).
lo_elt->get_command(
IMPORTING
ev_status_code = DATA(lv_status_code)
ev_elt_command = DATA(ls_elt_command) " ELT command json structure
ev_reason = DATA(lv_reason) ).
IF lv_status_code EQ 200.
lo_elt->go_event_instance->log_telemetry(
EXPORTING
iv_action = zcl_instru_event_class=>gc_get_com_success
iv_value = CONV #( lv_cnt ) ).
CLEAR lv_cnt.
EXIT.
ELSE.
IF lv_cnt NE 3.
WAIT UP TO 60 SECONDS.
ENDIF.
ENDIF.
ENDDO.

IF lv_status_code NE 200.
* MESSAGE e000 WITH lv_reason.
ENDIF.
DATA imp_status_1 TYPE string.
DATA(lv_event_count) = lo_elt->go_event_instance->gv_event_counter.
DATA(lv_guid) = lo_elt->go_event_instance->get_guid1(
* lv_guiid =
)."( ).

* DATA(lv_guid) = lo_elt->go_event_instance->get_guid( ).
IF ls_elt_command-result-command_id IS NOT INITIAL.

lo_elt->elt_ingestion(
EXPORTING
im_elt_command = ls_elt_command
im_commid = ls_elt_command-result-command_id
im_meta = ls_elt_command-result-metadata
im_guid = lv_guid
im_event_count = lv_event_count
IMPORTING
ex_file_name = DATA(im_file_name)
gc_extraction_empty_metadata = DATA(im_extraction_empty_metadata)
gc_extraction_empty_command_id = DATA(im_extraction_empty_command_id)
ex_send_api_fail_gen_prsi = DATA(im_send_api_fail_gen_prsi)
ex_rcv_api_gen_prsi_ret_code = DATA(im_rcv_api_gen_prsi_ret_code)
ex_rcv_api_gen_prsi_resp = DATA(im_rcv_api_gen_prsi_resp)
ex_rcv_api_gen_prsi_resp_init = DATA(im_rcv_api_gen_prsi_resp_init)
ex_rcv_api_gen_prsi_ret_code_f = DATA(im_rcv_api_gen_prsi_ret_code_f)
ex_abap_response = DATA(im_abap_response)
ex_status_code = DATA(im_status_code)
ex_reason = DATA(im_reason)
ex_pre_sign_url = DATA(im_pre_sign_url)
ex_gen_pre_sign_url = DATA(im_gen_pre_sign_url)
ex_ingestfile_status_code = DATA(im_ingestfile_status_code)
ex_ingestfile_reason = DATA(im_ingestfile_reason)
ex_rcv_api_upload_ret_code_f = DATA(im_rcv_api_upload_ret_code_f)
ex_rcv_api_upload_ret_code = DATA(im_rcv_api_upload_ret_code)
ex_send_api_fail_upload = DATA(im_send_api_fail_upload)
ex_create_url_fail_upload = DATA(im_create_url_fail_upload)
ex_postcomm_status_code = DATA(im_postcomm_status_code)
ex_postcomm_reason = DATA(im_postcomm_reason)
ex_post_comm_url_not_maint = DATA(im_post_comm_url_not_maint)
ex_create_url_fail_post_comm = DATA(im_create_url_fail_post_comm)
ex_send_api_fail_post_comm = DATA(im_send_api_fail_post_comm)
ex_rcv_api_post_com_ret_code_f = DATA(im_rcv_api_post_com_ret_code_f)
).

ex_log_command_id = ls_elt_command-result-command_id.
ex_event_count = lv_event_count.
ex_file_name = im_file_name.

gc_extraction_empty_metadata = im_extraction_empty_metadata.
gc_extraction_empty_command_id = im_extraction_empty_command_id.
ex_send_api_fail_gen_prsi = im_send_api_fail_gen_prsi.
ex_rcv_api_gen_prsi_ret_code = im_rcv_api_gen_prsi_ret_code.
ex_rcv_api_gen_prsi_resp = im_rcv_api_gen_prsi_resp.
ex_rcv_api_gen_prsi_resp_init = im_rcv_api_gen_prsi_resp_init.
ex_rcv_api_gen_prsi_ret_code_f = im_rcv_api_gen_prsi_ret_code_f.
ex_abap_response = im_abap_response.
ex_status_code = im_status_code.
ex_reason = im_reason.
ex_pre_sign_url = im_pre_sign_url.
ex_gen_pre_sign_url = im_gen_pre_sign_url.
ex_ingestfile_status_code = im_ingestfile_status_code.
ex_ingestfile_reason = im_ingestfile_reason.
ex_rcv_api_upload_ret_code_f = im_rcv_api_upload_ret_code_f.
ex_rcv_api_upload_ret_code = im_rcv_api_upload_ret_code.
ex_send_api_fail_upload = im_send_api_fail_upload.
ex_create_url_fail_upload = im_create_url_fail_upload.
ex_postcomm_status_code = im_postcomm_status_code.
ex_postcomm_reason = im_postcomm_reason.
ex_post_comm_url_not_maint = im_post_comm_url_not_maint.
ex_create_url_fail_post_comm = im_create_url_fail_post_comm.
ex_send_api_fail_post_comm = im_send_api_fail_post_comm.
ex_rcv_api_post_com_ret_code_f = im_rcv_api_post_com_ret_code_f.

APPEND VALUE #( "BASE it_logs FOR ls_logs IN it_logs
ex_log_command_id = ls_elt_command-result-command_id
ex_event_count = lv_event_count
ex_file_name = im_file_name
gc_extraction_empty_metadata = im_extraction_empty_metadata
gc_extraction_empty_command_id = im_extraction_empty_command_id
ex_send_api_fail_gen_prsi = im_send_api_fail_gen_prsi
ex_rcv_api_gen_prsi_ret_code = im_rcv_api_gen_prsi_ret_code
ex_rcv_api_gen_prsi_resp = im_rcv_api_gen_prsi_resp
ex_rcv_api_gen_prsi_resp_init = im_rcv_api_gen_prsi_resp_init
ex_rcv_api_gen_prsi_ret_code_f = im_rcv_api_gen_prsi_ret_code_f
ex_abap_response = im_abap_response
ex_status_code = im_status_code
ex_reason = im_reason
ex_pre_sign_url = im_pre_sign_url
ex_gen_pre_sign_url = im_gen_pre_sign_url
ex_ingestfile_status_code = im_ingestfile_status_code
ex_ingestfile_reason = im_ingestfile_reason
ex_rcv_api_upload_ret_code_f = im_rcv_api_upload_ret_code_f
ex_rcv_api_upload_ret_code = im_rcv_api_upload_ret_code
ex_send_api_fail_upload = im_send_api_fail_upload
ex_create_url_fail_upload = im_create_url_fail_upload
ex_postcomm_status_code = im_postcomm_status_code
ex_postcomm_reason = im_postcomm_reason
ex_post_comm_url_not_maint = im_post_comm_url_not_maint
ex_create_url_fail_post_comm = im_create_url_fail_post_comm
ex_send_api_fail_post_comm = im_send_api_fail_post_comm
ex_rcv_api_post_com_ret_code_f = im_rcv_api_post_com_ret_code_f ) TO et_logs." it_logs.

* wa_logs-ex_log_command_id = ls_elt_command-result-command_id.
* wa_logs-ex_event_count = lv_event_count.
* wa_logs-ex_file_name = im_file_name.
* wa_logs-gc_extraction_empty_metadata = im_extraction_empty_metadata.
* wa_logs-gc_extraction_empty_command_id = im_extraction_empty_command_id.
* wa_logs-ex_send_api_fail_gen_prsi = im_send_api_fail_gen_prsi.
* wa_logs-ex_rcv_api_gen_prsi_ret_code = im_rcv_api_gen_prsi_ret_code.
* wa_logs-ex_rcv_api_gen_prsi_resp = im_rcv_api_gen_prsi_resp.
* wa_logs-ex_rcv_api_gen_prsi_resp_init = im_rcv_api_gen_prsi_resp_init.
* wa_logs-ex_rcv_api_gen_prsi_ret_code_f = im_rcv_api_gen_prsi_ret_code_f.
* wa_logs-ex_abap_response = im_abap_response.
* wa_logs-ex_status_code = im_status_code.
* wa_logs-ex_reason = im_reason.
* wa_logs-
* wa_logs-
* wa_logs-
* wa_logs-
* wa_logs-
* wa_logs-
* wa_logs-
* wa_logs-






ELSE.

ex_log_no_command = zcl_instru_event_class=>gc_no_command. "'No Command presenting to execute'.
APPEND VALUE #( "BASE it_logs FOR ls_logs IN it_logs
ex_log_no_command = zcl_instru_event_class=>gc_no_command
ex_log_command_id = ls_elt_command-result-command_id
ex_event_count = lv_event_count
ex_file_name = im_file_name
gc_extraction_empty_metadata = im_extraction_empty_metadata
gc_extraction_empty_command_id = im_extraction_empty_command_id
ex_send_api_fail_gen_prsi = im_send_api_fail_gen_prsi
ex_rcv_api_gen_prsi_ret_code = im_rcv_api_gen_prsi_ret_code
ex_rcv_api_gen_prsi_resp = im_rcv_api_gen_prsi_resp
ex_rcv_api_gen_prsi_resp_init = im_rcv_api_gen_prsi_resp_init
ex_rcv_api_gen_prsi_ret_code_f = im_rcv_api_gen_prsi_ret_code_f
ex_abap_response = im_abap_response
ex_status_code = im_status_code
ex_reason = im_reason
ex_pre_sign_url = im_pre_sign_url
ex_gen_pre_sign_url = im_gen_pre_sign_url
ex_ingestfile_status_code = im_ingestfile_status_code
ex_ingestfile_reason = im_ingestfile_reason
ex_rcv_api_upload_ret_code_f = im_rcv_api_upload_ret_code_f
ex_rcv_api_upload_ret_code = im_rcv_api_upload_ret_code
ex_send_api_fail_upload = im_send_api_fail_upload
ex_create_url_fail_upload = im_create_url_fail_upload
ex_postcomm_status_code = im_postcomm_status_code
ex_postcomm_reason = im_postcomm_reason
ex_post_comm_url_not_maint = im_post_comm_url_not_maint
ex_create_url_fail_post_comm = im_create_url_fail_post_comm
ex_send_api_fail_post_comm = im_send_api_fail_post_comm
ex_rcv_api_post_com_ret_code_f = im_rcv_api_post_com_ret_code_f ) TO et_logs.

ENDIF.


IF ls_elt_command-result-command EQ 'NO_COMMAND'."NO_COMMAND found. Job execution to be stopped.
lo_elt->go_event_instance->log_telemetry(
EXPORTING
iv_action = zcl_instru_event_class=>gc_no_command
).
EXIT.
ENDIF.

GET TIME STAMP FIELD DATA(lv_current_timestamp). """""by ashish instruction we uncommented here 25.04.2025 from line 668 to 678
CALL METHOD cl_abap_tstmp=>subtract
EXPORTING
tstmp1 = lv_current_timestamp
tstmp2 = lv_start_timestamp
RECEIVING
r_secs = DATA(lv_secs).
IF ( lv_secs >= 54000 )."15 minutes time elapsed. Job execution to be stopped.
EXIT.
ENDIF.
ENDDO.

ENDMETHOD.


METHOD elt_ingestion.
DATA:lo_elt TYPE REF TO zcl_elt.
IF im_commid IS NOT INITIAL.
* MESSAGE s042 WITH p_comm.
CREATE OBJECT lo_elt
EXPORTING
iv_guid = im_guid " GUID in 'CHAR' format with upper-/lowercase (!)
iv_event_counter = im_event_count " Event counter MITC Instrumentation
iv_comm = im_commid.
ELSE.
lo_elt->go_event_instance->log_error(
EXPORTING
iv_action = zcl_instru_event_class=>gc_extraction_empty_command_id
).
gc_extraction_empty_command_id = zcl_instru_event_class=>gc_extraction_empty_command_id.
* MESSAGE e043 WITH sy-repid.
ENDIF.
IF im_meta IS INITIAL.
lo_elt->go_event_instance->log_error(
EXPORTING
iv_action = zcl_instru_event_class=>gc_extraction_empty_metadata ).
gc_extraction_empty_metadata = zcl_instru_event_class=>gc_extraction_empty_metadata.
* MESSAGE e044 WITH sy-repid.
ENDIF.
lo_elt->go_event_instance->log_start(
EXPORTING
iv_action = zcl_instru_event_class=>gc_extraction_start
iv_workflow_id = im_commid ).
* lo_elt->trigger_ingestion( is_config = im_meta-erp_config ).

* lo_elt->trigger_ingestion(
* EXPORTING
* is_config = im_meta-erp_config
* IMPORTING
** es_config =
* ex_file_name = DATA(im_file_name)
* ).

lo_elt->trigger_ingestion(
EXPORTING
is_config = im_meta-erp_config
IMPORTING
* es_config =
ex_file_name = DATA(im_file_name)
ex_send_api_fail_gen_prsi = DATA(im_send_api_fail_gen_prsi)
ex_rcv_api_gen_prsi_ret_code = DATA(im_rcv_api_gen_prsi_ret_code)
ex_rcv_api_gen_prsi_resp = DATA(im_rcv_api_gen_prsi_resp)
ex_rcv_api_gen_prsi_resp_init = DATA(im_rcv_api_gen_prsi_resp_init)
ex_rcv_api_gen_prsi_ret_code_f = DATA(im_rcv_api_gen_prsi_ret_code_f)
ex_abap_response = DATA(im_abap_response)
ex_status_code = DATA(im_status_code)
ex_reason = DATA(im_reason)
ex_pre_sign_url = DATA(im_pre_sign_url)
ex_gen_pre_sign_url = DATA(im_gen_pre_sign_url)
ex_ingestfile_status_code = DATA(im_ingestfile_status_code)
ex_ingestfile_reason = DATA(im_ingestfile_reason)
ex_rcv_api_upload_ret_code_f = DATA(im_rcv_api_upload_ret_code_f)
ex_rcv_api_upload_ret_code = DATA(im_rcv_api_upload_ret_code)
ex_send_api_fail_upload = DATA(im_send_api_fail_upload)
ex_create_url_fail_upload = DATA(im_create_url_fail_upload)
ex_postcomm_status_code = DATA(im_postcomm_status_code)
ex_postcomm_reason = DATA(im_postcomm_reason)
ex_post_comm_url_not_maint = DATA(im_post_comm_url_not_maint)
ex_create_url_fail_post_comm = DATA(im_create_url_fail_post_comm)
ex_send_api_fail_post_comm = DATA(im_send_api_fail_post_comm)
ex_rcv_api_post_com_ret_code_f = DATA(im_rcv_api_post_com_ret_code_f)
).

ex_file_name = im_file_name.

lo_elt->go_event_instance->log_end(
EXPORTING
iv_action = zcl_instru_event_class=>gc_extraction_end
iv_workflow_id = im_commid ).
ENDMETHOD.


METHOD execute_db_query.
DATA:ls_schema TYPE zstr_fields.
DATA lv_xstring TYPE xstring.
DATA:v_crlf TYPE string, "CRLF
v_cr TYPE string, "CR
v_lf TYPE string. "LF

v_crlf = cl_abap_char_utilities=>cr_lf.
v_cr = cl_abap_char_utilities=>cr_lf.
v_lf = cl_abap_char_utilities=>newline.

DATA:lr_fname TYPE RANGE OF zde_lvc_fname.
*
TYPES: BEGIN OF ty_metadata,
tabname TYPE c LENGTH 30,
fieldname TYPE sy-langu,
datatype TYPE c LENGTH 4,
inttype TYPE c LENGTH 1,
leng TYPE n LENGTH 4,
decimals TYPE n LENGTH 6,
sign TYPE c LENGTH 1,
outputlen TYPE n LENGTH 6,
scrtext_s TYPE c LENGTH 10,
scrtext_m TYPE c LENGTH 20,
scrtext_l TYPE c LENGTH 40,
END OF ty_metadata.

TYPES: truxs_t_text_data(4096) TYPE c .

DATA:lt_defies2 TYPE STANDARD TABLE OF zstr_dfies,
lt_defies TYPE STANDARD TABLE OF zstr_dfies,
ls_defies1 TYPE zstr_dfies, """Testing
lv_column_syntax TYPE string,
lt_fieldcat_persist TYPE zstr_fcat_tt,
wa_fieldcat TYPE zstr_fcat,
lt_csv TYPE truxs_t_text_data,
ls_head TYPE truxs_t_text_data,
lt_metadata TYPE STANDARD TABLE OF ty_metadata,
lr_data TYPE REF TO data,
lr_data_fae TYPE REF TO data,
lv_where TYPE string,
lv_delete TYPE string.

DATA:lt_description TYPE TABLE OF string.

DATA: lt_fae_table_fcat TYPE cl_abap_structdescr=>component_table,
ls_fae_table_fcat LIKE LINE OF lt_fae_table_fcat.

DATA:lv_date_from TYPE d,
lv_date_to TYPE d,
lv_time_from TYPE t,
lv_time_to TYPE t.
* Fetch tables required for metadata file
FIELD-SYMBOLS: <lt_table> TYPE ANY TABLE,
<lt_table_persist> TYPE ANY TABLE,
<lt_header_table> TYPE ANY TABLE,
<lt_fae_table> TYPE ANY TABLE.


IF is_table-fae IS NOT INITIAL."fae is not initial so global persist table is to be read for getting the FAE table
READ TABLE gt_fae_index ASSIGNING FIELD-SYMBOL(<lfs_fae_index>) WITH KEY name = is_table-fae.
IF sy-subrc EQ 0.
ASSIGN <lfs_fae_index>-table_data->* TO <lt_header_table>.
DATA(lt_fcat_persist) = <lfs_fae_index>-it_fcat.
DATA(lt_fcat_fae) = lt_fcat_persist.
LOOP AT gt_fae_ref_fields ASSIGNING FIELD-SYMBOL(<lfs_fae_ref_field>).
APPEND INITIAL LINE TO lr_fname ASSIGNING FIELD-SYMBOL(<lfs_fname>).
<lfs_fname>-sign = 'I'.
<lfs_fname>-option = 'EQ'.
<lfs_fname>-low = <lfs_fae_ref_field>-field.
ENDLOOP.
DELETE lt_fcat_fae WHERE fieldname NOT IN lr_fname.
CLEAR lr_fname.
*Create Dynamic table Code Start"""""
DATA: comp_tab1 TYPE cl_abap_structdescr=>component_table,
comp_wa1 LIKE LINE OF comp_tab1.

IF lt_fcat_fae IS NOT INITIAL.
LOOP AT lt_fcat_fae INTO DATA(ls_fcat_fae).
CLEAR:comp_wa1.
comp_wa1-name = ls_fcat_fae-fieldname.
comp_wa1-type ?= cl_abap_typedescr=>describe_by_name( ls_fcat_fae-tabname && '-' && ls_fcat_fae-fieldname ).
* comp_wa1-type ?= cl_abap_typedescr=>describe_by_name( is_table-fae && '-' && <lfs_fae_ref_field>-field ).
APPEND comp_wa1 TO comp_tab1.
CLEAR: ls_fcat_fae.
ENDLOOP.
ENDIF.
*Create Dynamic table using component table
IF comp_tab1 IS NOT INITIAL.
struct_type = cl_abap_structdescr=>create( comp_tab1 ).
table_type = cl_abap_tabledescr=>create( p_line_type = struct_type ).
ENDIF.
*Create Dynamic Internal table and work area
CREATE DATA dataref TYPE HANDLE table_type.
ASSIGN dataref->* TO <lt_fae_table>. "Dynamic table

*Create Dynamic table Code END"""""
* ASSIGN lr_data_fae->* TO <lt_fae_table>.
MOVE-CORRESPONDING <lt_header_table> TO <lt_fae_table>.
ENDIF.
ENDIF.

DATA(lt_tabname) = it_fcat.
SORT lt_tabname BY tabname.
DELETE ADJACENT DUPLICATES FROM lt_tabname COMPARING tabname.

LOOP AT lt_tabname ASSIGNING FIELD-SYMBOL(<fs_tabname>).
IF sy-tabix = 1.
ls_schema-name = <fs_tabname>-tabname.
ELSE.
CONCATENATE ls_schema-name '_' <fs_tabname>-tabname INTO ls_schema-name.
ENDIF.

LOOP AT it_fcat INTO DATA(ls_fcat) WHERE tabname = <fs_tabname>-tabname.
APPEND INITIAL LINE TO lt_defies ASSIGNING FIELD-SYMBOL(<lfs_defies>).
DATA(lv_tablename) = ls_fcat-tabname.
<lfs_defies>-tabname = ls_fcat-tabname.
<lfs_defies>-fieldname = ls_fcat-fieldname.
CLEAR: ls_fcat.
ENDLOOP.

ENDLOOP.
UNASSIGN <fs_tabname>.

SORT lt_defies BY tabname fieldname. " Fieldcat for all the tables in the query

" Build the field catalog from the input parameters
CLEAR et_fieldcat_persist.
LOOP AT it_fcat INTO DATA(ls_fieldcat).

IF sy-tabix = 1.
DATA(lv_count) = 1.
lv_column_syntax = |{ ls_fieldcat-coltext }| && |~| && |{ ls_fieldcat-fieldname }|.
ELSE.
lv_count = 0.
DATA(lv_column) = |{ ls_fieldcat-coltext }| && |~| && |{ ls_fieldcat-fieldname }|.
CONCATENATE lv_column_syntax lv_column INTO lv_column_syntax SEPARATED BY ','.
ENDIF.

"Metadata file population
READ TABLE lt_defies ASSIGNING FIELD-SYMBOL(<fs_defies>)
WITH KEY tabname = ls_fieldcat-tabname
fieldname = ls_fieldcat-fieldname BINARY SEARCH.
IF sy-subrc IS INITIAL.
"Dynamic table strucutre
wa_fieldcat-tabname = ls_fieldcat-tabname.
wa_fieldcat-fieldname = ls_fieldcat-fieldname.
wa_fieldcat-datatype = <fs_defies>-datatype.
wa_fieldcat-inttype = <fs_defies>-inttype.
* wa_fieldcat-intlen = <fs_defies>-intlen.
wa_fieldcat-ref_tabname = ls_fieldcat-tabname.
wa_fieldcat-ref_fieldname = ls_fieldcat-fieldname.
wa_fieldcat-reptext = <fs_defies>-fieldname.
wa_fieldcat-scrtext_l = <fs_defies>-fieldname.
"Header lookup for CSV file
IF lv_count EQ 1.
ls_head = <fs_defies>-fieldname.
ELSE.
CONCATENATE ls_head <fs_defies>-fieldname INTO ls_head SEPARATED BY ','.
ENDIF.
APPEND wa_fieldcat TO et_fieldcat.
IF is_table-persist EQ 'X'.
READ TABLE is_table-select ASSIGNING FIELD-SYMBOL(<lfs_select>)
WITH KEY name = ls_fieldcat-fieldname
persist = 'X'.
IF sy-subrc EQ 0.
APPEND wa_fieldcat TO et_fieldcat_persist.
ENDIF.
ENDIF.

APPEND INITIAL LINE TO lt_metadata ASSIGNING FIELD-SYMBOL(<fs_meta>).
IF <fs_meta> IS ASSIGNED.
<fs_meta>-tabname = <fs_defies>-tabname .
<fs_meta>-fieldname = <fs_defies>-fieldname .
<fs_meta>-datatype = <fs_defies>-datatype .
<fs_meta>-inttype = <fs_defies>-inttype .
<fs_meta>-leng = <fs_defies>-leng .
<fs_meta>-decimals = <fs_defies>-decimals .
<fs_meta>-outputlen = <fs_defies>-outputlen .
<fs_meta>-scrtext_s = <fs_defies>-scrtext_s .
<fs_meta>-scrtext_m = <fs_defies>-scrtext_m .
<fs_meta>-scrtext_l = <fs_defies>-scrtext_l .
<fs_meta>-sign = <fs_defies>-sign .
UNASSIGN <fs_meta>.
ENDIF.
ENDIF.
ENDLOOP.

lv_where = iv_where.

CASE iv_precondition_flag.
WHEN abap_true.
CLEAR ev_boolean.
**********************************************************************
* code change start
**********************************************************************
TRY.
" Strip alias from table name before validation
" e.g. 'I_SUPLRINVCCHGDOCAPI01 as cdh' -> 'I_SUPLRINVCCHGDOCAPI01'
DATA(lv_table_name) = iv_from.

FIND FIRST OCCURRENCE OF PCRE '\s+[aA][sS]\s+\w+' IN lv_table_name.
IF sy-subrc = 0.
REPLACE FIRST OCCURRENCE OF PCRE '\s+[aA][sS]\s+\w+'
IN lv_table_name WITH ''.
ENDIF.

CONDENSE lv_table_name.

" Validate stripped table name via type descriptor
DATA(lo_type) = cl_abap_typedescr=>describe_by_name( lv_table_name ).

IF lo_type->kind <> cl_abap_typedescr=>kind_table AND
lo_type->kind <> cl_abap_typedescr=>kind_struct.
RAISE EXCEPTION TYPE cx_abap_not_a_table.
ENDIF.

" Sanitize WHERE clause
DATA(lv_safe_where) = cl_abap_dyn_prg=>escape_quotes_str( lv_where ).

SELECT SINGLE @abap_true
FROM (iv_from)
WHERE (lv_safe_where)
INTO @ev_boolean.

CATCH cx_abap_not_a_table
cx_sy_move_cast_error INTO DATA(lx_error).
" Handle error
ev_boolean = abap_false.
ENDTRY.
* SELECT SINGLE @abap_true
* FROM (iv_from)
* WHERE (lv_where)
* INTO @ev_boolean.

**********************************************************************
* code change ended
**********************************************************************

WHEN abap_false.
TRY.
*Create Dynamic table Code Start"""""
CLEAR: gt_fi_data.
SORT lt_defies BY tabname fieldname. """"Testing
LOOP AT lt_defies INTO DATA(ls_defies).
CLEAR: gs_fi_data.
gs_fi_data-name = ls_defies-fieldname.
IF ls_defies-fieldname IS NOT INITIAL AND ls_fieldcat-tabname IS NOT INITIAL.
gs_fi_data-type ?= cl_abap_typedescr=>describe_by_name( ls_fieldcat-tabname && '-' && ls_defies-fieldname ).
APPEND gs_fi_data TO gt_fi_data.
CLEAR ls_defies.
ENDIF.
ENDLOOP.

*Create Dynamic table using component tab
IF gt_fi_data IS NOT INITIAL.
struct_type = cl_abap_structdescr=>create( gt_fi_data ).
table_type = cl_abap_tabledescr=>create( p_line_type = struct_type ).
ENDIF.
*Create Dynamic Internal table and work area
CREATE DATA dataref TYPE HANDLE table_type.
ASSIGN dataref->* TO <lt_table>. "Dynamic table
*Create Dynamic table Code END"""""

"DB query depending on the clauses
IF is_table-fae IS INITIAL.
IF lv_where IS NOT INITIAL.
IF iv_order_by IS NOT INITIAL.


**********************************************************************
* code change started
**********************************************************************
TRY.
" Strip alias from table name before validation
" e.g. 'I_SUPLRINVCCHGDOCAPI01 as cdh' -> 'I_SUPLRINVCCHGDOCAPI01'
DATA(lv_table_name1) = iv_from.

FIND FIRST OCCURRENCE OF PCRE '\s+[aA][sS]\s+\w+' IN lv_table_name1.
IF sy-subrc = 0.
REPLACE FIRST OCCURRENCE OF PCRE  '\s+[aA][sS]\s+\w+'
IN lv_table_name1 WITH ''.
ENDIF.

CONDENSE lv_table_name1.

" Validate stripped table name via type descriptor
DATA(lo_type1) = cl_abap_typedescr=>describe_by_name( lv_table_name1 ).

IF lo_type1->kind <> cl_abap_typedescr=>kind_table AND
lo_type1->kind <> cl_abap_typedescr=>kind_struct.
RAISE EXCEPTION TYPE cx_abap_not_a_table.
ENDIF.

" Sanitize column names
DATA(lv_safe_columns) = cl_abap_dyn_prg=>escape_quotes_str( lv_column_syntax ).

" Sanitize WHERE clause
DATA(lv_safe_where1) = cl_abap_dyn_prg=>escape_quotes_str( lv_where ).

" Sanitize ORDER BY
DATA(lv_safe_order) = cl_abap_dyn_prg=>escape_quotes_str( iv_order_by ).

" Additional ORDER BY check: only allow field names, commas, spaces, underscores
FIND FIRST OCCURRENCE OF PCRE '[^a-zA-Z0-9_, ]' IN lv_safe_order. "#EC NOTEXT
IF sy-subrc = 0.
RAISE EXCEPTION TYPE cx_abap_not_a_table.
ENDIF.

SELECT (lv_safe_columns)
FROM (iv_from)
WHERE (lv_safe_where1)
ORDER BY (lv_safe_order)
INTO CORRESPONDING FIELDS OF TABLE @<lt_table>.

CATCH cx_abap_not_a_table
cx_sy_move_cast_error INTO DATA(lx_error1).  "#EC NO_HANDLER
" Handle error
ENDTRY.




* SELECT (lv_column_syntax)
* FROM (iv_from)
* WHERE (lv_where) ORDER BY (iv_order_by)
* INTO CORRESPONDING FIELDS OF TABLE @<lt_table>.

**********************************************************************
* code change ended
**********************************************************************

ELSEIF iv_order_by IS INITIAL.


**********************************************************************
* code change started
**********************************************************************

TRY.
" Strip alias from table name before validation
" e.g. 'I_SUPLRINVCCHGDOCAPI01 as cdh' -> 'I_SUPLRINVCCHGDOCAPI01'
DATA(lv_table_name2) = iv_from.

FIND FIRST OCCURRENCE OF PCRE '\s+[aA][sS]\s+\w+' IN lv_table_name2.
IF sy-subrc = 0.
REPLACE FIRST OCCURRENCE OF PCRE '\s+[aA][sS]\s+\w+'
IN lv_table_name2 WITH ''.
ENDIF.

CONDENSE lv_table_name2.

" Validate stripped table name via type descriptor
DATA(lo_type2) = cl_abap_typedescr=>describe_by_name( lv_table_name2 ).

IF lo_type2->kind <> cl_abap_typedescr=>kind_table AND
lo_type2->kind <> cl_abap_typedescr=>kind_struct.
RAISE EXCEPTION TYPE cx_abap_not_a_table.
ENDIF.

" Sanitize column names
DATA(lv_safe_columns2) = cl_abap_dyn_prg=>escape_quotes_str( lv_column_syntax ).

" Sanitize WHERE clause
DATA(lv_safe_where2) = cl_abap_dyn_prg=>escape_quotes_str( lv_where ).

" Use original iv_from (with alias) in SELECT
SELECT (lv_safe_columns2)
FROM (iv_from)
WHERE (lv_safe_where2)
INTO CORRESPONDING FIELDS OF TABLE @<lt_table>.

CATCH cx_abap_not_a_table
cx_sy_move_cast_error INTO DATA(lx_error2). "#EC NO_HANDLER
" Handle error
ENDTRY.


* SELECT (lv_column_syntax)
* FROM (iv_from)
* WHERE (lv_where)
* INTO CORRESPONDING FIELDS OF TABLE @<lt_table>.

**********************************************************************
* code change ended
**********************************************************************

ENDIF.
ELSE.
SELECT (lv_column_syntax)
FROM (iv_from)
INTO CORRESPONDING FIELDS OF TABLE @<lt_table>.
ENDIF.
ELSE.
IF <lt_fae_table> IS ASSIGNED.
SORT <lt_fae_table>.
DELETE ADJACENT DUPLICATES FROM <lt_fae_table> COMPARING ALL FIELDS.
LOOP AT lt_fcat_fae ASSIGNING FIELD-SYMBOL(<lfs_fcat_fae>).
IF sy-tabix = 1.
CONCATENATE lv_delete <lfs_fcat_fae>-fieldname 'IS INITIAL' INTO lv_delete SEPARATED BY space.
ELSE.
CONCATENATE lv_delete 'AND' <lfs_fcat_fae>-fieldname 'IS INITIAL' INTO lv_delete SEPARATED BY space.
ENDIF.
ENDLOOP.
DELETE <lt_fae_table> WHERE (lv_delete).
IF <lt_fae_table> IS NOT INITIAL.

*Create Dynamic table Code Start"""""
SORT gt_fi_data BY name.

IF gt_fi_data IS NOT INITIAL.
LOOP AT gt_fi_data INTO DATA(ls_fae_ref_fields).
ls_fae_table_fcat-name = ls_fae_ref_fields-name.
IF ls_fieldcat-tabname IS NOT INITIAL AND ls_fae_ref_fields-name IS NOT INITIAL.
ls_fae_table_fcat-type ?= cl_abap_typedescr=>describe_by_name(
ls_fieldcat-tabname && '-' && ls_fae_ref_fields-name ).
ENDIF.
APPEND ls_fae_table_fcat TO lt_fae_table_fcat.
CLEAR ls_fae_ref_fields.
ENDLOOP.
ENDIF.

*Create Dynamic table using component tab
IF lt_fae_table_fcat IS NOT INITIAL.
struct_type = cl_abap_structdescr=>create( lt_fae_table_fcat ).
table_type = cl_abap_tabledescr=>create( p_line_type = struct_type ).
ENDIF.
*Create Dynamic Internal table and work area
CREATE DATA dataref TYPE HANDLE table_type.
ASSIGN dataref->* TO <lt_table>. "Dynamic table
*Create Dynamic table Code END"""""
**********************************************************************
* code change started
**********************************************************************

TRY.
" Strip alias from table name before validation
" e.g. 'I_SUPLRINVCCHGDOCAPI01 as cdh' -> 'I_SUPLRINVCCHGDOCAPI01'
DATA(lv_table_name3) = iv_from.

FIND FIRST OCCURRENCE OF PCRE '\s+[aA][sS]\s+\w+' IN lv_table_name3.
IF sy-subrc = 0.
REPLACE FIRST OCCURRENCE OF PCRE '\s+[aA][sS]\s+\w+'
IN lv_table_name3 WITH ''.
ENDIF.

CONDENSE lv_table_name3.

" Validate stripped table name via type descriptor
DATA(lo_type3) = cl_abap_typedescr=>describe_by_name( lv_table_name3 ).

IF lo_type3->kind <> cl_abap_typedescr=>kind_table AND
lo_type3->kind <> cl_abap_typedescr=>kind_struct.
RAISE EXCEPTION TYPE cx_abap_not_a_table.
ENDIF.

" Sanitize column names
DATA(lv_safe_columns3) = cl_abap_dyn_prg=>escape_quotes_str( lv_column_syntax ).

" Sanitize WHERE clause
DATA(lv_safe_where3) = cl_abap_dyn_prg=>escape_quotes_str( lv_where ).

" Use original iv_from (with alias) in SELECT
SELECT (lv_safe_columns3)
FROM (iv_from)
FOR ALL ENTRIES IN @<lt_fae_table>
WHERE (lv_safe_where3)
INTO CORRESPONDING FIELDS OF TABLE @<lt_table>.

CATCH cx_abap_not_a_table
cx_sy_move_cast_error INTO DATA(lx_error3). "#EC NO_HANDLER
" Handle error
ENDTRY.


* SELECT (lv_column_syntax)
* FROM (iv_from)
* FOR ALL ENTRIES IN @<lt_fae_table>
* WHERE (lv_where)
* INTO CORRESPONDING FIELDS OF TABLE @<lt_table>.
**********************************************************************
* code change ended
**********************************************************************
ENDIF.
ENDIF.
ENDIF.

IF <lt_table> IS ASSIGNED.
DATA(lv_cnt) = lines( <lt_table> ). " DESCRIBE TABLE <lt_table> LINES DATA(lv_cnt).
ENDIF.

go_event_instance->log_measurement(
EXPORTING
iv_action = zcl_instru_event_class=>gc_total_entry
iv_value = CONV #( lv_cnt )
).

CLEAR gt_table.
IF <lt_table> IS ASSIGNED.
* IF <lt_table> IS NOT INITIAL. """"""""""""""""""commented as Ashish informed 25.04.2025
gt_table = REF #( <lt_table> ).
* ENDIF. """"""""""""""""""commented as Ashish informed 25.04.2025
ENDIF.

" The TRY opened at the top of this WHEN branch had no handler at all, so the
" block never activated. Everything inside it is dynamic - describe_by_name,
" a ?= cast to a structure descriptor, cl_abap_tabledescr=>create and a fully
" dynamic SELECT - and any of it can fail on a column the caller named that
" does not exist. cx_root rather than a list: the point here is that one bad
" field name must not take the whole pull down.
CATCH cx_root INTO DATA(lx_dynamic).
CLEAR gt_table.
IF go_event_instance IS BOUND.
go_event_instance->log_error(
EXPORTING
it_description = VALUE string_table( ( lx_dynamic->get_text( ) ) ) ).
ENDIF.
ENDTRY.
WHEN OTHERS.
ENDCASE.
CLEAR:et_fieldcat,
lv_where.

ENDMETHOD.


METHOD generate_pre_sign.

DATA:ls_abap_response TYPE zstr_elt_presigned_url,
lv_resp_string TYPE string.

DATA:lt_description TYPE string_table,
lt_response TYPE string_table.

READ TABLE gt_erp_config ASSIGNING FIELD-SYMBOL(<lfs_api_url>)
WITH KEY labeltype = gc_api_type_presign.
IF sy-subrc NE 0 OR <lfs_api_url>-low IS INITIAL.
go_event_instance->log_error(
EXPORTING
iv_action = zcl_instru_event_class=>gc_gen_prsi_url_not_maint
).
ex_pre_sign_url = zcl_instru_event_class=>gc_gen_prsi_url_not_maint.

* MESSAGE e009.
ELSE.
DATA(lv_url) = <lfs_api_url>-low.
ENDIF.
CLEAR ls_abap_response.

REPLACE ALL OCCURRENCES OF '&FILE' IN lv_url WITH gv_zip_file_name.
REPLACE ALL OCCURRENCES OF '&COMM' IN lv_url WITH gv_command_id.

IF gv_hostname IS NOT INITIAL.
DATA(lv_conv) = CONV string( gv_hostname && lv_url ) .

TRY.
lr_http_client = cl_web_http_client_manager=>create_by_http_destination(
i_destination = cl_http_destination_provider=>create_by_url( lv_conv ) ).
CATCH cx_web_http_client_error cx_http_dest_provider_error. "#EC NO_HANDLER
"handle exception
ENDTRY.
ENDIF.

IF sy-subrc <> 0.
CLEAR lt_description.
IF sy-msgid IS NOT INITIAL.
MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
WITH sy-msgv1 sy-msgv1 sy-msgv1 sy-msgv1 INTO DATA(lv_url_err).
ENDIF.
APPEND INITIAL LINE TO lt_description ASSIGNING FIELD-SYMBOL(<lfs_description>).
<lfs_description> = CONV #( lv_url_err ).
APPEND INITIAL LINE TO lt_description ASSIGNING <lfs_description>.
<lfs_description> = CONV #( |{ lv_url }| && |{ gv_zip_file_name }| ).
go_event_instance->log_error(
EXPORTING
iv_action = zcl_instru_event_class=>gc_create_url_fail_gen_prsi
it_description = lt_description
).
ex_gen_pre_sign_url = zcl_instru_event_class=>gc_create_url_fail_gen_prsi.
* MESSAGE e065.
ELSE.
IF lr_http_client IS BOUND.
* DATA(lr_rest_client) = NEW cl_rest_http_client( io_http_client = lr_http_client ).
*
* lr_http_client->request->set_version( if_http_request=>co_protocol_version_1_0 ).

DATA(lo_request) = lr_http_client->get_http_request( ).
lo_request->set_header_fields( VALUE #(
( name = '~request_method' value = 'GET' )
( name = gc_auth_token value = CONV #( gv_auth_token ) )
( name = gc_erp_instance_id value = CONV #( gv_erp_instance_id ) )
( name = gc_content_type value = CONV #( gc_content_type ) )
( name = gc_file_cont_type value = CONV #( gc_appl_zip ) )
) ).

TRY.
DATA(lv_response) = lr_http_client->execute(
i_method = if_web_http_client=>get ).
CATCH cx_web_http_client_error. "#EC NO_HANDLER
ENDTRY.
DATA(lv_json_response) = lv_response->get_text( ).
DATA(lv_https_ststus) = lv_response->get_status( ).
ev_status_code = lv_https_ststus-code.

IF lv_https_ststus-code <> 200.
ev_status_code = lv_https_ststus-code.
* MESSAGE e010 WITH lv_err_status_code lv_err_reason INTO ev_reason.

IF sy-msgid IS NOT INITIAL.
MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
WITH sy-msgv1 sy-msgv1 sy-msgv1 sy-msgv1 INTO DATA(lv_msg_txt).
ENDIF.
CLEAR lt_description.
APPEND INITIAL LINE TO lt_description ASSIGNING <lfs_description>.
<lfs_description> = CONV #( lv_msg_txt ).
APPEND INITIAL LINE TO lt_description ASSIGNING <lfs_description>.
<lfs_description> = CONV #( lv_https_ststus-code ).
APPEND INITIAL LINE TO lt_description ASSIGNING <lfs_description>.
<lfs_description> = CONV #( lv_https_ststus-reason ).

go_event_instance->log_error(
EXPORTING
iv_action = zcl_instru_event_class=>gc_send_api_fail_gen_prsi
it_description = lt_description
).
gc_send_api_fail_gen_prsi = zcl_instru_event_class=>gc_send_api_fail_gen_prsi.
ex_send_api_fail_gen_prsi = zcl_instru_event_class=>gc_send_api_fail_gen_prsi.
ELSE.
IF lv_https_ststus-code EQ 200.
go_event_instance->log_telemetry(
EXPORTING
iv_action = zcl_instru_event_class=>gc_rcv_api_gen_prsi_ret_code
iv_value = CONV #( lv_https_ststus-code ) " numeric value being m
).
gc_rcv_api_gen_prsi_ret_code = zcl_instru_event_class=>gc_rcv_api_gen_prsi_ret_code.
ex_rcv_api_gen_prsi_ret_code = zcl_instru_event_class=>gc_rcv_api_gen_prsi_ret_code.
IF lv_json_response IS NOT INITIAL.
/ui2/cl_json=>deserialize( EXPORTING json = lv_json_response
pretty_name = abap_true
CHANGING data = ls_abap_response ).
es_abap_response = ls_abap_response.
CLEAR:lt_response.
* DATA(lo_parser) = NEW /ui5/cl_json_parser( ).
APPEND INITIAL LINE TO lt_response ASSIGNING FIELD-SYMBOL(<lfs_response>).
* TRY.
* CALL METHOD lo_parser->parse( json = lv_json_response ).
* CATCH cx_root INTO DATA(lx_parse).
* ENDTRY.
* <lfs_response> = lo_parser->m_json.
* <lfs_response> = ls_abap_response .
CLEAR lv_resp_string.
APPEND INITIAL LINE TO lt_response ASSIGNING <lfs_response>.
/ui2/cl_json=>deserialize( EXPORTING json = lv_json_response
pretty_name = abap_true
CHANGING data = lv_resp_string ).
<lfs_response> = lv_json_response."lv_resp_string.

go_event_instance->log_telemetry(
EXPORTING
iv_action = zcl_instru_event_class=>gc_rcv_api_gen_prsi_resp
it_response = lt_response
).
gc_rcv_api_gen_prsi_resp = zcl_instru_event_class=>gc_rcv_api_gen_prsi_resp.
ex_rcv_api_gen_prsi_resp = zcl_instru_event_class=>gc_rcv_api_gen_prsi_resp.
ELSE.
go_event_instance->log_error(
EXPORTING
iv_action = zcl_instru_event_class=>gc_rcv_api_gen_prsi_resp_init
).
gc_rcv_api_gen_prsi_resp_init = zcl_instru_event_class=>gc_rcv_api_gen_prsi_resp_init.
ex_rcv_api_gen_prsi_resp_init = zcl_instru_event_class=>gc_rcv_api_gen_prsi_resp_init.
* MESSAGE e012 WITH lv_status.
ENDIF.
ELSE.
go_event_instance->log_error(
EXPORTING
iv_action = zcl_instru_event_class=>gc_rcv_api_gen_prsi_ret_code_f
iv_value = CONV #( lv_https_ststus-code ) " numeric value being m
).
gc_rcv_api_gen_prsi_ret_code_f = zcl_instru_event_class=>gc_rcv_api_gen_prsi_ret_code_f.
ex_rcv_api_gen_prsi_ret_code_f = zcl_instru_event_class=>gc_rcv_api_gen_prsi_ret_code_f.
* MESSAGE e024 WITH lv_status lv_reason INTO ev_reason.
ENDIF.
ENDIF.
ENDIF.
ENDIF.
ENDMETHOD.


METHOD get_auth_token.

READ TABLE gt_erp_config
ASSIGNING FIELD-SYMBOL(<lfs_erp_config>)
WITH KEY labeltype = gc_auth.
IF sy-subrc NE 0 OR <lfs_erp_config>-low IS INITIAL.
* ex_erp_config = 'Auth Token Not-Maintained'.
ex_auth_token = 'Auth token not maintained'. "#EC NOTEXT
* MESSAGE e007.
ELSE.
gv_auth_token = <lfs_erp_config>-low.
ENDIF.

ENDMETHOD.


METHOD get_command.

DATA:lt_description TYPE string_table,
lt_response TYPE string_table.
DATA:lv_resp_string TYPE string,
ls_elt_command TYPE zstr_elt_command.

READ TABLE gt_erp_config ASSIGNING FIELD-SYMBOL(<lfs_api_url>)
WITH KEY labeltype = gc_api_type_get_command.
IF sy-subrc EQ 0.
DATA(lv_url) = <lfs_api_url>-low.
ELSE.
go_event_instance->log_error(
EXPORTING
iv_action = zcl_instru_event_class=>gc_get_comm_url_not_maint
).
gc_get_comm_url_not_maint = zcl_instru_event_class=>gc_get_comm_url_not_maint.
* MESSAGE e006.
ENDIF.

IF gv_hostname IS NOT INITIAL AND lv_url IS NOT INITIAL.
DATA(lv_conv) = CONV string( gv_hostname && lv_url ) .

TRY.
lr_http_client = cl_web_http_client_manager=>create_by_http_destination(
i_destination = cl_http_destination_provider=>create_by_url( lv_conv ) ).
CATCH cx_web_http_client_error cx_http_dest_provider_error. "#EC NO_HANDLER
"handle exception
ENDTRY.
ENDIF.

IF sy-subrc <> 0.
CLEAR lt_description.
IF sy-msgid IS NOT INITIAL.
MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
WITH sy-msgv1 sy-msgv1 sy-msgv1 sy-msgv1 INTO DATA(lv_url_err).
ENDIF.
APPEND INITIAL LINE TO lt_description ASSIGNING FIELD-SYMBOL(<lfs_description>).
<lfs_description> = CONV #( lv_url_err ).
APPEND INITIAL LINE TO lt_description ASSIGNING <lfs_description>.
<lfs_description> = CONV #( lv_url ).
go_event_instance->log_error(
EXPORTING
iv_action = zcl_instru_event_class=>gc_create_url_fail_get_com
it_description = lt_description
).
gc_create_url_fail_get_com = zcl_instru_event_class=>gc_create_url_fail_get_com.
* MESSAGE e001.
ELSE.
IF lr_http_client IS BOUND.

* DATA lr_rest_client TYPE REF TO cl_web
*
*
** lr_http_client->request->set_version( if_http_request=>co_protocol_version_1_0 ).
**
DATA(lo_request) = lr_http_client->get_http_request( ).
lo_request->set_header_fields( VALUE #(
( name = '~request_method' value = 'GET' )
( name = gc_auth_token value = CONV #( gv_auth_token ) )
( name = gc_erp_instance_id value = CONV #( gv_erp_instance_id ) )
) ).

IF sy-subrc <> 0.
TRY.
DATA(lv_response) = lr_http_client->execute(
i_method = if_web_http_client=>get ).
CATCH cx_web_http_client_error. "#EC NO_HANDLER
ENDTRY.
DATA(lv_https_ststus) = lv_response->get_status( ).

ev_status_code = lv_https_ststus-code.

IF sy-msgid IS NOT INITIAL.
MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
WITH sy-msgv1 sy-msgv1 sy-msgv1 sy-msgv1 INTO DATA(lv_msg_txt).
ENDIF.


CLEAR lt_description.
APPEND INITIAL LINE TO lt_description ASSIGNING <lfs_description>.
<lfs_description> = CONV #( lv_msg_txt ).
APPEND INITIAL LINE TO lt_description ASSIGNING <lfs_description>.
<lfs_description> = CONV #( lv_https_ststus-code ).
APPEND INITIAL LINE TO lt_description ASSIGNING <lfs_description>.
<lfs_description> = CONV #( lv_https_ststus-reason ).

go_event_instance->log_error(
EXPORTING
iv_action = zcl_instru_event_class=>gc_send_api_fail_get_com
it_description = lt_description
).
gc_send_api_fail_get_com = zcl_instru_event_class=>gc_send_api_fail_get_com.
* MESSAGE e003.
ELSE.
* DATA(lo_parser) = NEW /ui5/cl_json_parser( ).

TRY.
lv_response = lr_http_client->execute(
i_method = if_web_http_client=>get ).
CATCH cx_web_http_client_error. "#EC NO_HANDLER
ENDTRY.
lv_https_ststus = lv_response->get_status( ).

ev_status_code = lv_https_ststus-code.

IF lv_https_ststus-code = 200.
go_event_instance->log_telemetry(
EXPORTING
iv_action = zcl_instru_event_class=>gc_rcv_api_get_com_ret_code
iv_value = CONV #( ev_status_code ) " numeric value being m
).

DATA(lv_json_response) = lv_response->get_text( ).
IF lv_json_response IS NOT INITIAL.
/ui2/cl_json=>deserialize( EXPORTING json = lv_json_response
pretty_name = abap_true
CHANGING data = ls_elt_command ).

ev_elt_command = ls_elt_command.

CLEAR:lt_response.
APPEND INITIAL LINE TO lt_response ASSIGNING FIELD-SYMBOL(<lfs_response>).

* TRY.
* CALL METHOD lo_parser->parse( json = lv_json_response ).
* CATCH cx_root INTO DATA(lx_parse).
* ENDTRY.
* <lfs_response> = lo_parser->m_json.
* CLEAR lv_resp_string.

APPEND INITIAL LINE TO lt_response ASSIGNING <lfs_response>.
/ui2/cl_json=>deserialize( EXPORTING json = lv_json_response
pretty_name = abap_true
CHANGING data = lv_resp_string ).
<lfs_response> = lv_json_response. "lv_json_response

go_event_instance->log_telemetry(
EXPORTING
iv_action = zcl_instru_event_class=>gc_rcv_api_get_com_resp
it_response = lt_response
).

ELSE.
go_event_instance->log_error(
EXPORTING
iv_action = zcl_instru_event_class=>gc_rcv_api_get_com_resp_init
).
gc_rcv_api_get_com_resp_init = zcl_instru_event_class=>gc_rcv_api_get_com_resp_init.
* MESSAGE e005 WITH lv_status lv_reason.
ENDIF.

ELSE.
go_event_instance->log_error(
EXPORTING
iv_action = zcl_instru_event_class=>gc_rcv_api_get_com_ret_code
iv_value = CONV #( ev_status_code ) " numeric value being m
).
gc_rcv_api_get_com_ret_code = zcl_instru_event_class=>gc_rcv_api_get_com_ret_code.
* MESSAGE e023 WITH lv_status lv_reason INTO ev_reason.
ENDIF.
* ENDIF.
ENDIF.
ELSE.
* MESSAGE e002.
ENDIF.
ENDIF.
ENDMETHOD.


METHOD get_context_data.

DATA:ls_query_schema TYPE zstr_dynamic_query.
LOOP AT is_schema-context ASSIGNING FIELD-SYMBOL(<lfs_context>).
DATA(lv_tabix) = sy-tabix.
go_event_instance->log_start(
EXPORTING
iv_action = zcl_instru_event_class=>gc_get_context_data_start
iv_value = CONV #( lv_tabix )
).
APPEND INITIAL LINE TO gt_context_data ASSIGNING FIELD-SYMBOL(<lfs_context_data>).
<lfs_context_data>-name = <lfs_context>-name.
IF <lfs_context>-query IS NOT INITIAL.
prepare_query(
EXPORTING
is_table = <lfs_context>-query
IMPORTING
et_fcat = DATA(lt_fcat)
ev_from = DATA(lv_from)
ev_order_by = DATA(lv_order_by)
ev_where = DATA(lv_where)
).
execute_db_query(
EXPORTING
is_table = <lfs_context>-query
it_fcat = lt_fcat " Field Catalog for List Viewer Control
iv_where = lv_where
iv_order_by = lv_order_by
iv_from = lv_from
IMPORTING
et_fieldcat = DATA(lt_fieldcat)
).
<lfs_context_data>-table_data = gt_table.
<lfs_context_data>-it_fcat = lt_fieldcat.
ENDIF.
CLEAR:lt_fcat,
lv_from,
lv_order_by,
lv_where,
lt_fieldcat,
ls_query_schema.
go_event_instance->log_end(
EXPORTING
iv_action = zcl_instru_event_class=>gc_get_context_data_end
iv_value = CONV #( lv_tabix )
).
ENDLOOP.


ENDMETHOD.


METHOD get_erp_config.

" HANA:
"   SELECT label_type, low FROM /clr/zt_elt_cnfg
"     WHERE sys_id = @sy-sysid AND sequence = @iv_seq.
"
" SEQUENCE is a key field of ZTELT_CONFIG here too, so reading without it
" returns every profile maintained for the system and the READ TABLE ...
" WITH KEY label_type that follows picks whichever row came back first.
" With one profile that is invisible; with two it silently reads the
" wrong endpoint, token or project. Section 77.
"
" The filter is applied only when a sequence was supplied. The strictly
" faithful form filters always - blank means sequence 0 - but the rows in
" F3Y were maintained while this read ignored the column, so an
" unconditional filter could blank a working configuration on the first
" run. Once the maintained sequences are confirmed, drop the IF and keep
" the filtered SELECT.
IF gv_seq IS INITIAL.
SELECT labeltype,
low
FROM ztelt_config
WHERE sysid = @sy-sysid
INTO CORRESPONDING FIELDS OF TABLE @gt_erp_config.
ELSE.
SELECT labeltype,
low
FROM ztelt_config
WHERE sysid = @sy-sysid
AND sequence = @gv_seq
INTO CORRESPONDING FIELDS OF TABLE @gt_erp_config.
ENDIF.
IF sy-subrc NE 0.
ex_erp_config = 'Config Not-Maintained'. "#EC NOTEXT
* MESSAGE e040.
ENDIF.
ENDMETHOD.


METHOD get_erp_instance_id.
READ TABLE gt_erp_config
ASSIGNING FIELD-SYMBOL(<lfs_erp_config>)
WITH KEY labeltype = gc_erp_id.
IF sy-subrc NE 0 OR <lfs_erp_config>-low IS INITIAL.
ex_erp_instance_config = 'UID not maintained'. "#EC NOTEXT
* MESSAGE e041.
ELSE.
gv_erp_instance_id = <lfs_erp_config>-low.
ENDIF.

ENDMETHOD.


METHOD get_exec_program.

IF is_elt_command-result-command EQ 'DATA_EXTRACTION' OR
is_elt_command-result-command EQ 'DATA_QUALITY'.
* rv_program_name = 'ZCL_ELT'."'/CLR/ZELT_INGESTION'.
* WRITE is_elt_command-result-command_id.
ELSEIF is_elt_command-result-command EQ 'DATA_POSTING'.
* rv_program_name = '/CLR/ZELT_POSTING'.
* WRITE is_elt_command-result-command_id.
ELSE.
* MESSAGE s039 WITH is_elt_command-result-command is_elt_command-result-job_type.
* WRITE is_elt_command-result-command.
* WRITE is_elt_command-result-job_type.
* LEAVE LIST-PROCESSING.
ENDIF.

ENDMETHOD.


METHOD get_hostname.
READ TABLE gt_erp_config
ASSIGNING FIELD-SYMBOL(<lfs_erp_config>)
WITH KEY labeltype = gc_hostname.
IF sy-subrc NE 0 OR <lfs_erp_config>-low IS INITIAL.
* ex_erp_config = 'Config Not-Maintained'.
ex_hostname = 'Hostname not maintained'. "#EC NOTEXT
* MESSAGE e045.
ELSE.
gv_hostname = <lfs_erp_config>-low.
ENDIF.

ENDMETHOD.


METHOD get_posting_file.

DATA:lt_description TYPE string_table,
lt_response TYPE string_table.
DATA:lv_resp_string TYPE string,
ls_erp_posting TYPE zstr_elt_posting.

IF gv_hostname IS NOT INITIAL.
DATA(lv_conv) = is_file_url-url.
TRY.
lr_http_client = cl_web_http_client_manager=>create_by_http_destination(
i_destination = cl_http_destination_provider=>create_by_url( lv_conv ) ).
CATCH cx_web_http_client_error cx_http_dest_provider_error. "#EC NO_HANDLER
"handle exception
ENDTRY.
ENDIF.
IF sy-subrc <> 0.
CLEAR lt_description.
IF sy-msgid IS NOT INITIAL.
MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
WITH sy-msgv1 sy-msgv1 sy-msgv1 sy-msgv1 INTO DATA(lv_url_err).
ENDIF.
APPEND INITIAL LINE TO lt_description ASSIGNING FIELD-SYMBOL(<lfs_description>).
<lfs_description> = CONV #( lv_url_err ).
APPEND INITIAL LINE TO lt_description ASSIGNING <lfs_description>.
<lfs_description> = CONV #( is_file_url-url ).
go_event_instance->log_error(
EXPORTING
iv_action = zcl_instru_event_class=>gc_create_url_fail_get_file
it_description = lt_description
).
* MESSAGE e001.
ELSE.
IF lr_http_client IS BOUND.
* DATA(lr_rest_client) = NEW cl_rest_http_client( io_http_client = lr_http_client ).
* lr_http_client->request->set_version( if_http_request=>co_protocol_version_1_0 ).
DATA(lo_request) = lr_http_client->get_http_request( ).
lo_request->set_header_fields( VALUE #(
( name = '~request_method' value = 'GET' )
( name = gc_auth_token value = CONV #( gv_auth_token ) )
( name = gc_content_type value = gc_appl_json )
) ).
TRY.
DATA(lv_response) = lr_http_client->execute(
i_method = if_web_http_client=>get ).
CATCH cx_web_http_client_error. "#EC NO_HANDLER
ENDTRY.
DATA(lv_https_ststus) = lv_response->get_status( ).
DATA(lv_status) = lv_https_ststus-code.
IF sy-subrc <> 0.
IF sy-msgid IS NOT INITIAL.
MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
WITH sy-msgv1 sy-msgv1 sy-msgv1 sy-msgv1 INTO DATA(lv_msg_txt).
ENDIF.

CLEAR lt_description.
APPEND INITIAL LINE TO lt_description ASSIGNING <lfs_description>.
<lfs_description> = CONV #( lv_msg_txt ).
APPEND INITIAL LINE TO lt_description ASSIGNING <lfs_description>.
<lfs_description> = CONV #( lv_https_ststus-code ).
APPEND INITIAL LINE TO lt_description ASSIGNING <lfs_description>.
<lfs_description> = CONV #( lv_https_ststus-reason ).

go_event_instance->log_error(
EXPORTING
iv_action = zcl_instru_event_class=>gc_send_api_fail_get_file
it_description = lt_description
).
* MESSAGE e071 WITH lv_err_status_code lv_err_reason.
ELSE.

IF lv_https_ststus-code = 200.
go_event_instance->log_telemetry(
EXPORTING
iv_action = zcl_instru_event_class=>gc_rcv_api_get_file_ret_code
iv_value = CONV #( lv_status ) " numeric value being m
).
DATA(lv_json_response) = lv_response->get_text( ).
IF lv_json_response IS NOT INITIAL.
es_abap_response = lv_json_response.
ELSE.
go_event_instance->log_error(
EXPORTING
iv_action = zcl_instru_event_class=>gc_rcv_api_get_com_resp_init
).
* MESSAGE e073 WITH lv_status lv_reason.
ENDIF.
ELSE.
go_event_instance->log_error(
EXPORTING
iv_action = zcl_instru_event_class=>gc_rcv_api_get_file_ret_code
iv_value = CONV #( lv_status ) " numeric value being m
).
* MESSAGE e074 WITH lv_status lv_reason.
ENDIF.
ENDIF.
* ENDIF.
ELSE.
* MESSAGE e075.
ENDIF.
ENDIF.

ENDMETHOD.


METHOD ingest_files.

DATA:lt_description TYPE string_table,
lt_response TYPE string_table,
lv_resp_string TYPE string.

IF gv_hostname IS NOT INITIAL.
DATA(lv_conv) = iv_presigned_url.

TRY.
lr_http_client = cl_web_http_client_manager=>create_by_http_destination(
i_destination = cl_http_destination_provider=>create_by_url( lv_conv ) ).
CATCH cx_web_http_client_error cx_http_dest_provider_error. "#EC NO_HANDLER
"handle exception
ENDTRY.
ENDIF.

IF sy-subrc <> 0.
CLEAR lt_description.
IF sy-msgid IS NOT INITIAL.
MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
WITH sy-msgv1 sy-msgv1 sy-msgv1 sy-msgv1 INTO DATA(lv_url_err).
ENDIF.
APPEND INITIAL LINE TO lt_description ASSIGNING FIELD-SYMBOL(<lfs_description>).
<lfs_description> = CONV #( lv_url_err ).
APPEND INITIAL LINE TO lt_description ASSIGNING <lfs_description>.
<lfs_description> = CONV #( iv_presigned_url ).
go_event_instance->log_error(
EXPORTING
iv_action = zcl_instru_event_class=>gc_create_url_fail_upload
it_description = lt_description
).
gc_create_url_fail_upload = zcl_instru_event_class=>gc_create_url_fail_upload.
ex_create_url_fail_upload = zcl_instru_event_class=>gc_create_url_fail_upload.
* MESSAGE e014.
ELSE.
IF lr_http_client IS BOUND.
DATA(lo_request) = lr_http_client->get_http_request( ).

* DATA(lr_rest_client) = NEW cl_rest_http_client( io_http_client = lr_http_client ).
*
* lr_http_client->request->set_version( if_http_request=>co_protocol_version_1_0 ).


lo_request->set_header_fields( VALUE #(
( name = '~request_method' value = 'PUT' )
( name = gc_content_type value = CONV #( gc_appl_zip ) )
* ( name = gc_presign value = CONV #( iv_presigned_url ) )
) ).


lo_request->append_binary(
data = gv_zip_file_data
* offset = 0
length = xstrlen( gv_zip_file_data ) ).

* lo_request->append_text(
* data = gv_zip_file_data
* length = strlen( gv_zip_file_data ) ).

TRY.
DATA(lv_response) = lr_http_client->execute(
i_method = if_web_http_client=>put ).
CATCH cx_web_http_client_error. "#EC NO_HANDLER
ENDTRY.
DATA(lv_https_ststus) = lv_response->get_status( ).
DATA(lv_json_response) = lv_response->get_text( ).
IF lv_https_ststus-code <> 200.
ev_status_code = lv_https_ststus-code.
* MESSAGE e015 WITH lv_err_status_code lv_err_reason INTO ev_reason.

IF sy-msgid IS NOT INITIAL.
MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
WITH sy-msgv1 sy-msgv1 sy-msgv1 sy-msgv1 INTO DATA(lv_msg_txt).
ENDIF.
CLEAR lt_description.
APPEND INITIAL LINE TO lt_description ASSIGNING <lfs_description>.
<lfs_description> = CONV #( lv_msg_txt ).
APPEND INITIAL LINE TO lt_description ASSIGNING <lfs_description>.
<lfs_description> = CONV #( lv_https_ststus-code ).
APPEND INITIAL LINE TO lt_description ASSIGNING <lfs_description>.
<lfs_description> = CONV #( lv_https_ststus-reason ).

go_event_instance->log_error(
EXPORTING
iv_action = zcl_instru_event_class=>gc_send_api_fail_upload
it_description = lt_description
).
gc_send_api_fail_upload = zcl_instru_event_class=>gc_send_api_fail_upload.
ex_send_api_fail_upload = zcl_instru_event_class=>gc_send_api_fail_upload.
ELSE.
IF lv_https_ststus-code = 200.
ev_status_code = lv_https_ststus-code.
go_event_instance->log_telemetry(
EXPORTING
iv_action = zcl_instru_event_class=>gc_rcv_api_upload_ret_code
iv_value = CONV #( lv_https_ststus-code )
).
gc_rcv_api_upload_ret_code = zcl_instru_event_class=>gc_rcv_api_upload_ret_code.
ex_rcv_api_upload_ret_code = zcl_instru_event_class=>gc_rcv_api_upload_ret_code.
ELSE.
lv_json_response = lv_response->get_text( ).
IF lv_json_response IS NOT INITIAL.
CLEAR lt_response.
APPEND INITIAL LINE TO lt_response ASSIGNING FIELD-SYMBOL(<lfs_response>).
<lfs_response> = lv_json_response.
ENDIF.
go_event_instance->log_error(
EXPORTING
iv_action = zcl_instru_event_class=>gc_rcv_api_upload_ret_code_f
it_response = lt_response
iv_value = CONV #( lv_https_ststus-code )
).
gc_rcv_api_upload_ret_code_f = zcl_instru_event_class=>gc_rcv_api_upload_ret_code_f.
ex_rcv_api_upload_ret_code_f = zcl_instru_event_class=>gc_rcv_api_upload_ret_code_f.

* MESSAGE e025 WITH lv_status lv_reason INTO ev_reason.
ENDIF.
ENDIF.
ENDIF.
* MESSAGE e017.
ENDIF.

ENDMETHOD.


METHOD insert_table.

FIELD-SYMBOLS: <lt_table_data> TYPE INDEX TABLE,
<lfs_row> TYPE any.
DATA: ls_row TYPE REF TO data.
DATA: lt_table TYPE REF TO data.
LOOP AT is_schema-insert_table ASSIGNING FIELD-SYMBOL(<lfs_insert_table>).
CREATE DATA ls_row TYPE (<lfs_insert_table>-name).
CREATE DATA lt_table TYPE TABLE OF (<lfs_insert_table>-name).
ASSIGN lt_table->* TO <lt_table_data>.
LOOP AT <lfs_insert_table>-data ASSIGNING FIELD-SYMBOL(<lfs_data>).
LOOP AT <lfs_data> ASSIGNING FIELD-SYMBOL(<lfs_data_row>).
ASSIGN ls_row->* TO <lfs_row>.
ASSIGN COMPONENT <lfs_data_row>-name OF STRUCTURE <lfs_row> TO FIELD-SYMBOL(<lfs_value>).
IF <lfs_data_row>-type EQ 'VALUE'.
<lfs_value> = <lfs_data_row>-value.
ELSEIF <lfs_data_row>-type EQ 'REFERENCE'.
READ TABLE gt_context_data ASSIGNING FIELD-SYMBOL(<lfs_context_data>)
WITH KEY name = <lfs_data_row>-reference-row.
IF sy-subrc EQ 0.
ASSIGN <lfs_context_data>-table_data->* TO <lt_table_data>.
IF <lt_table_data> IS ASSIGNED.
READ TABLE <lt_table_data> ASSIGNING FIELD-SYMBOL(<lfs_row1>)
INDEX 1.
IF sy-subrc EQ 0.
ASSIGN COMPONENT <lfs_data_row>-reference-column OF STRUCTURE <lfs_row1> TO FIELD-SYMBOL(<lfs_query_value>).
<lfs_value> = <lfs_query_value>.
ENDIF.
ENDIF.
ENDIF.
ELSEIF <lfs_data_row>-type EQ 'SYSTEM'.
* ASSIGN COMPONENT <lfs_data_row>-value OF STRUCTURE sy TO FIELD-SYMBOL(<lfs_system_value>).
* IF sy-subrc EQ 0.
* <lfs_value> = <lfs_system_value>.
* ENDIF.
ENDIF.
ENDLOOP.
APPEND <lfs_row> TO <lt_table_data>.
ENDLOOP.
TRY.
DATA(lv_safe_table) = cl_abap_dyn_prg=>check_table_name_str(
val = <lfs_insert_table>-name
packages = VALUE #( )
).

MODIFY (lv_safe_table) FROM TABLE @<lt_table_data>.
" MODIFY (<lfs_insert_table>-name) FROM TABLE @<lt_table_data>.
CATCH cx_abap_not_a_table cx_abap_not_in_package INTO DATA(lx_error). "#EC NO_HANDLER
" Handle invalid table name
ENDTRY.
ENDLOOP.

ENDMETHOD.


METHOD ping_test.

DATA:ls_abap_response TYPE zstr_elt_ping_response,
lv_resp_string TYPE string.

READ TABLE gt_erp_config ASSIGNING FIELD-SYMBOL(<lfs_api_url>)
WITH KEY labeltype = gc_ping.

IF sy-subrc NE 0 OR <lfs_api_url>-low IS INITIAL.
ex_ping_url = 'Ping test url not maintained'. "#EC NOTEXT
* MESSAGE e051.
ELSE.
DATA(lv_url) = <lfs_api_url>-low.
ENDIF.


IF gv_hostname IS NOT INITIAL AND lv_url IS NOT INITIAL.
DATA(lv_conv) = CONV string( gv_hostname && lv_url ) .

TRY.
lr_http_client = cl_web_http_client_manager=>create_by_http_destination(
i_destination = cl_http_destination_provider=>create_by_url( lv_conv ) ).
CATCH cx_web_http_client_error cx_http_dest_provider_error. "#EC NO_HANDLER
"handle exception
ENDTRY.

DATA(lo_request) = lr_http_client->get_http_request( ).
lo_request->set_header_fields( VALUE #(
( name = '~request_method' value = 'GET' )
( name = gc_auth_token value = CONV #( gv_auth_token ) )
( name = gc_erp_instance_id value = CONV #( gv_erp_instance_id ) )
) ).


TRY.
DATA(lv_response) = lr_http_client->execute(
i_method = if_web_http_client=>get ).
CATCH cx_web_http_client_error. "#EC NO_HANDLER
ENDTRY.

DATA(lv_https_ststus) = lv_response->get_status( ).
IF lv_https_ststus-code EQ 200.
DATA(lv_json_response) = lv_response->get_text( ).
IF lv_json_response IS NOT INITIAL.
/ui2/cl_json=>deserialize( EXPORTING json = lv_json_response
pretty_name = abap_true
CHANGING data = ls_abap_response ).
* MESSAGE i000 WITH ls_abap_response-message.
ELSE.
ex_ping_empty_response = 'Empty response (Ping test)'. "#EC NOTEXT
* MESSAGE e058 WITH lv_status.
ENDIF.
ELSE.
ex_ping_fail = 'Ping test failed'. "#EC NOTEXT
* MESSAGE e055 WITH lv_status lv_reason.
ENDIF.

ENDIF.
ENDMETHOD.


METHOD post_command.

DATA:ls_payload TYPE zstr_elt_post_command_pl.

ls_payload-command_id = gv_command_id.

ls_payload-metadata = is_metadata.

READ TABLE ls_payload-metadata-s3_details ASSIGNING FIELD-SYMBOL(<lfs_s3_urls>) INDEX 1.
IF sy-subrc EQ 0.
DATA(lv_presigned_url) = <lfs_s3_urls>-url.
SPLIT lv_presigned_url AT '?' INTO <lfs_s3_urls>-url DATA(lv_other).
ENDIF.

DATA:ls_abap_response TYPE zstr_elt_presigned_url,
lv_resp_string TYPE string.

DATA:lt_description TYPE string_table,
lt_response TYPE string_table.

READ TABLE gt_erp_config ASSIGNING FIELD-SYMBOL(<lfs_api_url>)
WITH KEY labeltype = gc_post_command.
IF sy-subrc NE 0 OR <lfs_api_url>-low IS INITIAL.
go_event_instance->log_error(
EXPORTING
iv_action = zcl_instru_event_class=>gc_post_comm_url_not_maint
).
gc_post_comm_url_not_maint = zcl_instru_event_class=>gc_post_comm_url_not_maint.
ex_post_comm_url_not_maint = zcl_instru_event_class=>gc_post_comm_url_not_maint.
* MESSAGE e046.
ELSE.
DATA(lv_url) = <lfs_api_url>-low.
ENDIF.
CLEAR ls_abap_response.

IF gv_hostname IS NOT INITIAL.
DATA(lv_conv) = CONV string( gv_hostname && lv_url ) .
TRY.
lr_http_client = cl_web_http_client_manager=>create_by_http_destination(
i_destination = cl_http_destination_provider=>create_by_url( lv_conv ) ).
CATCH cx_web_http_client_error cx_http_dest_provider_error. "#EC NO_HANDLER
"handle exception
ENDTRY.
ENDIF.
IF sy-subrc <> 0.
CLEAR lt_description.
IF sy-msgid IS NOT INITIAL.
MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
WITH sy-msgv1 sy-msgv1 sy-msgv1 sy-msgv1 INTO DATA(lv_url_err).
ENDIF.
APPEND INITIAL LINE TO lt_description ASSIGNING FIELD-SYMBOL(<lfs_description>).
<lfs_description> = CONV #( lv_url_err ).
APPEND INITIAL LINE TO lt_description ASSIGNING <lfs_description>.
<lfs_description> = CONV #( |{ lv_url }| && |{ gv_zip_file_name }| ).
go_event_instance->log_error(
EXPORTING
iv_action = zcl_instru_event_class=>gc_create_url_fail_post_comm
it_description = lt_description
).
gc_create_url_fail_post_comm = zcl_instru_event_class=>gc_create_url_fail_post_comm.
ex_create_url_fail_post_comm = zcl_instru_event_class=>gc_create_url_fail_post_comm.
* MESSAGE e047.
ELSE.
IF lr_http_client IS BOUND.

DATA(lo_request) = lr_http_client->get_http_request( ).
lo_request->set_header_fields( VALUE #(
( name = '~request_method' value = 'POST' )
( name = gc_auth_token value = CONV #( gv_auth_token ) )
( name = gc_erp_instance_id value = CONV #( gv_erp_instance_id ) )
( name = gc_content_type value = CONV #( gc_appl_json ) )
) ).

IF ls_payload IS NOT INITIAL.
/ui2/cl_json=>serialize(
EXPORTING
data = ls_payload " Data to serialize
compress = abap_true " Skip empty elements
pretty_name = abap_true
RECEIVING
r_json = DATA(lv_data_string)" JSON string
).

IF lv_data_string IS NOT INITIAL.
lo_request->append_text( data = lv_data_string ).
ENDIF.
ENDIF.
TRY.
DATA(lv_response) = lr_http_client->execute(
i_method = if_web_http_client=>post ).
CATCH cx_web_http_client_error. "#EC NO_HANDLER
ENDTRY.
DATA(lv_json_response) = lv_response->get_text( ).
DATA(lv_https_ststus) = lv_response->get_status( ).

* MESSAGE e048 WITH lv_err_status_code lv_err_reason INTO ev_reason.
IF sy-subrc <> 0.
IF sy-msgid IS NOT INITIAL.
MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
WITH sy-msgv1 sy-msgv1 sy-msgv1 sy-msgv1 INTO DATA(lv_msg_txt).
ENDIF.
CLEAR lt_description.
APPEND INITIAL LINE TO lt_description ASSIGNING <lfs_description>.
<lfs_description> = CONV #( lv_msg_txt ).
APPEND INITIAL LINE TO lt_description ASSIGNING <lfs_description>.
<lfs_description> = CONV #( lv_https_ststus-code ).
APPEND INITIAL LINE TO lt_description ASSIGNING <lfs_description>.
<lfs_description> = CONV #( lv_https_ststus-reason ).

go_event_instance->log_error(
EXPORTING
iv_action = zcl_instru_event_class=>gc_send_api_fail_post_comm
it_description = lt_description
).
gc_send_api_fail_post_comm = zcl_instru_event_class=>gc_send_api_fail_post_comm.
ex_send_api_fail_post_comm = zcl_instru_event_class=>gc_send_api_fail_post_comm.
ELSE.
DATA:lv_status TYPE i.
lv_status = lv_https_ststus-code.
ev_status_code = lv_status.
IF lv_status EQ 200.
go_event_instance->log_telemetry(
EXPORTING
iv_action = zcl_instru_event_class=>gc_rcv_api_post_com_ret_code
iv_value = CONV #( lv_status ) " numeric value being m
).
ELSE.
go_event_instance->log_error(
EXPORTING
iv_action = zcl_instru_event_class=>gc_rcv_api_post_com_ret_code_f
iv_value = CONV #( lv_status ) " numeric value being m
).
gc_rcv_api_post_com_ret_code_f = zcl_instru_event_class=>gc_rcv_api_post_com_ret_code_f.
ex_rcv_api_post_com_ret_code_f = zcl_instru_event_class=>gc_rcv_api_post_com_ret_code_f.
* MESSAGE e027 WITH lv_status lv_reason INTO ev_reason.
ENDIF.
ENDIF.
* ENDIF.
ELSE.
* MESSAGE e050.
ENDIF.
ENDIF.
ENDMETHOD.


METHOD prepare_query.

DATA:lv_no_rows TYPE i,
lv_cr_date_field TYPE c LENGTH 30,
lv_md_date_field TYPE c LENGTH 30,
lv_ps_date_field TYPE c LENGTH 30,
lv_cr_time_field TYPE c LENGTH 30,
lv_left_table TYPE string,
lv_right_table TYPE string,
lv_from_table TYPE string,
lv_from_f_table TYPE string,
ls_fcat TYPE zstr_fcat,
lv_field TYPE string,
lv_tab_name TYPE string,
lv_value TYPE string.

"Prepare the field catalogue table using fieldnames and alias in SELECT
LOOP AT is_table-select ASSIGNING FIELD-SYMBOL(<lfs_select>).
CONCATENATE <lfs_select>-alias <lfs_select>-name INTO lv_field SEPARATED BY '~'.
APPEND INITIAL LINE TO et_fcat ASSIGNING FIELD-SYMBOL(<lfs_fcat>).
<lfs_fcat>-fieldname = <lfs_select>-name.
<lfs_fcat>-coltext = <lfs_select>-alias.
ENDLOOP.

CLEAR:lv_left_table,
lv_right_table,
lv_from_table.

"Fill the table name for the fields using the tabname in FROM
LOOP AT et_fcat ASSIGNING <lfs_fcat>
WHERE coltext = is_table-from_table-alias.
<lfs_fcat>-tabname = is_table-from_table-name.
ENDLOOP.

lv_left_table = |{ is_table-from_table-name }| && | as | && |{ is_table-from_table-alias }|.

LOOP AT is_table-from_table-join ASSIGNING FIELD-SYMBOL(<lfs_join>).
DATA(lv_tabix) = sy-tabix.
CONCATENATE <lfs_join>-name 'as' <lfs_join>-alias INTO lv_right_table SEPARATED BY space.
"Fill the table name for the fields using the tabname in JOIN
LOOP AT et_fcat ASSIGNING <lfs_fcat>
WHERE coltext = <lfs_join>-alias.
<lfs_fcat>-tabname = <lfs_join>-name.
ENDLOOP.

IF <lfs_join>-on IS NOT INITIAL.
DATA(lv_count) = lines( <lfs_join>-on )." DESCRIBE TABLE <lfs_join>-on LINES DATA(lv_count).
LOOP AT <lfs_join>-on ASSIGNING FIELD-SYMBOL(<lfs_on>).
CONCATENATE <lfs_on>-left-alias '~' <lfs_on>-left-name INTO DATA(lv_left_on).
CONCATENATE <lfs_on>-right-alias '~' <lfs_on>-right-name INTO DATA(lv_right_on).
CONCATENATE lv_left_on '=' lv_right_on INTO DATA(lv_from_table_field) SEPARATED BY space.
IF lv_from_table IS INITIAL.
lv_from_table = lv_from_table_field.
ELSE.
CONCATENATE lv_from_table_field 'AND' lv_from_table INTO lv_from_table SEPARATED BY space.
ENDIF.
CLEAR:lv_from_table_field,
lv_left_on,
lv_right_on.
ENDLOOP.
CLEAR lv_count.
IF lv_tabix = 1.
CONCATENATE lv_left_table 'INNER JOIN' lv_right_table 'ON' lv_from_table INTO lv_from_f_table SEPARATED BY space.
ELSE.
CONCATENATE lv_from_f_table 'INNER JOIN' lv_right_table 'ON' lv_from_table INTO lv_from_f_table SEPARATED BY space.
ENDIF.

ENDIF.
CLEAR lv_from_table.

ENDLOOP.

IF lv_from_f_table IS NOT INITIAL.
ev_from = lv_from_f_table.
ELSE.
ev_from = lv_left_table.
ENDIF.

ev_where = prepare_where_clause( is_schema = is_table ).

DATA(lv_cn) = lines( is_table-order_by ). "DESCRIBE TABLE is_table-order_by LINES DATA(lv_cn).
LOOP AT is_table-order_by ASSIGNING FIELD-SYMBOL(<lfs_order>).
IF ev_order_by IS INITIAL.
ev_order_by = |{ <lfs_order>-column-alias }~{ <lfs_order>-column-name } { <lfs_order>-order }|.
ELSE.
ev_order_by = | { ev_order_by },{ <lfs_order>-column-alias }~{ <lfs_order>-column-name } { <lfs_order>-order }|.
ENDIF.
ENDLOOP.

CLEAR:lv_from_table,
lv_left_table,
lv_right_table,
lv_no_rows.

ENDMETHOD.


METHOD prepare_single_cond_clause.

DATA:lv_value TYPE string,
lv_exp TYPE string.
DATA(lv_lines) = lines( is_expr-value ). "DESCRIBE TABLE is_expr-value LINES DATA(lv_lines).
IF is_expr-value[] IS NOT INITIAL.
LOOP AT is_expr-value INTO DATA(ls_value).
IF is_expr-operator EQ 'IN' OR
is_expr-operator EQ 'NOT IN' .
IF lv_value IS INITIAL.
lv_value = |'{ ls_value }'|.
ELSE.
lv_value = |{ lv_value },'{ ls_value }'|.
ENDIF.
ELSE.
lv_value = ls_value.
ENDIF.
ENDLOOP.

ELSEIF is_expr-reference_column-name IS NOT INITIAL.
lv_exp = |@<lt_fae_table>-{ is_expr-reference_column-name }|.
IF is_expr-reference_column-offset IS NOT INITIAL.
lv_exp = |{ lv_exp }+{ is_expr-reference_column-offset }| .
ENDIF.
APPEND INITIAL LINE TO gt_fae_ref_fields ASSIGNING FIELD-SYMBOL(<lfs_fae_ref_field>).
<lfs_fae_ref_field>-field = is_expr-reference_column-name.
ENDIF.
IF is_expr-column-name IS NOT INITIAL.
IF lv_value IS NOT INITIAL.
IF ( is_expr-operator NE 'IN' AND is_expr-operator NE 'NOT IN' ).
rv_expr_clause = |{ is_expr-column-alias }~{ is_expr-column-name } { is_expr-operator } '{ lv_value }'|.
ELSEIF ( is_expr-operator EQ 'IN' OR is_expr-operator EQ 'NOT IN' ).
rv_expr_clause = |{ is_expr-column-alias }~{ is_expr-column-name } { is_expr-operator } ({ lv_value })|.
ENDIF.
ELSEIF lv_exp IS NOT INITIAL.
rv_expr_clause = |{ is_expr-column-alias }~{ is_expr-column-name } { is_expr-operator } { lv_exp }|.
ENDIF.
ENDIF.

ENDMETHOD.


METHOD prepare_where_clause.

DATA:lv_string_clause5 TYPE string,
lv_string_clause4 TYPE string,
lv_string_clause3 TYPE string,
lv_string_clause2 TYPE string,
lv_string_clause1 TYPE string,
lv_string_clause TYPE string.

READ TABLE is_schema-where INTO DATA(ls_where) INDEX 1.

CLEAR: gt_fae_ref_fields.
IF ls_where IS NOT INITIAL.
CLEAR lv_string_clause1.
LOOP AT ls_where-list_of_expr INTO DATA(ls_list_of_expr1).
CLEAR lv_string_clause2.
LOOP AT ls_list_of_expr1-list_of_expr INTO DATA(ls_list_of_expr2).
CLEAR lv_string_clause3.
LOOP AT ls_list_of_expr2-list_of_expr INTO DATA(ls_list_of_expr3).
CLEAR lv_string_clause4.
LOOP AT ls_list_of_expr3-list_of_expr INTO DATA(ls_list_of_expr4).
CLEAR lv_string_clause5.
LOOP AT ls_list_of_expr4-list_of_expr INTO DATA(ls_list_of_expr5).
DATA(lv_expr_clause) = prepare_single_cond_clause( is_expr = ls_list_of_expr5-expr ).
IF lv_string_clause5 IS INITIAL.
lv_string_clause5 = |{ lv_expr_clause }|.
ELSE.
lv_string_clause5 = |{ lv_string_clause5 } { ls_list_of_expr4-boolean_operator } { lv_expr_clause }|.
ENDIF.
""
CLEAR lv_expr_clause.
ENDLOOP.
IF lv_string_clause5 IS NOT INITIAL AND ls_list_of_expr4-boolean_operator IS NOT INITIAL.
lv_string_clause5 = | ( { lv_string_clause5 } ) |.
ENDIF.
lv_expr_clause = prepare_single_cond_clause( is_expr = ls_list_of_expr4-expr ).
IF lv_string_clause4 IS INITIAL.
IF lv_string_clause5 IS INITIAL.
lv_string_clause4 = |{ lv_expr_clause }|.
ELSE.
IF lv_expr_clause IS INITIAL.
lv_string_clause4 = |{ lv_string_clause5 }|.
ELSE.
lv_string_clause4 = |{ lv_string_clause5 } { ls_list_of_expr3-boolean_operator } { lv_expr_clause }|.
ENDIF.
ENDIF.
ELSE.
IF lv_string_clause5 IS INITIAL.
IF lv_expr_clause IS INITIAL.
lv_string_clause4 = |{ lv_string_clause4 }|.
ELSE.
lv_string_clause4 = |{ lv_string_clause4 } { ls_list_of_expr3-boolean_operator } { lv_expr_clause }|.
ENDIF.
ELSE.
IF lv_expr_clause IS INITIAL.
lv_string_clause4 = |{ lv_string_clause4 } { ls_list_of_expr3-boolean_operator } { lv_string_clause5 }|.
ELSE.
lv_string_clause4 = |{ lv_string_clause4 } { ls_list_of_expr3-boolean_operator } { lv_string_clause5 } { ls_list_of_expr3-boolean_operator } { lv_expr_clause }|.
ENDIF.
ENDIF.
ENDIF.
CLEAR lv_expr_clause.
ENDLOOP.
IF lv_string_clause4 IS NOT INITIAL AND ls_list_of_expr3-boolean_operator IS NOT INITIAL.
lv_string_clause4 = | ( { lv_string_clause4 } ) |.
ENDIF.
lv_expr_clause = prepare_single_cond_clause( is_expr = ls_list_of_expr3-expr ).
IF lv_string_clause3 IS INITIAL.
IF lv_string_clause4 IS INITIAL.
lv_string_clause3 = |{ lv_expr_clause }|.
ELSE.
IF lv_expr_clause IS INITIAL.
lv_string_clause3 = |{ lv_string_clause4 }|.
ELSE.
lv_string_clause3 = |{ lv_string_clause4 } { ls_list_of_expr2-boolean_operator } { lv_expr_clause }|.
ENDIF.
ENDIF.
ELSE.
IF lv_string_clause4 IS INITIAL.
IF lv_expr_clause IS INITIAL.
lv_string_clause3 = |{ lv_string_clause3 }|.
ELSE.
lv_string_clause3 = |{ lv_string_clause3 } { ls_list_of_expr2-boolean_operator } { lv_expr_clause }|.
ENDIF.
ELSE.
IF lv_expr_clause IS INITIAL..
lv_string_clause3 = |{ lv_string_clause3 } { ls_list_of_expr2-boolean_operator } { lv_string_clause4 }|.
ELSE.
lv_string_clause3 = |{ lv_string_clause3 } { ls_list_of_expr2-boolean_operator } { lv_string_clause4 } { ls_list_of_expr2-boolean_operator } { lv_expr_clause }|.
ENDIF.
ENDIF.
ENDIF.
CLEAR lv_expr_clause.
ENDLOOP.
IF lv_string_clause3 IS NOT INITIAL AND ls_list_of_expr2-boolean_operator IS NOT INITIAL.
lv_string_clause3 = | ( { lv_string_clause3 } ) |.
ENDIF.
lv_expr_clause = prepare_single_cond_clause( is_expr = ls_list_of_expr2-expr ).
IF lv_string_clause2 IS INITIAL.
IF lv_string_clause3 IS INITIAL.
lv_string_clause2 = |{ lv_expr_clause }|.
ELSE.
IF lv_expr_clause IS INITIAL.
lv_string_clause2 = |{ lv_string_clause3 }|.
ELSE.
lv_string_clause2 = |{ lv_string_clause3 } { ls_list_of_expr1-boolean_operator } { lv_expr_clause }|.
ENDIF.
ENDIF.
ELSE.
IF lv_string_clause3 IS INITIAL.
IF lv_expr_clause IS INITIAL.
lv_string_clause2 = |{ lv_string_clause2 }|.
ELSE.
lv_string_clause2 = |{ lv_string_clause2 } { ls_list_of_expr1-boolean_operator } { lv_expr_clause }|.
ENDIF.
ELSE.
IF lv_expr_clause IS INITIAL.
lv_string_clause2 = |{ lv_string_clause2 } { ls_list_of_expr1-boolean_operator } { lv_string_clause3 }|.
ELSE.
lv_string_clause2 = |{ lv_string_clause2 } { ls_list_of_expr1-boolean_operator } { lv_string_clause3 } { ls_list_of_expr1-boolean_operator } { lv_expr_clause }|.
ENDIF.
ENDIF.
ENDIF.
CLEAR lv_expr_clause.
ENDLOOP.
IF lv_string_clause2 IS NOT INITIAL AND ls_list_of_expr1-boolean_operator IS NOT INITIAL.
lv_string_clause2 = | ( { lv_string_clause2 } ) |.
ENDIF.
lv_expr_clause = prepare_single_cond_clause( is_expr = ls_list_of_expr1-expr ).
IF lv_string_clause1 IS INITIAL.
IF lv_string_clause2 IS INITIAL.
lv_string_clause1 = |{ lv_expr_clause }|.
ELSE.
IF lv_expr_clause IS INITIAL.
lv_string_clause1 = |{ lv_string_clause2 }|.
ELSE.
lv_string_clause1 = |{ lv_string_clause2 } { ls_where-boolean_operator } { lv_expr_clause }|.
ENDIF.
ENDIF.
ELSE.
IF lv_string_clause2 IS INITIAL.
IF lv_expr_clause IS INITIAL.
lv_string_clause1 = |{ lv_string_clause1 }|.
ELSE.
lv_string_clause1 = |{ lv_string_clause1 } { ls_where-boolean_operator } { lv_expr_clause }|.
ENDIF.
ELSE.
IF lv_expr_clause IS INITIAL.
lv_string_clause1 = |{ lv_string_clause1 } { ls_where-boolean_operator } { lv_string_clause2 }|.
ELSE.
lv_string_clause1 = |{ lv_string_clause1 } { ls_where-boolean_operator } { lv_string_clause2 } { ls_where-boolean_operator } { lv_expr_clause }|.
ENDIF.
ENDIF.
ENDIF.
CLEAR lv_expr_clause.
ENDLOOP.
IF lv_string_clause1 IS NOT INITIAL AND ls_where-boolean_operator IS NOT INITIAL.
lv_string_clause1 = | ( { lv_string_clause1 } ) |.
ENDIF.
lv_expr_clause = prepare_single_cond_clause( is_expr = ls_where-expr ).
IF lv_string_clause IS INITIAL.
IF lv_string_clause1 IS INITIAL.
lv_string_clause = |{ lv_expr_clause }|.
ELSE.
IF lv_expr_clause IS INITIAL.
lv_string_clause = |{ lv_string_clause1 }|.
ELSE.
lv_string_clause = |{ lv_string_clause1 } { ls_where-boolean_operator } { lv_expr_clause }|.
ENDIF.
ENDIF.
ELSE.
IF lv_string_clause1 IS INITIAL.
IF lv_expr_clause IS INITIAL.
lv_string_clause = |{ lv_string_clause }|.
ELSE.
lv_string_clause = |{ lv_string_clause } { ls_where-boolean_operator } { lv_expr_clause }|.
ENDIF.
ELSE.
IF lv_expr_clause IS INITIAL.
lv_string_clause = |{ lv_string_clause } { ls_where-boolean_operator } { lv_string_clause1 }|.
ELSE.
lv_string_clause = |{ lv_string_clause } { ls_where-boolean_operator } { lv_string_clause1 } { ls_where-boolean_operator } { lv_expr_clause }|.
ENDIF.
ENDIF.
ENDIF.
CLEAR lv_expr_clause.
rv_where_clause = lv_string_clause.
ENDIF.

ENDMETHOD.


METHOD store_table_data.

DATA:lv_xstring TYPE xstring,
lv_filename TYPE string.

DATA:v_crlf TYPE string, "CRLF
v_cr TYPE string, "CR
v_lf TYPE string. "LF

DATA:lt_description TYPE TABLE OF string,
lt_fieldcat_persist TYPE zstr_fcat_tt,
lr_data TYPE REF TO data.

FIELD-SYMBOLS:<lt_table_persist> TYPE ANY TABLE,
<lt_table> TYPE ANY TABLE,
<lt_table_append> TYPE ANY TABLE.


v_crlf = cl_abap_char_utilities=>cr_lf.
v_cr = cl_abap_char_utilities=>cr_lf.
v_lf = cl_abap_char_utilities=>newline.

"Table is to be persisted. The global table GT_FAE_INDEX will be filled with table name, field catalogue and table data
IF is_table-persist IS NOT INITIAL AND
gt_table IS NOT INITIAL AND
is_table-union IS INITIAL.
"insert PERSIST data
APPEND INITIAL LINE TO gt_fae_index ASSIGNING FIELD-SYMBOL(<lfs_fae_index>).
<lfs_fae_index>-name = is_table-name.

****""""Create dynamic internal table code
DATA: struct_type TYPE REF TO cl_abap_structdescr, "Structure
table_type TYPE REF TO cl_abap_tabledescr, "Table type
dataref TYPE REF TO data.

DATA: lt_fieldcat TYPE cl_abap_structdescr=>component_table,
comp_wa LIKE LINE OF lt_fieldcat.

LOOP AT gt_fi_data INTO gs_fi_data.
comp_wa-name = gs_fi_data-name.
comp_wa-type ?= cl_abap_typedescr=>describe_by_name( is_table-from_table-name && '-' && gs_fi_data-name ).
APPEND comp_wa TO lt_fieldcat.
CLEAR gs_fi_data.
ENDLOOP.

*Create Dynamic table using component table
IF lt_fieldcat IS NOT INITIAL.
struct_type = cl_abap_structdescr=>create( lt_fieldcat ).
table_type = cl_abap_tabledescr=>create( p_line_type = struct_type ).
ENDIF.
*Create Dynamic Internal table and work area
CREATE DATA dataref TYPE HANDLE table_type.
****"""Create dynamic internal table END

ASSIGN dataref->* TO <lt_table_persist>.
ASSIGN gt_table->* TO <lt_table>.
MOVE-CORRESPONDING <lt_table> TO <lt_table_persist>.
<lfs_fae_index>-it_fcat = it_fieldcat_persist.
DATA(lt_data_persist) = REF #( <lt_table_persist> ).
<lfs_fae_index>-table_data = lt_data_persist.
ENDIF.

IF is_table-union IS NOT INITIAL.""""""by ashish instruction we added here 25.04.2025 AND gt_table IS NOT INITIAL.
READ TABLE gt_fae_index ASSIGNING <lfs_fae_index>
WITH KEY name = is_table-from_table-name.
IF sy-subrc NE 0.
"insert UNION data for the UNION table
APPEND INITIAL LINE TO gt_fae_index ASSIGNING <lfs_fae_index>.
<lfs_fae_index>-name = is_table-from_table-name.
<lfs_fae_index>-union = abap_true.
<lfs_fae_index>-union_data = gt_table.
IF is_table-persist EQ abap_true.
" Create dynamic internal table and line structure
DATA: ltab_fieldcat_persist TYPE cl_abap_structdescr=>component_table,
wa_fieldcat_persist LIKE LINE OF ltab_fieldcat_persist.

LOOP AT it_fieldcat_persist INTO DATA(ls_fielcat_persist).
wa_fieldcat_persist-name = ls_fielcat_persist-fieldname.
wa_fieldcat_persist-type ?= cl_abap_typedescr=>describe_by_name(
ls_fielcat_persist-tabname && '-' && ls_fielcat_persist-fieldname ).
APPEND wa_fieldcat_persist TO ltab_fieldcat_persist.
CLEAR:ls_fielcat_persist,wa_fieldcat_persist.
ENDLOOP.

*Create Dynamic table using component table
IF ltab_fieldcat_persist IS NOT INITIAL.
struct_type = cl_abap_structdescr=>create( ltab_fieldcat_persist ).
table_type = cl_abap_tabledescr=>create( p_line_type = struct_type ).
ENDIF.
*Create Dynamic Internal table and work area
CREATE DATA lr_data TYPE HANDLE table_type.

ASSIGN lr_data->* TO <lt_table_persist>.
ASSIGN gt_table->* TO <lt_table>.
MOVE-CORRESPONDING <lt_table> TO <lt_table_persist>.
<lfs_fae_index>-it_fcat = it_fieldcat_persist.
lt_data_persist = REF #( <lt_table_persist> ).
<lfs_fae_index>-table_data = lt_data_persist.
ENDIF.
ELSE.
"append current table entries to the UNION data
IF <lfs_fae_index>-union_data IS NOT INITIAL.
ASSIGN <lfs_fae_index>-union_data->* TO <lt_table_append>.
ELSE.
" Create dynamic internal table and line structure
DATA: ltab_fieldcat_union_data TYPE cl_abap_structdescr=>component_table,
wa_fieldcat_union_data LIKE LINE OF ltab_fieldcat_union_data.

IF gt_fi_data IS NOT INITIAL.
LOOP AT gt_fi_data INTO DATA(ls_fieldcat_union_data).
wa_fieldcat_union_data-name = ls_fieldcat_union_data-name.
wa_fieldcat_union_data-type ?= cl_abap_typedescr=>describe_by_name(
is_table-from_table-name && '-' && ls_fieldcat_union_data-name ).
APPEND wa_fieldcat_union_data TO ltab_fieldcat_union_data.
CLEAR:ls_fielcat_persist,wa_fieldcat_union_data.
ENDLOOP.

ENDIF.

*Create Dynamic table using component table
IF ltab_fieldcat_union_data IS NOT INITIAL.
struct_type = cl_abap_structdescr=>create( ltab_fieldcat_union_data ).
table_type = cl_abap_tabledescr=>create( p_line_type = struct_type ).
ENDIF.

*Create Dynamic Internal table and work area
CREATE DATA lr_data TYPE HANDLE table_type.
ASSIGN lr_data->* TO <lt_table_append>.
ENDIF.
ASSIGN gt_table->* TO <lt_table>.
INSERT LINES OF <lt_table> INTO TABLE <lt_table_append>.

SORT <lt_table_append>. """"""""""""""""""""""""""""""""""newly added as Ashish informed
DELETE ADJACENT DUPLICATES FROM <lt_table_append> COMPARING ALL FIELDS ."union duplicates removal """"""""""""""""""newly added as Ashish informed

DATA(lt_data_union) = REF #( <lt_table_append> ).
<lfs_fae_index>-union_data = lt_data_union.
<lfs_fae_index>-union = abap_true.

"append current table entries to the PERSIST data
IF is_table-persist EQ 'X' OR <lfs_fae_index>-table_data IS NOT INITIAL.
IF it_fieldcat_persist IS NOT INITIAL.

DATA: ltab_fieldcat_pers TYPE cl_abap_structdescr=>component_table,
wa_fieldcat_pers LIKE LINE OF ltab_fieldcat_pers.

LOOP AT it_fieldcat_persist INTO DATA(ls_fieldcat_pers).
wa_fieldcat_pers-name = ls_fieldcat_pers-fieldname.
wa_fieldcat_pers-type ?= cl_abap_typedescr=>describe_by_name(
ls_fieldcat_pers-tabname && '-' && ls_fieldcat_pers-fieldname ).
APPEND wa_fieldcat_pers TO ltab_fieldcat_pers.
CLEAR: wa_fieldcat_pers,ls_fieldcat_pers.
ENDLOOP.

*Create Dynamic table using component table
IF ltab_fieldcat_pers IS NOT INITIAL.
struct_type = cl_abap_structdescr=>create( ltab_fieldcat_pers ).
table_type = cl_abap_tabledescr=>create( p_line_type = struct_type ).
ENDIF.

*Create Dynamic Internal table and work area
CREATE DATA lr_data TYPE HANDLE table_type.
ASSIGN lr_data->* TO <lt_table_persist>.
MOVE-CORRESPONDING <lt_table> TO <lt_table_persist>.
INSERT LINES OF <lt_table_persist> INTO TABLE <lt_table_append>.
lt_data_persist = REF #( <lt_table_append> ).
<lfs_fae_index>-table_data = lt_data_persist.
ELSE.
IF <lfs_fae_index>-table_data IS NOT INITIAL.
ASSIGN <lfs_fae_index>-table_data->* TO <lt_table_persist>.
ENDIF.
MOVE-CORRESPONDING <lt_table_append> TO <lt_table_persist>.
lt_data_persist = REF #( <lt_table_persist> ).
<lfs_fae_index>-table_data = lt_data_persist.
ENDIF.
ENDIF.
ENDIF.
ENDIF.

IF is_table-union = abap_true.
DATA(lv_union_file) = abap_true. """""by ashish instruction we added here 25.04.2025
"Check if there are no more UNION entries for this table, if found file zip to be skipped
READ TABLE gt_config_tables TRANSPORTING NO FIELDS
WITH KEY name = is_table-name
from_table-name = is_table-from_table-name
union = abap_true.
IF sy-subrc EQ 0.
DATA(lv_index) = sy-tabix + 1.
LOOP AT gt_config_tables INTO DATA(ls_config_table) FROM lv_index.
IF ls_config_table-from_table-name = is_table-from_table-name AND
ls_config_table-union = abap_true.
DATA(lv_skip_file_zip) = abap_true.
EXIT.
ENDIF.
ENDLOOP.
ENDIF.
"Clear UNION table data if file ZIP for UNION table is to be made
IF lv_skip_file_zip = abap_false.
READ TABLE gt_fae_index ASSIGNING <lfs_fae_index>
WITH KEY name = is_table-from_table-name
union = abap_true.
IF sy-subrc EQ 0.
gt_table = <lfs_fae_index>-union_data.
* DATA(lv_union_file) = abap_true. """""by ashish instruction we commented here 25.04.2025
CLEAR <lfs_fae_index>-union_data.
ENDIF.
ENDIF.
ENDIF.

IF lv_skip_file_zip = abap_false.

IF gt_table IS NOT INITIAL.
/ui2/cl_json=>serialize(
EXPORTING
data = gt_table " Data to serialize
compress = abap_true " Skip empty elements
RECEIVING
r_json = DATA(lv_data_string)" JSON string
).
ENDIF.

IF lv_data_string IS NOT INITIAL.
REPLACE ALL OCCURRENCES OF v_cr IN lv_data_string WITH space.
" lv_xstring = cl_abap_hmac=>string_to_xstring( if_input = lv_data_string ).

TRY.
lv_xstring = cl_abap_hmac=>string_to_xstring( if_input = lv_data_string ).
CATCH cx_abap_message_digest INTO DATA(lx_error).  "#EC NO_HANDLER
" Handle error - log, raise your own exception, etc.
ENDTRY.

ENDIF.

IF lv_union_file EQ abap_true.
lv_filename = is_table-from_table-name.
ELSE.
lv_filename = is_table-name.
ENDIF.

APPEND INITIAL LINE TO gt_file_urls ASSIGNING FIELD-SYMBOL(<lfs_file_url>).
<lfs_file_url>-filename = |{ lv_filename }| && |.json|.
<lfs_file_url>-filedata = lv_xstring.
go_zip->add(
EXPORTING
name = |{ lv_filename }| && |.json| " Name (Case-Sensitive)
content = lv_xstring
).
CLEAR lt_description.
APPEND INITIAL LINE TO lt_description ASSIGNING FIELD-SYMBOL(<lfs_description>).
<lfs_description> = |{ lv_filename }| && |.json|.
go_event_instance->log_telemetry(
EXPORTING
iv_action = zcl_instru_event_class=>gc_json_file_created
it_description = lt_description
).

ENDIF.

* CLEAR:lv_skip_file_zip,
* lv_index,
* lv_filename,
* lv_union_file.

CLEAR:lv_filename.

ENDMETHOD.


METHOD trigger_ingestion.
DATA:lv_cnt TYPE i,
ls_metadata TYPE zstr_elt_meta_post_comm.

* create_files( it_tables = is_config-tables ).
create_files(
EXPORTING
it_tables = is_config-tables
IMPORTING
ex_file_name = DATA(im_file_name)
).
ex_file_name = im_file_name.

DO gv_url_retry_count TIMES.
lv_cnt = lv_cnt + 1.
go_event_instance->log_measurement(
EXPORTING
iv_action = zcl_instru_event_class=>gc_gen_presign_url_event_cnt
iv_value = CONV #( lv_cnt )
).
* generate_pre_sign(
* IMPORTING
* es_abap_response = DATA(ls_abap_response) " Parse Presigned URL
* ev_status_code = DATA(lv_status_code)
* ev_reason = DATA(lv_reason)
* ).

generate_pre_sign(
IMPORTING
es_abap_response = DATA(ls_abap_response)
ev_status_code = DATA(lv_status_code)
ev_reason = DATA(lv_reason)
ex_pre_sign_url = DATA(im_pre_sign_url)
ex_gen_pre_sign_url = DATA(im_gen_pre_sign_url)
* gc_send_api_fail_gen_prsi =
* gc_rcv_api_gen_prsi_ret_code =
* gc_rcv_api_gen_prsi_resp =
* gc_rcv_api_gen_prsi_resp_init =
* gc_rcv_api_gen_prsi_ret_code_f =
ex_send_api_fail_gen_prsi = DATA(im_send_api_fail_gen_prsi)
ex_rcv_api_gen_prsi_ret_code = DATA(im_rcv_api_gen_prsi_ret_code)
ex_rcv_api_gen_prsi_resp = DATA(im_rcv_api_gen_prsi_resp)
ex_rcv_api_gen_prsi_resp_init = DATA(im_rcv_api_gen_prsi_resp_init)
ex_rcv_api_gen_prsi_ret_code_f = DATA(im_rcv_api_gen_prsi_ret_code_f)
).

ex_abap_response = ls_abap_response.
ex_status_code = lv_status_code.
ex_reason = lv_reason.
ex_pre_sign_url = im_pre_sign_url.
ex_gen_pre_sign_url = im_gen_pre_sign_url.
ex_send_api_fail_gen_prsi = im_send_api_fail_gen_prsi.
ex_rcv_api_gen_prsi_ret_code = im_rcv_api_gen_prsi_ret_code.
ex_rcv_api_gen_prsi_resp = im_rcv_api_gen_prsi_resp.
ex_rcv_api_gen_prsi_resp_init = im_rcv_api_gen_prsi_resp_init.
ex_rcv_api_gen_prsi_ret_code_f = im_rcv_api_gen_prsi_ret_code_f.



IF lv_status_code EQ 200.
go_event_instance->log_telemetry(
EXPORTING
iv_action = zcl_instru_event_class=>gc_gen_presign_succ
iv_value = CONV #( lv_cnt )
).
CLEAR lv_cnt.
EXIT.
ELSE.
IF lv_cnt NE gv_url_retry_count.
WAIT UP TO gv_url_retry_wait_sec SECONDS.
ENDIF.
ENDIF.
ENDDO.

IF lv_status_code NE 200.
* MESSAGE e000 WITH lv_reason.
ENDIF.

IF ls_abap_response-result-payload IS NOT INITIAL.

CLEAR:lv_status_code,
lv_cnt.
DO gv_url_retry_count TIMES.
lv_cnt = lv_cnt + 1.
go_event_instance->log_measurement(
EXPORTING
iv_action = zcl_instru_event_class=>gc_ingest_event_cnt
iv_value = CONV #( lv_cnt )
).
* ingest_files(
* EXPORTING
* iv_presigned_url = ls_abap_response-result-payload
* IMPORTING
* ev_status_code = lv_status_code
* ev_reason = lv_reason
* ).

ingest_files(
EXPORTING
iv_presigned_url = ls_abap_response-result-payload
IMPORTING
ev_status_code = lv_status_code
ev_reason = lv_reason
* gc_rcv_api_upload_ret_code_f =
* gc_rcv_api_upload_ret_code =
* gc_send_api_fail_upload =
* gc_create_url_fail_upload =
ex_rcv_api_upload_ret_code_f = DATA(im_rcv_api_upload_ret_code_f)
ex_rcv_api_upload_ret_code = DATA(im_rcv_api_upload_ret_code)
ex_send_api_fail_upload = DATA(im_send_api_fail_upload)
ex_create_url_fail_upload = DATA(im_create_url_fail_upload)
).
ex_ingestfile_status_code = lv_status_code.
ex_ingestfile_reason = lv_reason.
ex_rcv_api_upload_ret_code_f = im_rcv_api_upload_ret_code_f.
ex_rcv_api_upload_ret_code = im_rcv_api_upload_ret_code.
ex_send_api_fail_upload = im_send_api_fail_upload.
ex_create_url_fail_upload = im_create_url_fail_upload.





IF lv_status_code EQ 200.
go_event_instance->log_telemetry(
EXPORTING
iv_action = zcl_instru_event_class=>gc_ingest_succ
iv_value = CONV #( lv_cnt )
).
CLEAR lv_cnt.
EXIT.
ELSE.
IF lv_cnt NE gv_url_retry_count.
WAIT UP TO gv_url_retry_wait_sec SECONDS.
ENDIF.
ENDIF.
ENDDO.

IF lv_status_code NE 200.
* MESSAGE e000 WITH lv_reason.
ENDIF.

ENDIF.


IF lv_status_code EQ 200.
APPEND INITIAL LINE TO ls_metadata-s3_details ASSIGNING FIELD-SYMBOL(<lfs_s3_details>).
<lfs_s3_details>-url = ls_abap_response-result-payload.


CLEAR:lv_status_code,
lv_cnt.
DO gv_url_retry_count TIMES.
lv_cnt = lv_cnt + 1.
go_event_instance->log_measurement(
EXPORTING
iv_action = zcl_instru_event_class=>gc_post_com_evnt_cnt
iv_value = CONV #( lv_cnt )
).
* post_command(
* EXPORTING
* is_metadata = ls_metadata
* IMPORTING
* ev_status_code = lv_status_code
* ev_reason = lv_reason
* ).

post_command(
EXPORTING
is_metadata = ls_metadata
IMPORTING
ev_status_code = lv_status_code
ev_reason = lv_reason
* gc_rcv_api_post_com_ret_code_f =
* gc_send_api_fail_post_comm =
* gc_create_url_fail_post_comm =
* gc_post_comm_url_not_maint =
ex_post_comm_url_not_maint = DATA(im_post_comm_url_not_maint)
ex_create_url_fail_post_comm = DATA(im_create_url_fail_post_comm)
ex_send_api_fail_post_comm = DATA(im_send_api_fail_post_comm)
ex_rcv_api_post_com_ret_code_f = DATA(im_rcv_api_post_com_ret_code_f)
).
ex_postcomm_status_code = lv_status_code.
ex_postcomm_reason = lv_reason.
ex_post_comm_url_not_maint = im_post_comm_url_not_maint.
ex_create_url_fail_post_comm = im_create_url_fail_post_comm.
ex_send_api_fail_post_comm = im_send_api_fail_post_comm.
ex_rcv_api_post_com_ret_code_f = im_rcv_api_post_com_ret_code_f.






IF lv_status_code EQ 200.
go_event_instance->log_telemetry(
EXPORTING
iv_action = zcl_instru_event_class=>gc_post_com_success
iv_value = CONV #( lv_cnt )
).
CLEAR lv_cnt.
* MESSAGE s060 WITH gv_command_id.
EXIT.
ELSE.
IF lv_cnt NE gv_url_retry_count.
WAIT UP TO gv_url_retry_wait_sec SECONDS.
ENDIF.
ENDIF.
ENDDO.

IF lv_status_code NE 200..
* MESSAGE e000 WITH lv_reason.
ENDIF.

ENDIF.
ENDMETHOD.


METHOD trigger_posting.

TYPES:BEGIN OF ty_s_idem_keys,
idem_key TYPE c LENGTH 100,
row_no TYPE int4,
END OF ty_s_idem_keys,
ty_t_idem_keys TYPE TABLE OF ty_s_idem_keys.

DATA:lt_idem_keys TYPE ty_t_idem_keys.
DATA:lt_idem_keys_r TYPE ty_t_idem_keys.

DATA:ls_metadata TYPE zstr_elt_meta_post_comm,
lv_cnt TYPE i.

DATA:ls_elt_succ TYPE ztelt_success,
ls_elt_errs TYPE ztelt_errors.

DATA:lt_description TYPE TABLE OF string.

DATA:lt_idem_exist TYPE TABLE OF ztelt_success.

DATA: lv_file TYPE string,
lt_string_table TYPE string_table,
lt_schema TYPE zstr_elt_posting_tt,
lv_query TYPE string,
ls_query_schema TYPE zstr_dynamic_query,
ls_posting_file TYPE zstr_elt_posting.

DATA:lt_ack_info TYPE zstr_elt_ack_tt.

get_posting_file(
EXPORTING
is_file_url = is_file_details " S3 URL details structure
IMPORTING
es_abap_response = DATA(lv_posting_file) " ELT posting schema
).

SPLIT lv_posting_file AT cl_abap_char_utilities=>newline INTO TABLE DATA(lt_posting_file).

CLEAR lt_idem_exist.
LOOP AT lt_posting_file ASSIGNING FIELD-SYMBOL(<lfs_posting_file>).
DATA(lv_tabix) = sy-tabix.
CLEAR:lt_description,
ls_posting_file.
* *** convert the data from json to sap format
/ui2/cl_json=>deserialize( EXPORTING json = <lfs_posting_file>
pretty_name = abap_true
CHANGING data = ls_posting_file ).

APPEND INITIAL LINE TO lt_description ASSIGNING FIELD-SYMBOL(<lfs_description>).
<lfs_description> = <lfs_posting_file>.
go_event_instance->log_start(
EXPORTING
iv_action = zcl_instru_event_class=>gc_exec_post_file_start
it_description = lt_description
).

APPEND INITIAL LINE TO lt_idem_keys ASSIGNING FIELD-SYMBOL(<lfs_idem_keys>).
<lfs_idem_keys>-idem_key = ls_posting_file-idempotency_key.
<lfs_idem_keys>-row_no = lv_tabix.

SELECT SINGLE *
FROM ztelt_success
WHERE idem_key = @ls_posting_file-idempotency_key
INTO @DATA(ls_idem_exist).

IF sy-subrc EQ 0.
APPEND ls_idem_exist TO lt_idem_exist.
CLEAR ls_idem_exist.
go_event_instance->log_error(
EXPORTING
iv_action = zcl_instru_event_class=>gc_idem_already_exist
).
CLEAR ls_elt_errs.
* GET TIME.
ls_elt_errs-entry_date = cl_abap_context_info=>get_system_date( ).
ls_elt_errs-entry_time = cl_abap_context_info=>get_system_time( ).
ls_elt_errs-command_id = gv_command_id.
ls_elt_errs-idem_key = ls_posting_file-idempotency_key.
ls_elt_errs-row_no = lv_tabix.
ls_elt_errs-status = 'DUPLICATE'.
ls_elt_errs-err_no = 1.
ls_elt_errs-typemes = 'E'.
ls_elt_errs-numbermes = '068'.
* MESSAGE e068 INTO ls_elt_errs-messagemes.
update_post_failure(
EXPORTING
is_elt_errs = ls_elt_errs " Log of document posted via ELT posting
IMPORTING
ev_subrc = DATA(lv_subrc) " ABAP System Field: Return Code of ABAP Statements
ev_dbcnt = DATA(lv_dbcnt) " ABAP System Field: Edited Database Table Rows
).
IF lv_subrc EQ 0 AND lv_dbcnt >= 1.
COMMIT WORK.
go_event_instance->log_telemetry(
EXPORTING
iv_action = zcl_instru_event_class=>gc_error_table_updated
iv_value = CONV #( lv_dbcnt )
).
ENDIF.
CONTINUE.
ENDIF.

insert_table( is_schema = ls_posting_file ).
*
check_precondition(
EXPORTING
is_schema = ls_posting_file
iv_row_no = lv_tabix
IMPORTING
ev_error = DATA(lv_error)
).
IF lv_error IS NOT INITIAL.
CONTINUE.
ELSE.
go_event_instance->log_telemetry(
EXPORTING
iv_action = zcl_instru_event_class=>gc_all_check_condition_passed
).
ENDIF.
*
CLEAR gt_context_data.
get_context_data( is_schema = ls_posting_file ).
*
CASE ls_posting_file-posting_type.
* WHEN 'BAPI_ACC_DOCUMENT_POST'.
* bapi_acc_document_post( is_schema = ls_posting_file
* iv_row_no = lv_tabix ).
* WHEN ' '.
WHEN OTHERS.
ENDCASE.

go_event_instance->log_end(
EXPORTING
iv_action = zcl_instru_event_class=>gc_exec_post_file_end
).
CLEAR:lv_error,
lv_tabix.
ENDLOOP.


SELECT * FROM ztelt_success
FOR ALL ENTRIES IN @lt_idem_keys
WHERE command_id = @gv_command_id AND
idem_key = @lt_idem_keys-idem_key AND
row_no = @lt_idem_keys-row_no
INTO TABLE @DATA(lt_elt_succ).

SELECT * FROM ztelt_errors
FOR ALL ENTRIES IN @lt_idem_keys
WHERE command_id = @gv_command_id AND
idem_key = @lt_idem_keys-idem_key AND
row_no = @lt_idem_keys-row_no
INTO TABLE @DATA(lt_elt_errs).

LOOP AT lt_idem_keys ASSIGNING <lfs_idem_keys>.
APPEND INITIAL LINE TO lt_ack_info ASSIGNING FIELD-SYMBOL(<lfs_ack_info>).
<lfs_ack_info>-idempotency_key = <lfs_idem_keys>-idem_key.
READ TABLE lt_elt_succ ASSIGNING FIELD-SYMBOL(<lfs_elt_succ>)
WITH KEY idem_key = <lfs_idem_keys>-idem_key
row_no = <lfs_idem_keys>-row_no.
IF sy-subrc EQ 0.
<lfs_ack_info>-status = <lfs_elt_succ>-status.
<lfs_ack_info>-posting_info-company_code = <lfs_elt_succ>-company_code.
<lfs_ack_info>-posting_info-fiscal_year = <lfs_elt_succ>-fiscal_year.
<lfs_ack_info>-posting_info-voucher_number = <lfs_elt_succ>-document_number.
ENDIF.
LOOP AT lt_elt_errs ASSIGNING FIELD-SYMBOL(<lfs_elt_errs>)
WHERE idem_key = <lfs_idem_keys>-idem_key AND
row_no = <lfs_idem_keys>-row_no.
READ TABLE lt_idem_exist ASSIGNING FIELD-SYMBOL(<lfs_idem_exist>)
WITH KEY idem_key = <lfs_idem_keys>-idem_key.
IF sy-subrc EQ 0.
<lfs_ack_info>-posting_info-company_code = <lfs_idem_exist>-company_code.
<lfs_ack_info>-posting_info-fiscal_year = <lfs_idem_exist>-fiscal_year.
<lfs_ack_info>-posting_info-voucher_number = <lfs_idem_exist>-document_number.
ENDIF.
APPEND INITIAL LINE TO <lfs_ack_info>-posting_result ASSIGNING FIELD-SYMBOL(<lfs_posting_result>).
<lfs_ack_info>-status = <lfs_elt_errs>-status.
<lfs_posting_result>-message_text = <lfs_elt_errs>-messagemes.
<lfs_posting_result>-message_id = <lfs_elt_errs>-idmes.
<lfs_posting_result>-message_number = <lfs_elt_errs>-numbermes.
<lfs_posting_result>-message_v1 = <lfs_elt_errs>-message_v1mes.
<lfs_posting_result>-message_v2 = <lfs_elt_errs>-message_v2mes.
<lfs_posting_result>-message_v3 = <lfs_elt_errs>-message_v3mes.
<lfs_posting_result>-message_v4 = <lfs_elt_errs>-message_v4mes.
ENDLOOP.
ENDLOOP.

CLEAR:lv_cnt.
DO gv_url_retry_count TIMES.
lv_cnt = lv_cnt + 1.
go_event_instance->log_measurement(
EXPORTING
iv_action = zcl_instru_event_class=>gc_post_com_evnt_cnt
iv_value = CONV #( lv_cnt )
).
ls_metadata-acknowledgment_info = lt_ack_info.
post_command(
EXPORTING
is_metadata = ls_metadata
IMPORTING
ev_status_code = DATA(lv_status_code)
).
IF lv_status_code EQ 200.
go_event_instance->log_telemetry(
EXPORTING
iv_action = zcl_instru_event_class=>gc_post_com_success
iv_value = CONV #( lv_cnt )
).
CLEAR lv_cnt.
* MESSAGE s060 WITH gv_command_id.
EXIT.
ELSE.
IF lv_cnt NE gv_url_retry_count.
WAIT UP TO gv_url_retry_wait_sec SECONDS.
ENDIF.
ENDIF.
ENDDO.

IF lv_status_code NE 200.
* MESSAGE e061 WITH lv_status_code.
ENDIF.

ENDMETHOD.


METHOD update_post_failure.

INSERT ztelt_errors FROM @is_elt_errs.
ev_subrc = sy-subrc.
ev_dbcnt = sy-dbcnt.

ENDMETHOD.


METHOD update_post_success.

INSERT ztelt_success FROM @is_elt_succ.
ev_subrc = sy-subrc.
ev_dbcnt = sy-dbcnt.

ENDMETHOD.
ENDCLASS.
