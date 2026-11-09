# ZZCLR_EINVOICE_ELT — conversion design

RAP / ABAP-Cloud rebuild of the on-premise package `/CLR/EINVOICE_ELT`,
built as a sibling of the already-converted `ZZCLR_ELT`.

- **Source analysed:** `/CLR/EINVOICE_ELT` (707 files), `/CLR/ELT` (201), `/CLR/INSTRUMENTATION` (71)
- **Template followed:** `integration-sap-public-cloud-elt-WEIKFIELD-ELT`, generation "B" (the short `Z*` prefixes — the mature generation with the event log, APJ jobs, BAL logging and ATC-hardened dynamic SQL). The older `ZGSTELT_*` generation was not used as a model.
- **Scope:** ten configuration business objects, the outbound Sales/AR e-invoice BO, the AP/inbound BO and the self-billed BO.
- **Status:** 549 files, statically cross-checked (§8). **Not compiled** — nothing here has been through an ADT syntax check or ATC run, and §7 lists the specific things to verify first.
- **Second pass (2026-09-25 HANA drop):** see §11 for everything that changed and why.

---

## 0. Package boundary

This repository is **one** ABAP package, `ZZCLR_EINVOICE_ELT` — the cloud
counterpart of `/CLR/EINVOICE_ELT` only. `/CLR/ELT` and
`/CLR/INSTRUMENTATION` are **not** in it; their cloud version is the separate
`ZZCLR_ELT` package you already have, and this package consumes it.

The entire runtime dependency is three lines of code:

| Consumed object | Where | What for |
|---|---|---|
`ZCL_ELT` | `ZCL_EINV_SUBMIT` line 100 — `NEW zcl_elt( )` | the command/pull engine: `get_command`, `trigger_ingestion`, the presigned-URL upload, the zip, the acknowledgement, and `insert_table` (which is what writes the status rows back) |
`ZTELT_CONFIG` | `ZCL_EINV_CONFIG` lines 399, 410 | `LABELTYPE = 'AUTH'` (the platform token) and `'HOSTNAME'` |

Nothing else crosses the boundary. In particular `ZCL_INSTRU_EVENT_CLASS` is
**not** referenced — instrumentation is reached only transitively, because
`ZCL_ELT`'s own constructor instantiates it, exactly as in the HANA original.

This mirrors the on-premise split, where `/CLR/EINVOICE_ELT`'s only entry into
`/CLR/ELT` was the single function module `/CLR/EINV_EWAY_TRIGGER_ELT` plus
three `SELECT`s on `/CLR/ZT_ELT_CNFG`.

One thing to know about that split: in HANA it is **circular**. `/CLR/ZCL_ELT`
does `MODIFY /clr/zt_einv` on its error branches — the shared framework writes
into the e-invoice package's own table. Here the direction is one-way:
`ZCL_EINV_SUBMIT` calls `ZCL_ELT` and *returns* the outcome, and the RAP
handler persists it. `ZCL_ELT` still writes the status tables through its
generic `insert_table`, but by table name from the platform-supplied schema,
not by a compile-time dependency on this package.

## 1. What the HANA package actually was

Worth stating plainly, because it shapes every decision below.

| Object type | Count | What they really were |
|---|---:|---|
Transparent tables | 23 | 8 transactional, 15 customizing |
DDIC structures | 76 | almost entirely JSON wire-shapes for `/ui2/cl_json` |
Data elements | ~300 | one per field, mostly single-use |
Classes | 6 | of which **3 are completely empty** (`ZCL_EINV_AE`, `_FR`, `_OM`) |
Function groups | 14 | **all 14 are SM30 table-maintenance generator output, no logic** |
Programs/includes | 13 | selection screens, ALV callbacks, dynpro modules |
Transactions | 18 | 12 of them just SM30 shortcuts |

The real logic sat in three places: `/CLR/ZCL_EINV_BASE` (1,886 lines), the report includes, and — critically — **outside the package**, in `/CLR/ZCL_ELT` of `/CLR/ELT`, reached through the single function module `/CLR/EINV_EWAY_TRIGGER_ELT`.

Four findings changed the design materially:

1. **The country subclasses are empty.** `/CLR/ZCL_EINV_FACTORY` built a class name by string concatenation (`'/CLR/ZCL_EINV_' && land1`) to get country-specific polymorphism, but `_AE`, `_FR` and `_OM` have no bodies. Every hook they were meant to fill — `cancel`, `call_cancel`, `edit_row`, `exclude_doc` — inherits an empty method from the base class. **Cancel and inline edit were non-functional in the shipped code.**

2. **`exclude_doc` had inverted-safe behaviour.** It always returned blank, and `consolidate_data` read blank as "not eligible". So the moment anyone maintained the `EXCLUDE_DOC` constant, *every* document was silently dropped from the worklist.

3. **`/CLR/AP_EINVOICE~get_document_info` is entirely commented out** (lines 344–818). `/CLR/EINV_APITEM` is therefore never written and `/CLR/EINV_APHEAD` only ever gets four of its 159 fields. The AP cockpit filters on `ISSUE_DT`, `BUYER_VAT` and `SELLER_VAT`, all of which stay initial — so it normally returns nothing. That commented block is the only surviving UBL→table mapping spec, which is why AP is phase 2 rather than part of this delivery.

4. **The dependency on `/CLR/ELT` is circular.** `/CLR/ZCL_ELT` itself does `MODIFY /clr/zt_einv` on its error branches — the "shared framework" writes into the e-invoice package's own table. §5 explains how that is handled.

---

## 2. Object model

### 2.1 Configuration — 15 tables become 10

| HANA | Cloud | Decision |
|---|---|---|
`/CLR/EINV_CNTRY` | `ZTEINV_CNTRY` | kept; `HANDLER_CLASS` added (§4) |
`/CLR/EINV_API` | `ZTEINV_API` | kept as-is |
`/CLR/EINV_CONST` | `ZTEINV_CONST` | kept as-is |
`/CLR/EINV_INVMAP` | `ZTEINV_INVMAP` | kept as-is |
`/CLR/EINV_DOCTYP` | `ZTEINV_DOCTYP` | kept as-is |
`/CLR/EINV_STATUS` | `ZTEINV_STATUS` | **reduced** — `SYNC_ICON`/`ASYNC_ICON`/`SYNC_COLOUR`/`COLOR_CODE`/`COLOR_DESC` replaced by one `CRITICALITY`; sync/async collapsed into a `PROC_MODE` key |
`/CLR/EINV_VAT` | `ZTEINV_VAT` | kept as-is |
`/CLR/YT_ACTION` | `ZTEINV_ACTION` | kept as-is |
`/CLR/YT_REASON` | `ZTEINV_REASON` | kept as-is |
`/CLR/YT_STATUS` | `ZTEINV_STATTX` | kept as-is |
`/CLR/EINV_FCAT` | — | **dropped**: an `lvc_t_fcat` field catalogue. Now `@UI.lineItem` annotations in `ZCDS_MET_EINV_DOC`. |
`/CLR/EINV_APFCAT` | — | **dropped** (same reason, AP side) |
`/CLR/EINV_SELSCR` | — | **dropped**: drove `LOOP AT SCREEN` / `MODIFY SCREEN`. Now `@UI.selectionField` plus end-user Fiori adaptation. |
`/CLR/EINV_ALVFUN` | — | **dropped**: GUI function-code enablement. Now RAP `instance feature control`. |
`/CLR/EINV_APALV` | — | **dropped** (same, and structurally identical to `ALVFUN`) |

Five customizing tables, 14 `.tobj` maintenance objects, 14 generated function groups and 12 SM30 transactions disappear because they described a SAP GUI screen.

### 2.2 Transactional — field names kept deliberately

| HANA | Cloud |
|---|---|
`/CLR/ZT_EINV` | `ZTEINV_DOC` |
`/CLR/ZT_EINV_ASY` | `ZTEINV_DOC_ASY` |
`/CLR/ZT_EINV_ERR` | `ZTEINV_ERR` |
`/CLR/ZT_SALES_ST` | `ZTEINV_SALES_ST` |
— | `ZTEINV_PDF` (new, §3) |

**The database field names stay identical** (`VBELN`, `BELNR`, `BUKRS`, `GJAHR`, `INVID`, `STATUS`…), minus `MANDT`. This is not laziness — it is the only reason the migration is tractable. `/CLR/ZCL_ELT~insert_table` writes these tables *fully dynamically* from a schema the Clear platform sends down:

```abap
CREATE DATA ls_row TYPE (<lfs_insert_table>-name).
ASSIGN COMPONENT <lfs_data_row>-name OF STRUCTURE <lfs_row> TO <lfs_value>.
MODIFY (lv_safe_table) FROM TABLE @<lt_table_data>.
```

Rename the fields and every platform-side ingestion schema breaks. Keep them, and the platform config needs one change: the table *name*. Fiori-friendly names are applied at the CDS layer (`vbeln as BillingDocument`), which is exactly the pattern `ZZCLR_ELT` uses (`projectid` → `Projectid`).

Two design faults were fixed rather than carried over:

- `/CLR/ZT_EINV_ERR` had the pure UI flag `CHECKBOX` **inside its primary key**. Removed from the key.
- `MANDT` was an explicit first key field on all 23 tables. Replaced by `CLIENT`/`CLNT 3`, matching `ZTELT_CONFIG`.

### 2.3 Status precedence, moved into CDS

`/CLR/ZCL_EINV_BASE` resolved the effective status with three sequential overlay methods on `GT_FINAL`:

```
fill_einv_status    reads ZT_EINV        (sync)
fill_async_status   overlays ZT_EINV_ASY (async)
fill_sales_status   overlays ZT_SALES_ST (multi-stage exchange)
```

`ZCDS_INT_EINV_DOC` expresses the same precedence as one COALESCE:

```sql
coalesce( _Exchange.PaExchangeStatus,
          coalesce( _Async.SyncStatus, status ) ) as EffectiveStatus
```

The status becomes filterable, sortable and groupable — in the HANA version it existed only inside an internal table, so you could not select on it at all.

---

## 3. The worklist: materialised, not joined at runtime

This is the biggest architectural change, so it is worth being explicit about the alternative that was rejected.

The HANA cockpit built its list on every execution: `get_data` → `get_billing_docs` (VBRK ⋈ INVMAP) → `get_accounting_docs` (BKPF ⋈ INVMAP) → `select_partner_data` (BSEG, KNA1, LFA1) → `select_einvoice_data` (three status tables) → `consolidate_data` → `GT_FINAL` → ALV. The list was transient.

A RAP managed BO needs a persistent table. Two options:

- **(a) Unmanaged BO over the runtime join.** Keeps the transient model, but requires hand-implementing `READ` and `LOCK`, joins the whole journal-entry table on every list refresh, and gives no audit trail.
- **(b) Materialise.** A pick-up step inserts a `ZTEINV_DOC` row with status `NOT PROCESSED` for every relevant document; the BO is then a plain managed BO with actions.

**(b) was chosen.** It is simpler RAP, it performs far better on a list report with paging, it gives a real audit trail, and it fits the existing architecture — the platform's write-back already inserts into this table anyway. The pick-up is available two ways so nothing has to wait for a job:

- static action `PickUpDocuments` (a button in the app)
- `ZCL_EINV_PICKUP_JOB` (scheduled, with optional straight-through submission)

One behaviour was deliberately *not* preserved: `fill_einv_status` marked reversed documents without a document ID as `cancel = 'X'` and `consolidate_data` then **deleted those rows from the list**. So a cancelled document that never got an e-invoice simply vanished, with no record that it had been considered. Here the row stays and is flagged.

---

## 4. Country handling: from a class-name string to a contract

```abap
" HANA — /CLR/ZCL_EINV_FACTORY
lv_classname = '/CLR/ZCL_EINV_' && to_upper( land1 ).
CONDENSE lv_classname NO-GAPS.
CREATE OBJECT ro_instance TYPE (lv_classname).
```

Adding a country meant creating a class whose name happened to match, with nothing declaring what it had to implement. Replaced by:

- `ZIF_EINV_COUNTRY` — the explicit contract: `is_document_excluded`, `check_cancel_allowed`, `map_criticality`, `enrich_headers`
- `ZTEINV_CNTRY-HANDLER_CLASS` — the implementation, configured per company code
- `ZCL_EINV_COUNTRY_FACTORY` — resolves and caches it; the `?=` cast rejects a class that does not implement the interface, so a bad config value fails fast instead of dumping later on a missing method
- `ZCL_EINV_COUNTRY_DEFAULT` — the fallback, and the first place the four abandoned hooks actually do something

The factory also stops doing three things it should never have done: reading the company code from `IMPORT … FROM MEMORY ID '/CLR/EINV_COCKPIT'`, pushing customizing into public attributes of another object, and exposing the auth token as the public attribute `GV_AUTH`.

---

## 5. Integration: reuse `ZCL_ELT`, do not fork it

`/CLR/EINV_EWAY_TRIGGER_ELT` was the only hand-over from cockpit to platform. Function modules cannot be created in ABAP Cloud, so it becomes `ZCL_EINV_SUBMIT~submit_document`.

The converted `ZCL_ELT` in `ZZCLR_ELT` has the **generic** command engine (`get_command`, `trigger_ingestion`, `create_files`, `insert_table`, `post_command`) but not the e-invoice-specific variants the HANA version had (`get_command_einvoice`, `trigger_ingestion_einvoice`, `ingestion_writeback_einvoice`, `insert_table_einvoice_ingst`). The generic pair is used — which is the better outcome: the e-invoice flow no longer carries its own copy of the command engine, the presigned-URL upload, the zip creation or the acknowledgement handling.

Three things changed in the hand-over:

| HANA | Cloud | Why |
|---|---|---|
`DO 2 TIMES … WAIT UP TO 3 SECONDS` | no retry in-line | `WAIT` blocks a work process and is not permitted; and it is the wrong thing to do inside an action a user is waiting on. Failed documents keep their error status and `ZCL_EINV_SUBMIT_JOB` retries them. |
`MODIFY /clr/zt_einv` from the trigger | outcome returned, caller persists via EML | the trigger wrote the status table behind the cockpit's back |
Auth token in a public attribute | `ZCL_EINV_CONFIG~get_auth_token( )` | still read from `ZTELT_CONFIG[AUTH]` so one place configures both packages, but never exposed |

### HTTP

All four hand-written HTTP blocks (`call_get_status`, `call_print_pdf`, `call_seller_action`, `AP_EINVOICE~call_api`) collapse into `ZCL_EINV_API_CLIENT`, using the same released APIs `ZCL_ELT` already uses:

```abap
cl_web_http_client_manager=>create_by_http_destination(
  i_destination = cl_http_destination_provider=>create_by_url( lv_url ) )
```

Two defects were fixed rather than reproduced:

- **The auth header name was inconsistent.** `x-cleartax-auth-token` in `/CLR/ZCL_EINV_BASE` and `/CLR/AP_EINVOICE`, but `x-clear-auth-token` in `FORM call_action_api`. Unified on `x-clear-auth-token`, which is what `ZCL_ELT` sends.
- **The AP action JSON template was malformed** — a stray `{` before `"documentTypeCode"`, unbalanced braces, and only `comment` escaped. Payloads are now serialized from typed structures (`ZSTR_EINV_ACT_REQ`), so quoting cannot be got wrong.

`ZCL_EINV_API_CLIENT~create_client( )` is deliberately the single method to change when you move endpoint and credential into a Communication Arrangement — swap `create_by_url` for `create_by_comm_arrangement` and drop the token header. That is the strategic target; it was not done now because it would diverge from how `ZZCLR_ELT` works today and needs a new Communication Scenario.

---

## 6. UI: the cockpit

| HANA GUI function | RAP artefact |
|---|---|
`&CREATE` → `submit_data` / `submit_data_batch` | action `SubmitEInvoice` |
`&STATUS` → `get_status` / `call_get_status` | action `RefreshStatus` |
`&PDF` → `print_pdf` / `call_print_pdf` | action `RequestPrintout` |
`&UPDATE` → dynpro 0200 + `call_seller_action` | action `SellerAction` with a deep parameter |
`&ZCANCEL` → `cancel` / `call_cancel` (both empty) | action `CancelEInvoice` — **first working implementation** |
`get_data` + `consolidate_data` | static action `PickUpDocuments` |
`/CLR/EINV_ALVFUN` + `FORM zpfstatus1` | `instance feature control` |
hotspot → `CALL TRANSACTION 'VF03'` / `'FB03'` | `@Consumption.semanticObject`, no code |
`REUSE_ALV_GRID_DISPLAY_LVC` + `/CLR/EINV_FCAT` | `ZCDS_MET_EINV_DOC` annotations |
`set_status_colors` + `lvc_t_scol` + icon literals | `criticality` via `ZCL_EINV_VE_CRITICALITY` |
`file_save_dialog` + `SCMS_DOWNLOAD frontend='X'` | `ZTEINV_PDF` + stream download |
`FORM display_error_popup` (manual 85-char word wrap) | `_Error` child list on the object page |

**Dynpro 0200 → a deep action parameter.** The seller-action dialog had an editable `cl_gui_alv_grid` for the VAT split inside a `cl_gui_custom_container`, with `register_edit_event`, `set_ready_for_input`, a celltab style table and add/delete-row handling. In RAP that is an abstract root entity (`ZCDS_ABS_EINV_SELLACT`) with a composition to `ZCDS_ABS_EINV_VATSPLIT` — Fiori Elements renders the dialog and the editable table, and no screen-painter object exists.

**No draft handling.** This BO is action-driven, not a free-editing object page; drafts would add three shadow tables and a draft lifecycle for nothing. Concurrency is covered by `etag master LocalLastChangedAt`. (The analysis of `ZZCLR_ELT` flagged its unused `ZTELT_CONFIG_DR` draft table as an anti-pattern — not repeated here.)

**No `COMMIT WORK`, no `ENQUEUE`/`DEQUEUE`, no `MESSAGE`.** Persistence is EML inside the RAP LUW; diagnostics go through `reported`/`failed`; the PDF store flushes in `save_modified` of the additional save. For reference, the HANA code committed once per inserted row inside an `ENQUEUE_E_TABLE` bracket (`AP_EINVOICE~get_documents`) and had its `COMMIT WORK` **commented out** in `call_seller_action`, relying on the implicit commit at the next screen change.

### Background processing

`sy-batch` and `SUBMIT` are gone; three APJ jobs replace them.

| Job | Catalog entry | Replaces |
|---|---|---|
`ZCL_EINV_PICKUP_JOB` | `ZAJC_EINV_PICKUP` | running the cockpit report in background |
`ZCL_EINV_SUBMIT_JOB` | `ZAJC_EINV_SUBMIT` | `submit_data_batch` |
`ZCL_EINV_STATUS_JOB` | `ZAJC_EINV_STATUS` | **nothing — this gap did not exist before** |

The status job is genuinely new. In the HANA package status was only ever refreshed by a user pressing `&STATUS`. `/CLR/ZT_EINV_ASY` existed as an async shadow table but nothing in the package ever polled it. A document submitted on Friday afternoon sat in `SUBMITTED` until somebody opened the cockpit.

### The automatic-generation trigger — needs a decision

`/CLR/ZCL_ELT_EINVOICE` was called from two **classic enhancement implementations**:

- `/CLR/ELT_EINVOICE_SD_CREATE` at `\FU:RV_INVOICE_REFRESH\SE:BEGIN` and `\SE:END`
- `/CLR/ELT_EINVOICE_FI_CREATE` at `\PR:SAPMF05A\FO:TRANSAKTION_VERLASSEN\SE:BEGIN`, reading that program's global `XBKPF`

Source-code plug-ins into SAP's own function modules and dynpro programs **cannot exist in Public Cloud**, and there is no way to read `SAPMF05A`'s globals from outside. `ZCL_EINV_AUTO_TRIGGER` ports the full relevance logic and exposes `on_document_posted( )`; how it gets called is the open decision:

1. **Business Events** (recommended) — subscribe to billing-document / journal-entry events via Enterprise Event Enablement and call it from the consumer.
2. **A released BAdI**, if your release offers one for the posting transaction.
3. **Polling** via `ZCL_EINV_PICKUP_JOB` with `P_SUBMIT = 'X'` — no extension point needed, at the cost of latency. **This is the default, so nothing is left dangling.**

The `AUTO_IRN` transaction-code whitelist (`ZTEINV_CONST` rows compared against `sy-tcode`) is **not** ported — `sy-tcode` has no meaning in Fiori. If the intent was to restrict auto-generation to certain entry channels, express it as a document-type restriction in `ZTEINV_INVMAP`, which the relevance check already evaluates.

---

## 7. Verify these before activating

Honest list of what static checking cannot settle.

**Released-view field names.** Three views assume BKPF/VBRK semantics on released views. Confirm in ADT (F2 on the view) and adjust — they are flagged with comment blocks in the source:

- `ZCDS_INT_EINV_REL_JRNL`: `I_JournalEntry-AccountingDocumentType` (BLART), `ReferenceDocumentType` (AWTYP), `OriginalReferenceDocument` (AWKEY), `IsReversed`/`IsReversal`, `AccountingDocumentCreationDate` (CPUDT)
- `ZCDS_INT_EINV_RELEVANT`: `I_BillingDocument-BillingDocumentType` (FKART), `CancellationStatus` (FKSTO)
- `ZCDS_INT_EINV_DOC`: `I_JournalEntry-TransactionCurrency`

**Document amount.** The cockpit showed `BSEG-WRBTR`. `I_JournalEntry` has no header total, so the column is **not** in the model — deliberately, rather than guessing a field name. If it is needed, add an aggregating view over `I_JournalEntryItem`.

**`/ui2/cl_json`.** Used for serialization because the converted `ZCL_ELT` uses it and the wire structures are built for its `pretty_name` convention. It is not formally released for ABAP Cloud; it evidently works in your tenant. If ATC objects, the replacement is `xco_cp_json`, and the name mapping across all `ZSTR_EINV_*` structures has to be redone.

**Calculated fields in a managed BO.** `EffectiveStatus` / `EffectiveMessage` are CDS-calculated and unmapped in the BDEF. Under `strict ( 2 )` confirm RAP accepts them as read-only; if not, drop them from the interface view and compute the precedence in the projection instead.

**`ZTELT_CONFIG` and `ZCL_ELT` are consumed cross-package.** Both are C1-released in `ZZCLR_ELT`, so this is legitimate. `ZDE_PROJECT_ID` and `ZDE_SYSID` are **not** released, which is why this package defines its own `ZDE_EINV_PROJECTID` / `ZDE_EINV_SYSID` rather than referencing them.

**Not generated, because they cannot be hand-written meaningfully.** These carry platform-generated GUIDs, CHIP IDs and service hashes, and must be created by activating in ADT / BAS:

- IAM apps (`.sush.xml`, `ZIAM_*_EXT.sia6.xml`) and the `_IWSG` service objects — generated when the service binding is published
- Business catalogs (`.sia1.xml`, `.sia7.xml`) and launchpad pages (`.uipg.json`)
- The Fiori Elements apps themselves (`.uiad.json`) — build in BAS against `ZSB_EINV_DOC` and `ZSB_EINV_CONFIG`

Fabricating those with invented GUIDs would produce files that look right and import broken.

---

## 8. What was checked

`gen/check.py` cross-checks the whole tree and reports zero inconsistencies. It verifies:

1. every `ROLLNAME` resolves to a local data element / structure / table type
2. every data element's domain exists; every table type's row type exists
3. every CDS data source, association target and composition target resolves locally or to a declared external (`I_JournalEntry`, `I_BillingDocument`, `ZTELT_CONFIG`, `ZCL_ELT`)
4. every BDEF's implementation class, persistent table, entity and action-parameter entity exists
5. every metadata extension annotates a real entity
6. every ABAP reference to a `Z*` object of this package resolves
7. every service definition exposes real entities
8. every APJ job class implements `if_apj_dt_exec_object` and `if_apj_rt_exec_object`
9. **no non-released construct survived** — `cl_gui_alv_grid`, `cl_salv_table`, `cl_gui_frontend_services`, `cl_http_client`, `cl_rest_http_client`, `REUSE_ALV*`, `SCMS_DOWNLOAD`, `CALL FUNCTION`, `CALL TRANSACTION`, `SUBMIT`, `COMMIT`/`ROLLBACK WORK`, `WAIT UP TO`, `ENQUEUE_*`/`DEQUEUE_*`, `MESSAGE e###`, `FORM`/`PERFORM`, `LOOP AT SCREEN`, `sy-batch`/`sy-sysid`/`sy-mandt`/`sy-datum`/`sy-uzeit`/`sy-repid`/`sy-ucomm`/`sy-tcode`, and direct reads of BKPF/BSEG/VBRK/VBRP/KNA1/LFA1/T001/MKPF
10. every BDEF field mapping names a field the target table actually has

The checker was itself self-tested: a deliberately broken CDS data source and a deliberately introduced `COMMIT WORK` were both detected, then reverted. This is static analysis only — it is not a substitute for an ADT syntax check.

---

## 9. AP inbound and self-billed

Both were built in the second pass. §11 covers what the source actually contained.

## 10. Object inventory

413 files. Configuration BOs are generated from a spec (`gen/gen_ddic.py`, `gen/gen_config_rap.py`, `gen/gen_wrappers.py`) so the ten of them stay identical in shape; the transactional BO, the engine classes and the jobs are hand-written.

**DDIC** — 47 domains, 50 data elements, 24 tables/structures, 6 table types
**Configuration BOs** (×10) — `ZCDS_INT_EINV_*`, `ZCDS_CUN_EINV_*`, base + projection BDEF, `ZBP_CDS_INT/CUN_*`, `ZCDS_MET_EINV_*`
**Sales BO** — `ZCDS_INT_EINV_DOC` (+ `_ERR`, `_STAT`, `_ASY`), `ZCDS_INT_EINV_REL_JRNL`, `ZCDS_INT_EINV_RELEVANT`, `ZCDS_CUN_EINV_DOC` (+ children), 4 abstract parameter entities, 2 BDEFs, `ZBP_CDS_INT_EINV_DOC` (+ `locals_imp`, `locals_saver_imp`), `ZBP_CDS_CUN_EINV_DOC`, `ZCDS_MET_EINV_DOC`
**Value helps** — 7 × `ZVH_EINV_*`
**Engine** — `ZIF_EINV_COUNTRY`, `ZCL_EINV_COUNTRY_DEFAULT`, `ZCL_EINV_COUNTRY_FACTORY`, `ZCL_EINV_CONFIG`, `ZCL_EINV_API_CLIENT`, `ZCL_EINV_SUBMIT`, `ZCL_EINV_WORKLIST`, `ZCL_EINV_PDF_STORE`, `ZCL_EINV_UTIL`, `ZCL_EINV_VE_CRITICALITY`, `ZCL_EINV_AUTO_TRIGGER`
**Jobs** — 3 job classes + 3 `.sajc.json` + 3 `.sajt.json` + `ZAJL_EINV_EXECUTION.aplo.json`
**Services** — `ZSD_EINV_DOC`/`ZSB_EINV_DOC`, `ZSD_EINV_CONFIG`/`ZSB_EINV_CONFIG`
**Messages** — `ZEINV_MSG` (22 messages; numbers 000–025 keep their `/CLR/ZME_EINV` meaning where the original still applies)

### Suggested activation order

1. domains → data elements → structures → table types → tables
2. message class `ZEINV_MSG`
3. engine classes (`ZCL_EINV_UTIL`, `ZIF_EINV_COUNTRY`, `ZCL_EINV_CONFIG`, `ZCL_EINV_COUNTRY_*`, `ZCL_EINV_API_CLIENT`)
4. `ZCDS_INT_EINV_*` interface views → `ZVH_EINV_*` value helps → `ZCDS_CUN_EINV_*`
5. abstract parameter entities → BDEFs → `ZBP_*` classes → `ZCDS_MET_*`
6. `ZCL_EINV_WORKLIST`, `ZCL_EINV_SUBMIT`, `ZCL_EINV_PDF_STORE`, `ZCL_EINV_VE_CRITICALITY`, `ZCL_EINV_AUTO_TRIGGER`
7. service definitions → service bindings → publish (this generates the IAM/`_IWSG` objects)
8. job classes → job catalog entries → job templates → job log object
9. Fiori Elements apps in BAS → business catalogs → launchpad pages


---

## 11. Second pass — the 2026-09-25 HANA drop

The updated export adds 136 files and changes 21. Here is what it contained and what was done with it.

### 11.1 AR — what changed

| HANA change | Handled how |
|---|---|
`/CLR/ZT_EINV` + `/CLR/ZT_SALES_ST` gain `ZSIGNED_QRCODE`, `ZSIGNED_INV`, `UUID` | added to `ZTEINV_DOC` / `ZTEINV_SALES_ST` and exposed as `SignedQrCode` / `SignedInvoice` / `PlatformUuid`; the two large ones are object-page only |
`/CLR/EINV_CNTRY` gains `VAT`, and `SEQUENCE` is promoted to a key field | both applied to `ZTEINV_CNTRY` |
`/CLR/EINV_FCAT` gains `NO_OUT` | **not carried over** — `NO_OUT` is the ALV "hidden column" flag, and `EINV_FCAT` was already dropped in pass one. The equivalent is `@UI.hidden` / omission from `lineItem` |
`COMMAND_ID` surfaced in the cockpit | was already exposed |
`get_data` rewritten to resolve VBRK via `BKPF-AWKEY(10)` filtered on `AWTYP = 'VBRK'` | already the logic in `ZCDS_INT_EINV_RELEVANT` — the old code joined VBRK on `BUKRS/BELNR/GJAHR`, which are not its key. This is a genuine bug fix in the source, and the conversion had independently landed on the correct join |
`submit_data` now clears the error text on a successful resubmit | already the behaviour — the handler writes the whole result, empty message included |
`IV_COUNTRY` threaded `submit_data` → `submit_data_retrieval` → `/CLR/EINV_EWAY_TRIGGER_ELT` → `/CLR/ZCL_ELT` | `ZCL_EINV_SUBMIT~submit_document` gained `iv_country`, resolved from config when not passed. **See the caveat below.** |
New country classes `/CLR/ZCL_EINV_DE`, `/CLR/ZCL_EINV_JO` | `ZCL_EINV_COUNTRY_DE` and `_JO` added |

**On the country classes.** Both new HANA classes are *empty* — 15 lines, no overrides, byte-identical to `_AE`, `_FR` and `_OM`. Adding them is pure registration, so the factory's `CREATE OBJECT TYPE ('/CLR/ZCL_EINV_' && land1)` finds something. The country-polymorphism pattern is still not genuinely used; the real differentiation added in this drop is the `IV_COUNTRY` parameter and the config tables. The two cloud classes mirror that: empty subclasses of `ZCL_EINV_COUNTRY_DEFAULT`, present so `HANDLER_CLASS` can point at them and so there is an obvious home for German or Jordanian specifics when those are specified.

**Caveat on `IV_COUNTRY`.** The released `ZCL_ELT` in `ZZCLR_ELT` exposes only the generic `get_command( )`, which has no country parameter — the country-aware variant exists only on the HANA `/CLR/ZCL_ELT`, extended in the same drop. Rather than fork ~3,400 lines of command engine into this package, `ZCL_EINV_SUBMIT` resolves and records the country but does not pass it. **`ZZCLR_ELT` should add an optional country parameter to `get_command`**; the call site is commented and ready.

**Not carried over:** the `AUTO_IRN` transaction-code whitelist that compares `ZTEINV_CONST-LOW` against `sy-tcode`. `sy-tcode` has no meaning in Fiori.

### 11.2 AP inbound

`/CLR/EINV_APHEAD` grew 159 → 262 fields and `/CLR/EINV_APITEM` 59 → 94, so `ZTEINV_APHEAD` / `ZTEINV_APITEM` were generated from the updated definitions. Two changes were forced:

**Key normalisation.** The HANA tables cannot form a RAP composition: the header is keyed `(DOCUMENTNUMBER, UUID)` — `DOCUMENTID` was demoted out of the key in this drop — while the item is keyed `(DOCUMENTID, DOCUMENTNUMBER, LINE_ID)`. The child key does not contain the parent key. Both are normalised to `(DocumentId, DocumentNumber)` (+ `LineId`), with `UUID` as a data field. That is also what the existing HANA `UPDATE ... WHERE documentid = @.. AND documentnumber = @..` already assumed — the statement no longer matches its own primary key in the source.

**Currency and quantity references.** All 27 header amounts reference `RBKP-WAERS`, and the two item quantities reference `RSEG-BSTME`. `RBKP` and `RSEG` are not released for ABAP Cloud, so the tables cannot be activated at all. Repointed at `CURRENCY` / `INV_CURR` / `ITEM_UNIT_CODE` inside the same table, and surfaced as `@Semantics.amount.currencyCode` / `@Semantics.quantity.unitOfMeasure` in CDS.

**The fetch path is broken in the source, and this matters.** The four `/CLR/EINV_AP_GET_DOCUMENT*` programs were **deleted** in this drop while transaction `/CLR/EINV_AP_GETDOC` still points at them; nothing calls `/CLR/AP_EINVOICE` any more (`&GET_DOC` is commented out); and `get_document_info` — the only UBL→column mapping specification that has ever existed — is 100% commented out and has never run in any export. So the ~138 columns added here have no producer anywhere.

`ZCL_EINV_EDOC_FETCH` therefore implements what was actually live (`GET_DOC_LIST` → run log + the four-column document stub) and **scaffolds but does not map** the detail fetch. Writing a 262-field UBL mapping against commented-out, never-executed code would be guesswork; it needs the current API contract and a sample payload. That is stated in the class documentation rather than hidden.

### 11.3 Self-billed

**The self-billed tables are byte-for-byte copies of the AP tables.** All 262 header and 94 item fields are identical in name, data element, type, length and decimals. The only differences are the key order and `DOCUMENTID`'s key flag. There is no seller/buyer swap and no AR-only column; `ARHEAD` even keeps the AP-oriented `MATCH_STATUS`.

The direction is expressed **only in code**: self-billing filters `BUYER_VAT ∈ own VAT` (we are the buyer issuing on the supplier's behalf) and sends `taxpayerIdentifier = BUYER_VAT`, where AP sends the seller's.

So both BOs are generated from one template, and the action logic lives in one class, `ZCL_EINV_EDOC_ACTION`, parameterised by the three things that actually differ:

| | AP | Self-billed |
|---|---|---|
`EINV_TYPE` | `PURCHASE` | `SELF_BILLED` |
endpoint | `EINV_AP_STATUS` | `EINV_SELF_STATUS`, falling back to `EINV_AP_STATUS` |
`taxpayerIdentifier` | `SELLER_VAT` | `BUYER_VAT` |

In HANA these were two ~200-line copies of the same FORMs (`send_action_data` / `self_send_action_data`, `call_action_api` / `self_call_action_api`), including duplicated bugs.

**Nothing populates `/CLR/EINV_ARHEAD` or `/CLR/EINV_ARITEM` anywhere in the export** — only `SELECT` and `UPDATE`. The self-billed cockpit assumes the rows are already there. The same fetch class serves both, with the target table chosen by type.

**No link to the sales tables.** `ARHEAD` is keyed on ClearTax identifiers and carries no `BUKRS`, `VBELN`, `BELNR` or `GJAHR`. The AP cockpit joins its header to `/CLR/ZT_PURCH_ST` on `INVOICE_NUM = DOCUMENTNUMBER`; the self-billed one does **no** such join, so its status column shows only the raw stored value and never the exchange status. If that link is wanted, `DocumentNumber ↔ ZTEINV_SALES_ST.InvoiceNumber` is the obvious candidate — deliberately not invented here.

### 11.4 Two defects found by the checker, not by reading

Adding a rule that CDS elements aliased away from their table column must appear in the BDEF `mapping` block caught:

- the four new e-document BDEFs, and
- **all ten configuration BOs from the first pass**, which had no mapping blocks at all while aliasing `land1 → Country`, `bukrs → CompanyCode`, `sysid → SystemId` and more.

None of them would have activated. Both are fixed, and the rule is now check #11.

### 11.5 Source defects deliberately not reproduced

| HANA defect | Here |
|---|---|
`get_excluded_fcodes` reads `/CLR/EINV_APALV` without the new `EINV_TYPE` key, so a button disabled for self-billing also disappears from the AP cockpit | the whole table is replaced by RAP instance feature control, which cannot have the bug |
AP action payload is malformed JSON (stray `{`, unbalanced braces, only the comment escaped) | typed structure, serializer does the quoting |
`UPDATE ... WHERE documentid AND documentnumber` no longer matches the primary key | key normalised so it does |
`API_MESSAGE` lived only in the in-memory grid and was lost on exit | persisted |
`get_documents` did one `INSERT` + `ENQUEUE`/`DEQUEUE` + `COMMIT WORK` **per document**, and plain `INSERT` would dump on a re-fetch | one set-based `INSERT ... ACCEPTING DUPLICATE KEYS`, committed once by the job, so a re-fetch preserves user-set action data |
Action type accepted unvalidated if typed into the cell | `validate_action` checks it against `ZTEINV_ACTION` |
`EINV_SELF_STATUS` falls back to the AP endpoint silently | fallback kept, but reported in the result message |
`/CLR/EINV_VAT` vs `/CLR/EINV_CNTRY-VAT` half-migrated, two sources of truth | both read, longest-standing first — neither configuration breaks |

### 11.6 Still open

- **The UBL detail mapping** (§11.2). Needs the API contract; the raw payload column is reserved so it can be applied retroactively.
- **`ZZCLR_ELT` country parameter** (§11.1).
- **`ZTEINV_SALES_ST`'s three new fields are dead in the source** — `fill_sales_status` does not copy them. Exposed here so the write-back can fill them, but confirm which table the platform actually writes.
- **Self-billed ↔ sales-status link** (§11.3).
- **`/CLR/EINV_CNTRY` key extension vs. the factory's `SELECT SINGLE`** — the HANA factory does not filter on `SEQUENCE`, so with several rows per company code the row it picks is non-deterministic. `ZCL_EINV_CONFIG` orders by `SEQUENCE`; check your table content for duplicates.

---

## 12. Code review, 2026-09-28

A full review of the package — RAP behaviour, CDS layer, and hand-written ABAP
for syntax and cloud compliance — found 28 defects, five of which would have
stopped activation. All are fixed. **CODE_REVIEW.md** has the detail; this
section records only the things that changed a design decision taken earlier in
this document.

### 12.1 The derived status moved off the business object's root view

§3 described `EffectiveStatus` and `EffectiveMessage` as a `coalesce` in
`ZCDS_INT_EINV_DOC`, replacing the three overlay methods `fill_sales_status` /
`fill_async_status` / `fill_einv_status`. That is still what happens, but not
where.

A managed business object maps every element of its root view onto a column of
its persistent table, and elements not named in the `mapping for` block are
mapped implicitly by name. The six calculated elements — the two status fields
plus `TransactionCurrency`, `IsReversed`, `IsReversal` and
`BillingCancellationStatus` — have no column in `ZTEINV_DOC`, so the behaviour
definition would not have activated.

The layering is now:

    zteinv_doc
      ├── ZCDS_INT_EINV_DOC      root view of the BO, 1:1 with the table
      │     └── _Enrich [1..1] ──┐
      └── ZCDS_INT_EINV_DOC_ENR  ◄┘  the coalesce and the released-view joins

`ZCDS_CUN_EINV_DOC` exposes the six as path expressions over `_Enrich`, which
keeps them filterable and sortable — `EffectiveStatus` is a
`@UI.selectionField`, so a virtual element would not have done. The behaviour
implementation reads them with `read_enrichment( )`, a plain SELECT over the
enrichment view.

The rule this establishes, and the reason it is worth stating: **the root view
of a managed business object stays 1:1 with its table.** Anything derived goes
beside it, not in it.

### 12.2 The background jobs execute BO actions instead of repeating them

§9 described `ZCL_EINV_SUBMIT_JOB` and `ZCL_EINV_STATUS_JOB` as calling the
platform and writing the result back. They no longer do. An EML write made
outside the business object — one without `IN LOCAL MODE` — is subject to the
behaviour definition's static field control, and `SyncStatus`, `ErrorText`,
`CommandId` and `IsSent` are all `field ( readonly )` there. The write-back
would have been rejected, silently, and `select_pending` would have handed the
same documents back on the next run: an unbounded resubmission loop.

All four job and trigger classes now issue `EXECUTE SubmitEInvoice` or
`EXECUTE RefreshStatus` against the business object. The handler already does
the work in local mode, so the eligibility rules, the error-detail children and
the write-back all happen exactly once, in one place, whether the caller is a
user or a job.

### 12.3 `SubmitImmediately` is implemented

§6 listed `SubmitImmediately` among the pick-up parameters and noted that the
HANA equivalent `P_SUBM` was dead on the selection screen. It was dead here too
— the parameter was declared and never read. It now submits the rows the action
just created, which is what makes an unattended end-to-end APJ run possible.

### 12.4 Item currency references

§2 said the item amounts were repointed from `RBKP-WAERS` to the same table's
`INV_CURR`. That was wrong: `/CLR/EINV_APITEM-INV_CURR` is typed `BP_CURR` —
an amount, despite the name — and DDIC requires a `CURR` column's reference
field to be `CUKY`. Neither item table would have been created.

They now reference `PRICE_CURR`, the only real `CUKY` on those tables, except
where an amount has a currency of its own. The CDS element for `INV_CURR` is
renamed `InvoiceCurrencyAmount`. `gen_edoc.py` asserts the types before writing
a table, so the mistake cannot be made again.

### 12.5 Nine more checker rules

§8 described eleven rules. There are now twenty. The nine added during the
review are listed in CODE_REVIEW.md §5; each was self-tested by deliberately
re-introducing the defect it is meant to catch. Two of them — the readonly-key
rule and the empty-authorization-handler rule — also fire against code
inherited verbatim from `ZZCLR_ELT`, where they are reported as advisories
rather than failures.

### 12.6 Added to §11.6, still open

- **The reversal guard is skipped on the straight-through path.**
  `SubmitEInvoice` reads `IsReversed` and `BillingCancellationStatus` from the
  enrichment view, which reads the database. When `PickUpDocuments` submits
  immediately, the row it created is still in the transactional buffer, so the
  guard finds nothing and passes. The documents were selected as relevant
  moments earlier, so the window is small — but if straight-through processing
  is switched on for a high-volume company code, close it by carrying
  `IsReversed` from `ZCDS_INT_EINV_RELEVANT` into the action.
- **`ct_calculated_data = CORRESPONDING #( … )`** in `ZCL_EINV_VE_CRITICALITY`
  and `ZCL_EINV_VE_EDOC_CRIT`, against the generically typed `CHANGING`
  parameter of `if_sadl_exit_calc_element_read~calculate`. SAP's own published
  pattern, but the one construct here that a syntax check settles faster than
  reading does.
- **`ZVH_EINV_ACTTYPE_AP` and `ZVH_EINV_ACTTYPE_SELF`** filter
  `ZTEINV_ACTION` on `EInvoiceType = 'PURCHASE'` and `'SELF_BILLED'`. Those are
  the literals the HANA cockpits used, so the existing `/CLR/YT_ACTION` content
  transfers unchanged — but confirm the migrated table actually carries them
  before going live, or both dropdowns come up empty.

---

## 13. The normalised e-document model, 2026-10-01

The `/CLR/EINV_ELT_AP` drop replaces the inbound AP model outright. It is not a
field change but a model change, so the flat `ZTEINV_APHEAD` / `ZTEINV_APITEM`
pair and everything generated from it is gone, and so is the self-billed
`ZTEINV_ARHEAD` / `ZTEINV_ARITEM` pair that shared its shape.

### 13.1 Why it changed

The old tables were the HANA tables carried across as they stood: 262 and 94
columns, with fixed slots for every repeating UBL group. Four note slots. Four
tax subtotals. One allowance and one charge per document and per line. Three
slots each for contract, billing and additional document references. Anything
beyond the slot count was silently dropped on the way in.

The drop's own workbook lists 33 defects in that shape. The ones that matter
most here:

| | Old | New |
|---|---|---|
Structure | 1 allowance + 1 charge per level | `ELTAPA`, unlimited, document and line level |
Structure | 4 notes, line note separate | `ELTAPN`, unlimited, with a subject code |
Structure | 4 tax subtotals | `ELTAPT`, unlimited |
Structure | 1..4 slots per reference kind | `ELTAPR`, unlimited, typed by `REF_TYPE` |
Missing | no agent, service provider or manufacturer party | `ELTAPP` roles |
Missing | no `CustomizationID`, no SBDH sender/receiver/process | header columns |
Wrong type | every `CURR` referenced `RBKP-WAERS`, every `QUAN` referenced `RSEG-BSTME` | every reference is a `CUKY`/`UNIT` column of the same table |
Truncation | endpoint IDs at `CHAR 20`, subdivisions at `CHAR 10` | `CHAR 100` |
Precision | unit price at 2 decimals | `DEC 21,6`, quantities `QUAN 17,6` |

The currency and unit wiring is the same defect §12.4 of this document
describes: the old item tables could not have been created at all.

### 13.2 The shape

    ZTEDOC_APH   invoice header            key UUID                    root
      ZTEDOC_API   invoice line            + LINE_ID
      ZTEDOC_APP   parties                 + LINE_ID, PARTY_ROLE
      ZTEDOC_APT   VAT breakdown           + SEQ
      ZTEDOC_APA   allowances and charges  + LINE_ID, SEQ
      ZTEDOC_APN   notes                   + LINE_ID, SEQ
      ZTEDOC_APR   document references     + LINE_ID, REF_TYPE, SEQ
      ZTEDOC_APX   item attributes         + LINE_ID, ATTR_TYPE, SEQ

`ZTEDOC_SB*` is the same set for self-billing. 227 columns per variant, down
from 356, with nothing lost — the slots became rows.

`LINE_ID` is blank on a document-level row and carries the line number on a
line-level one, so parties, notes, allowances and references serve both levels
from one table. That is why every child hangs off the header on `UUID` alone:
the composition is header-to-child, and the line a child belongs to is a
property of the child, not part of the path to it.

The namespace is `ZTEDOC_` rather than `ZTEINV_` because `ZTEINV_API` was
already taken — it is the API endpoint registry. The CDS, behaviour and service
objects follow: `ZCDS_INT_EDOC_*`, `ZCDS_CUN_EDOC_*`, `ZSD_EDOC_AP`,
`ZSD_EDOC_SB`.

### 13.3 Every column carries its UBL XPath

The drop's workbook gives a UBL 2.1 XPath, a BT code where one exists, a
transformation rule and a sample value for all 227 columns. The generator reads
the workbook alongside the DDIC export and writes the XPath into the interface
view as a comment above the element, and the description into
`@EndUserText.label`:

```abap
      @EndUserText.label: 'Sum of invoice line net amounts (BT-106)'
      /* /Invoice/cac:LegalMonetaryTotal/cbc:LineExtensionAmount */
      @Semantics.amount.currencyCode: 'Currency'
      line_ext_amt as LineExtensionAmount,
```

So the mapping specification lives in the code that implements it, which is
where it is still readable in two years.

### 13.4 Two ways to see the data

**The cockpit** (`ZSD_EDOC_AP`, `ZSD_EDOC_SB`). A list report over the header,
with the seller and buyer names as columns — they come from the party table
through two filtered associations, `_SellerParty` and `_BuyerParty`, picked out
by `PARTY_ROLE` on the document-level row. The object page groups the 81 header
columns into nine sections derived from the UBL field prefixes (Document,
Standard, Currency, Totals, Delivery, Payment, Payment Terms, Prepaid, Admin),
then gives each child table a tab of its own: Lines, Parties, VAT breakdown,
Allowances and charges, Notes, References, Item attributes. Fiori Elements puts
the row count on each tab, so a document that carries nine notes says so.

This is the HANA 262-column ALV replaced by something navigable. The grouping is
not invented: the prefix of a field name is which UBL group it belongs to.

**The flat view** (`ZSD_EDOC_APFLAT`, `ZSD_EDOC_SBFLAT`). One row per invoice
line, carrying the whole header, the whole line and the document-level seller
and buyer — about 140 columns. This is what to query, download or build an
analytical report over.

What it deliberately does not flatten is the five 0..n children. Folding notes,
VAT subtotals, allowances, references or item attributes into the row would
multiply it, and every amount on it would then be wrong when summed. Those stay
as tabs and as views of their own.

### 13.5 What the key change costs

The old header was keyed on `DOCUMENTNUMBER`; the new one is keyed on `UUID`,
the SBDH `InstanceIdentifier`. The document list endpoint does not return it —
it lives in the payload, which only the detail fetch retrieves.

So `ZCL_EINV_EDOC_FETCH~fetch_document_list` now mints a local UUID for each
stub row and keeps matching the platform by `DOCUMENTNUMBER`. The duplicate
guard had to move with it: `INSERT ... ACCEPTING DUPLICATE KEYS` no longer
protects anything, because a second run would mint a second UUID and insert a
duplicate under a different key. `existing_documents( )` reads the document
numbers of the batch first and skips the ones already there, which is what keeps
a re-fetch from overwriting the action type and status a user has set.

### 13.6 Still open

- **The detail fetch is still a stub**, but it is no longer blocked on a
  specification. The target model and the XPath for every column now exist; what
  is missing is a live payload to write the transformation against.
  `/CLR/CL_EINV_ELT_AP_UTIL` in the drop is the reference implementation of the
  write side — `save_document`, `delete_document`, `iso_to_sap_unit`,
  `subject_code_from_note`, `fill_keys` — and it has not been ported, because
  porting a loader with no payload to load is guesswork of a different kind.
- **The self-billed variant is inferred.** Only the AP drop was supplied. The
  two are the same UBL document read from the other side and the HANA originals
  were byte-identical, so `ZTEDOC_SB*` is generated from the same structure —
  but the XPath comments are accurate for AP and assumed for self-billing.
  Verify them against a self-billed payload before relying on the mapping.
  `UNIT_ISO` / `UNIT_SAP` is the one place the two could legitimately differ.
- **`SBDH_COUNTRY` and the country handler.** The header now carries the SBDH
  country, which is the natural input to `ZCL_EINV_COUNTRY_FACTORY`. Nothing
  reads it yet; the factory is still driven by company code.

### 13.7 Three defects found reviewing the generated stack

Each is now a checker rule, and each was self-tested by re-introducing it.

1. **`instance feature control action X;` is not behaviour-definition syntax.**
   It reads like the SAP documentation but it is prose, not BDL: feature control
   is a characteristic of the operation, written
   `action ( features : instance ) X ...`. As a standalone statement it is both
   an unknown statement and a second declaration of the action. The first
   conversion had it five times in the sales business object as well, which
   means `ZCDS_INT_EINV_DOC` would not have activated either. Fixed in both.
   Rule 21.
2. **A projection navigated `_SellerParty` and `_BuyerParty`, which did not
   exist.** A projection view can only follow an association the projected
   entity exposes. The two filtered associations are now declared on the
   interface view. Rule 22 catches any path expression over an association the
   view and its base do not have.
3. **`ENTITY edocument BY _Party` was missing its backslash.** EML navigates by
   `BY \_Party`. Rule 23.

---

## 14. First activation, 2026-10-01

Worklist `CB9980000060`. The 16 e-document tables and both root interface
views (`ZCDS_INT_EDOC_APH`, `ZCDS_INT_EDOC_SBH`) activated — the model itself
is sound. Everything else that failed came back to six causes; the rest of the
log was cascade.

Each is now a checker rule, self-tested by re-introducing the defect. The
checkers carry 28 rules.

### 14.1 `LABEL` is a CDS reserved word

`ZCDS_INT_EINV_CONST` aliased `zlabel as Label`. The element is now
`LabelCode`; the column, the `@EndUserText.label` and the UI label are
unchanged, so nothing else moves. Rule 25 carries the reserved-word list.

### 14.2 `@EndUserText.label` is typed `STRING(40)`

51 labels were longer. The e-document ones came straight from the mapping
workbook, where a description like *"Payment card primary account number,
masked (BT-87)"* is 50 characters.

Truncating from the right would throw away the BT code, which is the part
worth keeping, so `lab40( )` cuts the prose and keeps the code:

    Payment card primary account number, masked (BT-87)
    -> Payment card primary account numbe (BT-87)

It also refuses to leave a dangling `(`. The cap is applied in the one function
that writes the annotation rather than trusted to whoever writes the spec.
Rule 24.

### 14.3 Two released-view elements do not exist in this release

Both were on the "verify in ADT" list in §7, and both are now resolved by
removal rather than by a second guess.

**`I_JournalEntry-CreatedByUser`.** Dropped from `ZCDS_INT_EINV_REL_JRNL` and
`ZCDS_INT_EINV_RELEVANT`. Nothing consumed it: `get_data` took `ir_user` as a
selection-screen parameter, and the pick-up action does not offer one.

**`I_BillingDocument-CancellationStatus`.** The whole `_Billing` association is
gone from `ZCDS_INT_EINV_DOC_ENR`. The submission guard now reads

```abap
      IF ls_enr-IsReversed = abap_true OR ls_enr-IsReversal = abap_true.
```

which loses nothing in practice: cancelling a billing document posts an FI
reversal, and `I_JournalEntry-IsReversed` reports that. `IsReversed` and
`IsReversal` are confirmed good — the same activation accepted both.

If you want the billing flag as well, confirm the element name in ADT
(`BillingDocumentIsCancelled` is the likely one) and the comment in
`ZCDS_INT_EINV_DOC_ENR` has the two lines to add back.

`I_BillingDocument-BillingDocumentType` in `ZCDS_INT_EINV_RELEVANT` is the one
released element still unverified — that view never got checked, because
`REL_JRNL` failed first.

### 14.4 Key elements must be contiguous and start at position one

The flat views put `key h.Uuid` first and `key i.LineId` eighty columns later,
where the line fields begin. Both keys are now emitted first and the rest
follows in table order. Rule 26.

### 14.5 `SELECT *` is not permitted in a view entity

`ZCDS_CUN_EDOC_APFLAT` was `{ * }`. It now lists all 140 elements, which is
also the only place the currency and unit references can be restated for the
consumption layer — so the `@Metadata.ignorePropagatedAnnotations: false`
workaround that was there for the `*` is gone too. Rule 27.

### 14.6 The provider contract belongs to the root projection only

> Provider contract not modifiable if view contains "REDIRECTED TO PARENT"
> associations

Every projection had `provider contract transactional_query`. Only the root
may: a child inherits it, and declaring it on a view that also carries
`redirected to parent` is rejected. Removed from all fourteen e-document child
projections and from `ZCDS_CUN_EINV_DOC_ERR` / `_STAT`. Rule 28 catches the
contract where it does not belong; rule 14, which requires it, now skips views
with a to-parent association.

### 14.7 What the checker could not have caught

Rules 24 to 28 would have caught five of the six before the transport. The
sixth — §14.3 — could not be: whether `I_JournalEntry` has a `CreatedByUser`
element is a fact about the tenant's release, not about the source, and no
static check over this repository can know it. That is what the "verify in ADT"
list in §7 is for, and it did its job: both failures were already on it.

---

## 15. Second activation, 2026-10-01 10:08

Everything DDIC activated — 95 domains, 223 data elements, all 16 e-document
tables, every structure and table type. So did every interface view, every
configuration view, every value help, both flat interface views and
`ZCDS_INT_EINV_DOC`. §14's six fixes all held.

Two errors left, both about what ABAP Cloud permits rather than about the
model.

### 15.1 `@ObjectModel.virtualElement` is not released for ABAP Cloud

> Use of Annotation 'OBJECTMODEL.VIRTUALELEMENT' is not permitted (not released)

The status criticality was a virtual element in three consumption views, backed
by `ZCL_EINV_VE_CRITICALITY` and `ZCL_EINV_VE_EDOC_CRIT` through
`if_sadl_exit_calc_element_read`. That whole mechanism is classic-ABAP; it is
not released here.

It is now a `CASE` in the enrichment view beside each business object, reached
by a `[1..1]` association and exposed on the projection as a path expression:

```abap
      case upper( coalesce( _Exchange.PaExchangeStatus,
                            coalesce( _Async.SyncStatus, status ) ) )
        when 'VALID'     then 3
        ...
      end  as StatusCriticality
```

Three things get better rather than worse:

- it is **filterable and sortable**, which a virtual element never was;
- the two VE classes are gone, and with them the `CORRESPONDING #( )` against
  a generically typed `CHANGING` parameter that CODE_REVIEW.md §4 could not
  settle without a compiler;
- `ZCDS_INT_EDOC_APENR` / `ZCDS_INT_EDOC_SBENR` now exist as the place for any
  further derived value on the e-document side, mirroring
  `ZCDS_INT_EINV_DOC_ENR` on the sales side.

What is lost: `ZCL_EINV_CONFIG~get_criticality` no longer wins over the default
mapping in the UI. `ZTEINV_STATUS` is keyed on
`(PROJECTID, SYSID, LAND1, BUKRS, SEQUENCE, PROC_MODE)` with `STATUS` as a
plain attribute, so it cannot be joined on the status alone without fanning
out. The ABAP callers still consult it. If the configured mapping has to drive
the colour too, the way in is a grouping view over `ZTEINV_STATUS` keyed on
status — worth doing only once there is real content in that table. Rule 29.

### 15.2 A projection view must belong to a business object

> Transactional Projection View must be part of a business object

`ZCDS_CUN_EDOC_APFLAT` and `_SBFLAT` were written `as projection on` so their
elements could be listed one by one (§14.5). But `as projection on` makes a
view a projection whether or not it declares a contract, and a projection needs
a behaviour definition. They are query views with no transactional behaviour,
so they are now `as select from`. Rule 30.

### 15.3 Warnings, and what was done about them

**Output length.** Fourteen numeric domains warned *"Output length (n) is less
than the calculated output length (m)"* — the generators were writing
`OUTPUTLEN = LENG`. DDIC's own formula is integer digits, plus a thousands
separator every three, plus the decimal point and the decimals; `INT4` is
length plus one for the sign, `DATS` is 10 and `TIMS` is 8. The generators now
compute it, and every value matches what the activation reported. Warnings
only, but a log you can read is worth more than a log you skim.

`ZDO_EINV_URL` still warns that its output length of 300 exceeds the 255-column
dynpro maximum. There are no dynpros in Public Cloud and the URL field is
genuinely that long; capping it would only trade one warning for another.

**Key type.** `ZTEDOC_APH`, `ZTEDOC_SBH` and `ZTEINV_RUN` warn *"Key must have
the type Inverted Individual on the database"* — their keys are a 50- or
100-character UUID. The tables activated. Set it in ADT under the table's
technical settings (Key type → Inverted individual) rather than from the
repository: the serialized form of that attribute is not something to guess at.

### 15.4 Where the checker stands

30 rules. Of the eight distinct activation failures across the two rounds,
seven are now caught statically. The eighth — whether `I_JournalEntry` has a
`CreatedByUser` element — is a fact about the tenant's release that no check
over this repository can know.

---

## 16. Third activation, 2026-10-01 — the ABAP and behaviour layer

The DDIC and CDS layers are clean. This round reached the behaviour
definitions and the classes, and found seven things in this package. Five are
now checker rules; the other two are a type match and a parameter-name length
that no rule over this repository could settle cheaply.

### 16.1 `field ( ... )` is a statement of its own in a projection

> "action | association | create | delete | event | function | key | update"
> was expected, not "field".

Only those eight may follow `use`. A field characteristic is written without
it:

```abap
  use update;
  use association _Document;
  field ( readonly ) DocumentNumber, Quantity, ...;
```

All fourteen e-document child projections had `use field ( readonly )`.
Rule 31.

### 16.2 A to-parent association has to be declared by the child

> The association "_Document" must be included in the behavior definition of
> entity "ZCDS_INT_EDOC_API", since it is a "to parent" association.
> …must be exposed publicly by the behavior definition…

§14.6 removed `use association _Document` from the child projections because
the base did not declare it. That was the wrong half to remove: RAP requires a
to-parent association to be declared by the child **and** exposed on its
projection, whether or not anything navigates it. Both are back, in both the
e-document children and `ZCDS_INT_EINV_DOC_ERR` / `_STAT`. Rule 32 ties the two
together: a child that is `lock dependent by _X` must declare
`association _X;`.

### 16.3 Key fields want `readonly : update`

> The key field "UUID" should be flagged as "readonly" or "readonly:update".

CODE_REVIEW.md §2.15 took key fields out of the readonly lists because the
unconditional `field ( readonly )` also blocks them on create. That part stands
— but the right answer was the qualified form, not silence:

```abap
  field ( readonly : update ) Uuid, LineId;
```

The key is fixed once the row exists, and a loader can still supply it on
create. Added to every e-document entity and to the sales business object and
its two children. Checker rule 16 still rejects the unconditional form on a
key, which is the one that breaks create.

### 16.4 An APJ parameter name is `CHAR 8`

> "P_MAXROWS" is not an admissible value for type "C(8)". Admissible: P_MAXROW.

`P_MAXROWS`, `P_BUDAT_F`, `P_BUDAT_T`, `P_CPUDT_F`, `P_CPUDT_T` are all nine
characters, so four job classes failed and took their job catalog entries down
with them — which is where most of this log's "class does not exist" noise came
from. Renamed to `P_MAXROW`, `P_BUDATF`, `P_BUDATT`, `P_CPUDTF`, `P_CPUDTT`.
Rule 33.

### 16.5 `COND string #( )` is two syntaxes at once

> Field "COND" is unknown.

Either `COND #( ... )`, which infers the type from the target, or
`COND string( ... )`, which states it. Not both. Rule 34.

### 16.6 A derived RAP type cannot be a RETURNING parameter

> "CREATE ZCDS_INT_EINV_DOC RETURNING" is not valid.

`ZCL_EINV_WORKLIST~filter_existing` returned a `TABLE FOR CREATE`. It now
filters in place with a `CHANGING` parameter, and both callers were adjusted.
Rule 35.

### 16.7 `FOR ALL ENTRIES` compares column to column

> …the fields "DOCUMENTNUMBER" and "LT_NO-TABLE_LINE" must have the same type
> and the same length.

The driver table in `ZCL_EINV_EDOC_FETCH~existing_documents` was a
`STRING_TABLE` against a `CHAR 50` column. It is now
`STANDARD TABLE OF zde_elt_docno`. Not a rule: catching it statically means
resolving the type of every selected column, which is the compiler's job.

### 16.8 One edit to inherited source

`ZSD_ELT_CONFIG` ships a 42-character `@EndUserText.label`, which stops it
activating. Everything inherited from `ZZCLR_ELT` is otherwise copied byte for
byte, but an object that will not activate blocks the import, so `merge.py`
now caps any over-long label it finds in the inherited files and says how many
it capped. Three were.

### 16.9 Inherited problems left alone

These are in code copied verbatim from `ZZCLR_ELT` and are listed so nobody
spends an afternoon looking for them in the conversion:

| | |
|---|---|
`ZCDS_INT_EVENT_LOG` | ten unmapped fields and four unmapped key fields — the behaviour definition has no `mapping for` block at all |
`ZBP_CDS_INT_ELT_CONFIG` | `Component "SYSID" multiply specified by named include via "%TKY"` |
`ZCL_ELT` | a `TRY` with no `CATCH` at line 1383; `STRING` for the generic `CSEQUENCE`; ~25 redundant conversions |
`ZCL_INSTRU_EXEC`, `ZCL_INSTRU_EVENT_CLASS` | `sy-datum` / `sy-uzeit` in the current language version; deprecated data element `FLAG` |
`ZCDS_*_COMP_DETAILS`, `ZCDS_INT_ELT_CONFIG`, `ZCDS_INT_INS_CONFIG`, `ZCDS_INT_EVENT_LOG` | `create` and `ping` without global authorization; key fields not flagged readonly |
`ZLPP_ELT_CONFIG`, `ZLPP_EVENT_LOG` | referenced LADI not found, section title initial |

`The field SUBC of the TRDIR entry … contains the incorrect value 'B'` appears
against every behaviour definition in the package, inherited and new alike. It
is an artifact of how the BDEF arrives through abapGit rather than anything in
the source.

### 16.10 Where the checker stands

35 rules. Of the thirteen distinct failures across three activation rounds,
eleven are caught statically. The two that are not are both facts the tenant
knows and the repository does not: whether a released view has a given element,
and whether two DDIC types match in length.


## 17. Fourth activation, 2026-10-01 — the inherited configuration layer

The third round's fixes all landed; this round's log is a different list. What
it exposed was a blind spot rather than a new defect class: everything that
broke here came from the **configuration package merged in from `ZZCLR_ELT`**,
or from RAP derived types crossing a method signature. The checker had seen
most of it and reported it as *advisory*, because the file was inherited
verbatim and inherited code "activates in the customer tenant today". It
activated on HANA. That is not the same sentence.

### 17.1 `ZCDS_INT_EVENT_LOG` had no `mapping for` block

Thirteen errors, one cause. The behaviour definition declared
`persistent table ztevent_log` and no mapping, so RAP matched element names to
column names one for one. Ten elements are CamelCase over a snake_case column
(`WorkflowId`/`workflow_id`, `DocCount`/`doc_count`, `SendErrorReason`/
`send_error_reason`, …) and three of those are keys, so nothing resolved.

Rule 11 had flagged it. It was filed under "inherited, advisory" and shipped.
`add()` in `check_merged.py` now downgrades only the two families the tenant
has actually been observed to tolerate — `non-released construct` and
`is a CDS reserved word`. Everything else is a problem wherever it came from.

### 17.2 A derived RAP type cannot cross a method declaration

Three failures, one root:

| Object | Reported as |
|---|---|
`ZBP_CDS_INT_EDOC_APH` / `_SBH` | `"ACTION IMPORT" is not valid` |
`ZBP_CDS_INT_EINV_DOC` | `A RETURNING parameter must be fully typed` |
`ZCL_EINV_WORKLIST` | `The statement before "CREATE ..." was not closed` |

`TYPE TABLE FOR …` in a method **body** is fine: the class is compiled after
the behaviour definition. In the **declaration part** it is not, and the
compiler's complaint is whatever the parser hit when the type failed to
resolve. Three different fixes, one principle — the signature no longer names
a derived type:

- `read_parties` is gone from both e-document handlers; its four lines are
  inlined into `sendaction`, which already has `keys` in the right shape.
- `read_documents` became `EXPORTING` instead of `RETURNING`. A derived type
  on a RETURNING parameter is forbidden outright, whatever the activation
  order; this is the §16.9 lesson applying to `TABLE FOR READ RESULT` as
  well, which the checker had explicitly excluded.
- `filter_existing` became `keep_new`, which takes and returns four plain key
  fields. `ZCL_EINV_WORKLIST` is not a behaviour pool, so it has no business
  depending on a behaviour definition's activation state at all.

### 17.3 `ZCL_ELT`: a 263-line `TRY` with no handler

`TRY.` at line 1120, `ENDTRY.` at line 1383, nothing in between. Everything
inside is dynamic — `describe_by_name`, a `?=` cast to a structure descriptor,
`cl_abap_tabledescr=>create`, a fully dynamic `SELECT` — so one bad column name
from a caller takes the whole pull down. Now caught, logged through the
existing instrumentation, and `gt_table` cleared.

### 17.4 `ZCDS_INT_ELT_CONFIG`: a determination that could never have worked

`updsysid` read the row and, when `Sysid` was blank, wrote back

```abap
MODIFY ... UPDATE FIELDS ( Sysid )
  WITH VALUE #( ( %tky = <row>-%tky  Sysid = 'CXS' ) )
```

which the tenant rejects with *Component SYSID multiply specified by named
include via %TKY*. `Sysid` is one of the four key fields, so `%tky` already
carries it. Removing the duplicate would not have helped: RAP does not let a
determination change a key field at all. Determination, handler method and
BDEF declaration are all removed, with a comment where they were. **A default
for `Sysid` has to move to the create payload** — a UI default value, or
`cl_abap_context_info=>get_system_id( )` in whatever creates the row. This is
the one behaviour change in this round; it is a behaviour that never ran.

### 17.5 Authorization and readonly keys on the five configuration BOs

Four handlers had an **empty `get_instance_authorizations`** — the §12 defect,
in the files the code review did not cover because they came from the other
package. An empty RESULT denies every operation on every row. `ZCDS_CUN_COMP_DETAILS`
also had an empty `get_global_features`, which is why the Ping button did
nothing.

All five now carry `authorization master ( instance, global )`, a filled
instance handler, a global handler covering `create`, and
`field ( readonly : update )` on every key — the qualified form, never the
unconditional one, which would block the key on create too (§16.7).

### 17.6 Deprecations

`TYPE flag` → `abap_boolean` (8×, `ZCL_INSTRU_EVENT_CLASS`). `sy-datum` /
`sy-uzeit` → `cl_abap_context_info=>get_system_date( )` / `get_system_time( )`
(8×, `ZCL_INSTRU_EVENT_CLASS` and `ZCL_INSTRU_EXEC`, including two
`TYPE RANGE OF sy-datum` which became `RANGE OF d`).

### 17.7 Left alone, deliberately

- **~35 `Redundant conversion for type STRING / VALUE`** in `ZCL_ELT`,
  `ZCL_INSTRU_*` and `ZBP_CDS_CUN_COMP_DETAILS`, and one *fixed type STRING
  used for the generic type CSEQUENCE*. These are warnings; the objects
  activate. Each one needs the operand's declared type confirmed before the
  `CONV` comes off, and a wrong guess turns a warning into a type error. They
  are customer code and they are harmless.
- **`The field SUBC of the TRDIR entry … contains the incorrect value 'B'`**,
  against all 31 behaviour definitions. Unchanged from §16: an artifact of how
  a BDEF arrives through abapGit, not of its content. It clears on
  re-activation once the BDEF's implementation class is active, which is why
  **the activation order in §10 matters** — tables, then CDS, then behaviour
  definitions, then classes.

### 17.8 Where the checker stands

**41 rules.** Six new ones, each self-tested by re-introducing the defect it
was written for:

| Rule | Catches |
|---|---|
36 | a derived RAP type in a method declaration — `ACTION IMPORT` / `FUNCTION IMPORT` anywhere, any derived type outside a behaviour pool |
37 | `"!` ABAP Doc in front of a chained `TYPES:` / `DATA:` / `CONSTANTS:` |
38 | a `TRY` that reaches its `ENDTRY` with no `CATCH` and no `CLEANUP` |
39 | `create` or a static action under `authorization master ( instance )` alone |
40 | a key element that appears in no `field ( readonly … )` list |
41 | `TYPE flag`, `sy-datum`, `sy-uzeit` |

Rule 35 was widened: it excluded `TABLE FOR READ RESULT`, which is precisely
the form this round rejected.

Of the nineteen distinct failures across four activation rounds, seventeen are
now caught statically. The two that are not remain facts only the tenant
knows: whether a released view carries a given element, and whether two DDIC
types match in length.


## 18. Fifth activation, 2026-10-01 — three of my own, one latent

Twelve errors, in three files. Two of them were defects I introduced in §17;
one was a latent defect in `ZCL_EINV_WORKLIST` that only became reachable once
§17 fixed the line above it.

### 18.1 `%%tky` — a generator artifact

Four handlers (`ZBP_CDS_INT_EVENT_LOG`, `_INS_CONFIG`, `_COMP_DETAILS`,
`ZBP_CDS_CUN_COMP_DETAILS`) got their filled `get_instance_authorizations`
from a Python template that doubled the percent signs for `%`-formatting and
was then interpolated as an f-string, so `%%tky` reached the source verbatim.
Mechanical, mine, fixed. **Rule 43** catches any `%%<word>` in ABAP.

### 18.2 A derived RAP type is not accepted in a method declaration at all

§17.2 concluded that `TABLE FOR …` is safe in the declaration part of a
behaviour pool, because there the behaviour definition is active by
construction. That was wrong. `ZBP_CDS_INT_EINV_DOC` line 99 —

```abap
METHODS read_documents
  IMPORTING it_keys TYPE ty_keys
  EXPORTING et_doc  TYPE TABLE FOR READ RESULT zcds_int_einv_doc.
```

— still failed, with *the statement before "READ ..." was not closed*. Not
RETURNING. Not outside a pool. Not `ACTION IMPORT`. The rule is simply:

> A RAP derived type belongs in a method **body**. It may not appear in a
> method declaration, in any parameter position, in any class.

`read_documents` is therefore gone the same way `read_parties` went: its one
`READ ENTITIES` statement is repeated in each of the six actions. **Rule 36**
lost its behaviour-pool exemption.

This is the third correction to a conclusion drawn in an earlier round, and
the pattern is consistent — each time, the earlier conclusion was the
*narrowest* reading of the error the tenant happened to report. The tenant
reports the first thing the parser trips on, not the rule.

### 18.3 `SELECT DISTINCT FROM` — the old word order in the new syntax

```abap
SELECT DISTINCT FROM ZCDS_INT_EINV_RELEVANT
  FIELDS BillingDocument, ...
```

In the `FIELDS` form, `DISTINCT` belongs to the select list, not in front of
`FROM`. The tenant answers *"FROM" is invalid here (due to grammar)* and then
reports every subsequent variable in the method as unknown — six follow-on
errors from one. Now `SELECT FROM … FIELDS DISTINCT …`.

This had been in `select_relevant` since the first conversion and was never
reached: the parser stopped at line 53 (§16, §17.2) every previous round.
**Rule 42** catches the word order.

### 18.4 Where the checker stands

**43 rules**, all self-tested. The three added this round all fire on the
exact text the tenant rejected.


## 19. Sixth activation, 2026-10-01 — inside `ZBP_CDS_INT_EINV_DOC`

All seven errors in one file. The parser is now deep enough into the sales
behaviour pool to read the action handlers, and four of them are real RAP
semantics the earlier rounds never reached.

### 19.1 A determination's `REPORTED` is not an EML `REPORTED`

```abap
reported-einvoice = VALUE #( BASE reported-einvoice ( LINES OF ls_reported-einvoice ) ).
```

*unsuitable for the type … (see long text)*. Inside a determination,
`reported` is `RESPONSE FOR REPORTED EARLY`; the `REPORTED` of an EML `MODIFY`
is the `LATE` form. Two different deep types. The identical line in six action
handlers is fine — there both sides are `LATE` — which is why only line 241
was reported. Now `APPEND CORRESPONDING #( ) ` row by row.

### 19.2 A static action's result row has no `%cid_ref`

`PickUpDocuments` is `static action … result [0..*] $self`. There is no
instance and no triggering key, so the result row carries `%param` and nothing
to point back with. `%cid_ref` removed; the created worklist is returned as a
plain list. `lt_cid_map` stays — it still links a created row's `%cid` back to
the action row for message reporting.

### 19.3 `INDEX INTO` declares its own variable

`DATA lv_idx TYPE i.` and, 63 lines later, `FOR … INDEX INTO lv_idx`. The FOR
expression declares it; the explicit `DATA` is the duplicate. Removed.

### 19.4 The deep action parameter — the one real decision this round

`ZCDS_ABS_EINV_SELLACT` modelled dynpro 0200's editable VAT-split grid as a
composition:

```abap
_VatSplit : composition [0..*] of ZCDS_ABS_EINV_VATSPLIT;
```

The generated `%param` structure does not carry it. `ls_par-_VatSplit` is
*a component that does not exist*, and the four follow-on errors (`LS_SPLIT`
unknown, `ENDLOOP` without `LOOP`, `ENDMETHOD` without `METHOD`) are all that
one line.

**What I changed, and it is a functional change:** the composition is gone and
the parameter now carries four flat rate/amount pairs —
`VatRate1..4` / `VatAmount1..4`. The handler builds `lt_split` from whichever
pairs are filled. `ZCDS_ABS_EINV_VATSPLIT` is deleted.

Four covers standard, reduced, zero and exempt, which is every regime this
add-on has met, and a flat parameter is what a Fiori Elements action dialog
renders natively — a deep one needs a custom fragment regardless. But **it is
a cap where there was none**, and if a seller action ever needs a fifth rate
the right fix is not a fifth pair: model the VAT split as a **child entity of
the business object**, maintained on the object page, and have `SellerAction`
read it with EML. That is unbounded, persisted and auditable. The four pairs
are the cheap version; say the word and the child entity is maybe eight files.

### 19.5 Where the checker stands

**47 rules**, all self-tested.

| Rule | Catches |
|---|---|
44 | `%cid_ref` in the handler of an action the BDEF declares `static` |
45 | a determination or validation copying an EML `REPORTED` with `LINES OF` |
46 | a `composition` in an abstract entity used as an action `parameter` |
47 | a variable declared with `DATA` and again by `INDEX INTO` |

Rules 44, 45 and 47 read method bodies through a new `abap_code()` helper that
strips comments first, so a rule never fires on the comment explaining why the
construct is absent — the same correction rule 24 needed for CDS.


## 20. Seventh activation, 2026-10-01 — one error, no object

```
Job catalog entry  doesn't exist.    VALUE_LABS_ROSHNI_DEV_080_F3Y_EN    Unknown
```

No resource, no line, and an empty name between the two spaces. The empty name
is the whole message: something asked for a job catalog entry and passed
nothing.

The four job templates generated for this conversion wrote

```json
"generalInformation": { "catalogEntry": "ZAJC_EINV_FETCH" }
```

The key is **`catalogName`**. With the wrong spelling the field the tenant
reads is simply absent, so it looks up the empty string and reports a missing
catalog entry with nothing to attach the error to. The two templates inherited
from `ZZCLR_ELT` — `ZAJT_ELT_EXECUTE_COMMAND` and `ZAJT_INSTRU_EXEC`, both of
which activate — are what settled the spelling. Fixed in `gen_wrappers.py`, so
it stays fixed.

The `.sajc.json` catalog entries were right already: `className`, same as the
inherited ones.

### 20.1 Where the checker stands

**48 rules.** Rule 48 walks the APJ chain end to end — every `.sajt.json` must
carry a `catalogName` that exists as a `.sajc.json`, and every `.sajc.json` a
`className` that exists as a class. All three failure modes are self-tested.

This is the class of defect the checker is best at and I was worst at: the
tenant's message named no object, so there was nothing to read. A rule that
simply follows a reference from one file to another would have found it before
the round started.


## 21. The last ten objects

The worklist is down to two launchpad page templates and the eight APJ
objects. Two things about them.

### 21.1 Order within the APJ set

A job template references its catalog entry, and a catalog entry references
its class. So the order is **classes → `ZAJC_*` → `ZAJT_*`**, and activating
the eight together is fine only because the four classes are already active.
If the templates are activated alone against catalog entries that are not yet
active, the result is §20's message again — and it still names no object.

### 21.2 `ZLPP_ELT_CONFIG` pointed at a tile that does not exist

Found while looking at the remaining worklist, not reported by the tenant yet.
A launchpad page template names the tile it shows as `{ladiId, tileId}`, and
the tile id is a platform-generated hash:

| | asks for | the descriptor declares |
|---|---|---|
`ZLPP_EVENT_LOG` → `ZEVENT_LOG_UI5R` | `UI5R_B4949049…_AL` | `UI5R_B4949049…_AL` ✓ |
`ZLPP_ELT_CONFIG` → `ZELT_CONFIG_UI5R` | `UI5R_6FF9AD57…_AL` | `UI5R_AC8E883C…_AL` ✗ |

`UI5R_6FF9AD57…` belongs to a deployment of the ELT configuration app in some
other system; nothing in this package declares it. That is the
*referenced LADI not found* warning §16 recorded and I left alone. The page now
points at `UI5R_AC8E883C…_AL`, the tile `ZELT_CONFIG_UI5R` actually declares.

These hashes are regenerated when the app is deployed from BAS, so if the tile
id changes again on deployment, re-point the page — it is one field.

`ZELT_EVENT_LOG_UI5R` is a third app descriptor with no launchpad page of its
own. That is not an error; it is left as it was.

### 21.3 Where the checker stands

**49 rules.** Rule 49 resolves every `.uipg.json` visualization: the `ladiId`
must be a `.uiad.json` in the package and the `tileId` one of the tiles that
descriptor declares. Both failure modes self-tested.

Rules 48 and 49 are the same shape — follow a reference from one file to
another and check it lands. Between them they cover the descriptor layer,
which is where the errors name no object and are hardest to trace.


## 22. The job templates, still empty — and what I am not going to guess again

The four `ZAJT_EINV_*` templates still fail, and the ADT editor shows why:
**Job Catalog Entry is blank.** Not "wrong", not "unresolved" — empty. Whatever
the tenant stored when it imported those files, it is not the catalog entry
name, which is why the message has never had a name in it.

### 22.1 What the evidence does and does not support

`catalogEntry` was wrong (§20). `catalogName` is what the two inherited
templates carry, and it did not help. Those two prove less than I assumed:
`ZAJT_ELT_EXECUTE_COMMAND` and `ZAJT_INSTRU_EXEC` were **already active in this
tenant from the earlier ZZCLR_ELT installation**, so their runtime state was
never built from the JSON in this repository. They can look healthy in ADT
while telling us nothing about what the deserializer reads.

So I have guessed this key twice and I am not guessing a third time. The
tenant can answer it directly, and the answer is one round-trip (§22.3).

### 22.2 The catalog entries are not the problem

Each of the four resolves to a class that exists and implements both
`if_apj_dt_exec_object` and `if_apj_rt_exec_object`, and
`get_parameters` fills `et_parameter_def` and `et_parameter_val` correctly.
Nothing in the Problems view is about them.

The four `.sajc.json` files did carry a `sections` / `groups` / `parameters`
block that `ZAJC_ELT_EXECUTE_COMMAND` does not. That block turned out to be
legitimate — `ZAJC_INSTRU_EXEC`, also inherited, has one — but it is not doing
any work here, because the selection screen comes from the class's
`get_parameters` at runtime. Removed, so the four files are now byte-for-byte
the shape of the simplest entry known to work.

### 22.3 The one test that settles it

In ADT, on any one of the four templates:

1. Type the catalog entry name into the **Job Catalog Entry** field
   (`ZAJC_EINV_SUBMIT` for `ZAJT_EINV_SUBMIT`).
2. Save and activate.
3. In abapGit, stage the repository and look at the diff for
   `zajt_einv_submit.sajt.json`.

That diff is the tenant telling us, in its own serialization, what the key is
called. Whatever it says goes into `sajt()` in `gen_wrappers.py` and the other
three regenerate from it.

If filling the field by hand is quicker than waiting for me, do all four — it
is one field each, and pushing afterwards corrects the repository too.


## 23. The job catalog entries were never registered

The package tree in ADT says what the error list could not. Under *Identity
and Access Management*: **Business Catalogs (4)** — `ZBC_ELT_CONFIG`,
`ZBC_ELT_EXECUTE_COMMAND_JOB`, `ZBC_EVENT_LOG`, `ZBC_INSTRU_EXECUTE` — and
**IAM Apps (4)**. All four of each are the ones inherited from `ZZCLR_ELT`.
Nothing in that tree belongs to the four e-invoice jobs.

An application job catalog entry is not reachable by name just because the
object exists. It has to be registered as an **IAM app of type `SAJC`**, and
the inherited jobs each have one:

```
zajc_elt_execute_command_sajc.sia6.xml   APP_TYPE SAJC  SECONDARY_ID ZAJC_ELT_EXECUTE_COMMAND
zajc_instru_exec_sajc.sia6.xml           APP_TYPE SAJC  SECONDARY_ID ZAJC_INSTRU_EXEC
```

The four generated for this conversion had none. That is a far better
explanation of an empty *Job Catalog Entry* field than a misspelled JSON key:
the template names an entry the tenant has no registration for, resolves
nothing, and reports the empty name it ended up with.

### 23.1 What is now in the package

`gen_wrappers.py` writes the four missing registrations —
`ZAJC_EINV_PICKUP_SAJC`, `ZAJC_EINV_SUBMIT_SAJC`, `ZAJC_EINV_STATUS_SAJC`,
`ZAJC_EINV_FETCH_SAJC`. The file is fully determined: `APP_TYPE SAJC`,
`SECONDARY_ID` the catalog entry, no platform hash anywhere.

### 23.2 What still has to be done in ADT

The **business catalog** cannot be generated. `ZBC_ELT_EXECUTE_COMMAND_JOB`
carries a `CHIP_ID`:

```
X-SAP-UI2-PAGE:X-SAP-UI2-CATALOGPAGE:ZBC_ELT_EXECUTE_COMMAND_JOB:3WO8ZLI358ZZTJXFZ8TCR8ZX3
```

The trailing token is generated when the catalog is created, so writing the
file by hand produces a catalog the launchpad cannot render. Create one
business catalog in ADT for the e-invoice jobs — modelling it on
`ZBC_ELT_EXECUTE_COMMAND_JOB`, which holds exactly one job — and assign the
four IAM apps to it. Until that exists the jobs can be activated but nobody
can schedule them from the launchpad.

This is the same boundary §7 drew for the Fiori apps, and the tree confirms
that side too: *Fiori User Interface (0)*. The four Fiori Elements apps are
still to be built in BAS.

### 23.3 The order, and why re-pulling may not be enough

classes → `ZAJC_*` → `ZAJC_*_SAJC` → `ZAJT_*`.

abapGit imports a file only when its content has changed. A template whose
reference was stored empty on an earlier pull keeps that empty reference
through every later pull of an identical file. So after this pull, if a
template is still empty, type the catalog entry into the field in ADT and
activate — that rewrites the stored reference directly.

That also settles the question §22 left open. After filling the field and
activating, stage the repository in abapGit:

- **no diff** on `zajt_einv_submit.sajt.json` → the JSON was right all along
  and the problem was registration and import caching, as §23 argues;
- **a diff** → the serialized key differs from `catalogName`, and the diff
  says what it is.

### 23.4 Where the checker stands

**50 rules.** Rule 50 requires every `.sajc.json` to have a matching
`.sia6.xml` with `APP_TYPE SAJC` and the catalog entry as `SECONDARY_ID`.


## 24. Publishing the service bindings

The ABAP and CDS layers are through — 441 dictionary objects, 158 CDS, 16
business services, all eight bindings and all eight definitions in the tree.
What fails now is the publish:

```
Inbound service ZSB_EDOC_AP_0001_G4BA does not exist
Local Publish of ZSB_EDOC_AP failed
```

### 24.1 The binding claimed to be published

Every generated `.srvb.xml` ended with

```xml
<PUBLISHED>true</PUBLISHED>
<BINDING_CREATED>true</BINDING_CREATED>
```

copied from the inherited bindings, where it is true. Those two flags say *the
inbound service that backs this endpoint already exists*. For the inherited
bindings it does, and it ships beside them — `zsb_event_log_iwsg.sco2.xml`,
`zsb_elt_config_iwsg.sco2.xml`. For the six generated here, nothing ever
created one, so the tenant goes looking for an inbound service by the name it
would have had and reports that it does not exist.

Both flags are now `false` in `gen_wrappers.py` and `gen_apx.py`. A binding
arriving from a repository has not been published in the tenant it arrives in;
publishing is what creates the endpoint.

### 24.2 Why the inbound service cannot simply ship

The inherited bindings are **OData V2**, and a V2 inbound service is fully
determined — `IBS_ID` `<binding>_IWSG`, `IBS_TYPE` `IWSG`,
`ODATA_SRV_IDENTIFIER` `<binding>_0001`, no hash. That is why those two could
be exported and re-imported.

The six here are **OData V4 - UI**, which is correct for RAP and Fiori
Elements, and the V4 endpoint is a different object — the `_G4BA` in the error
is its type, not a random suffix. It is created by Local Publish and is not
something to write by hand. This is the §7 boundary again, now with a name.

### 24.3 If a binding still will not publish after the pull

The two flags are stored on the binding when it is imported, so a binding that
already arrived claiming `PUBLISHED` may keep that state. Two ways out, in
order of preference:

1. Pull, then **Local Publish** again. The corrected flags should let ADT
   create the endpoint.
2. If it still refuses: delete the binding object in ADT and recreate it over
   its service definition (right-click the service definition → *New Service
   Binding*, OData V4 - UI). About thirty seconds each, six bindings, and it
   produces the endpoint the way the tenant expects. Afterwards push, so the
   repository carries whatever ADT wrote.

### 24.4 Where the checker stands

**51 rules.** Rule 51 refuses a `.srvb.xml` that claims `PUBLISHED true`
without an inbound service shipping alongside it.


## 25. The launchpad layer comes out of the repository

Five files deleted, on the principle that an object carrying a
platform-generated identifier belongs to the system that generated it:

| Removed | What it was |
|---|---|
`zelt_config_ui5r.uiad.json` | launchpad app descriptor item for the ELT configuration app |
`zelt_event_log_ui5r.uiad.json` | LADI for the ELT event log app |
`zevent_log_ui5r.uiad.json` | LADI for the event log app |
`zlpp_elt_config.uipg.json` | launchpad page template for the ELT configuration |
`zlpp_event_log.uipg.json` | launchpad page template for the event log |

Both kinds are regenerated when the Fiori apps are deployed from BAS. Keeping
them in the repository only ever produced stale cross-references: §21.2 was
exactly that — `ZLPP_ELT_CONFIG` naming tile
`UI5R_6FF9AD57…_AL` while the descriptor beside it declared
`UI5R_AC8E883C…_AL`, a hash from whichever system the page had last been
exported from. There is no way to keep a generated hash correct by hand across
two systems, so the right place for these files is nowhere.

The pages went with the descriptors because a page template has no content of
its own: it is a reference to a descriptor and a tile id inside it. A page
without its descriptor cannot activate.

### 25.1 What now dangles, deliberately

Three IAM apps still name a UI app that is no longer in the repository:

```
ZIAM_ELT_CONFIG_EXT        UI_APP_ID  ZELT_CONFIG_UI5R
ZIAM_EVENT_LOG_EXT         UI_APP_ID  ZEVENT_LOG_UI5R
ZSB_ELT_CONFIG_IWSG_EXT    UI_APP_ID  ZELT_CONFIG_UI5R
ZSB_EVENT_LOG_IWSG_EXT     UI_APP_ID  ZELT_EVENT_LOG_UI5R
```

and the two business catalogs `ZBC_ELT_CONFIG` and `ZBC_EVENT_LOG` assign
those IAM apps. They stay: they are the ELT configuration and event log
launchpad setup that already works in the customer tenant, and the
descriptors they point at already exist *there*. The dangling reference is a
property of the repository, not of the tenant, and it resolves again the
moment the apps are deployed.

That is also why no checker rule was added for it. Rule 49 still checks any
`.uipg.json` that reappears, and finds none; a rule firing on the intended
state would be noise.

### 25.2 Order, restated

Everything that carries a generated identifier is now created in the tenant,
not imported into it:

| Object | Created by |
|---|---|
OData V4 endpoint (`_G4BA`) | Local Publish of the service binding (§24) |
Business catalog for the four jobs | ADT, because of the `CHIP_ID` (§23.2) |
Launchpad app descriptor items | BAS, on deploying the Fiori app |
Launchpad page templates | BAS, same |
Fiori Elements apps | BAS (§7) |

The repository carries the ABAP, the CDS, the behaviour, the services, the
jobs and the IAM app registrations — everything that is fully determined by
its own content.


## 26. A service binding is four objects, not one

§24 was wrong, or at least not the whole answer. The flags are now `false` —
ADT agrees, the panel says *service endpoint is not published* — and Local
Publish still fails the same way, on `ZSB_EINV_CONFIG` as on `ZSB_EDOC_AP`.

The package says why. What ships for a binding that works:

```
zsb_elt_config.srvb.xml            the binding
zsb_elt_config_iwsg.sco2.xml       the inbound service
zsb_elt_config_iwsg_ibs.sia6.xml   IAM app for the inbound service
zsb_elt_config_iwsg_ext.sia6.xml   IAM app extension
```

What ships for each of the six generated here:

```
zsb_edoc_ap.srvb.xml
```

One object out of four. The `.srvb.xml` was written by analogy with the two
inherited V2 bindings, and the analogy only reached as far as the file I could
see. The other three are created when the binding is published — for V2 they
are the `_IWSG` set above, for OData V4 - UI they are the `_G4BA` objects the
error names. Setting `PUBLISHED` to false was right and changed nothing,
because the problem was never the flag.

I am not going to invent the missing three. That is the same trap as the job
template key in §22: authoring a platform object from a half-seen example,
twice.

### 26.1 What to do

Per binding, in ADT:

1. Delete the binding object.
2. Right-click its service definition → *New Service Binding*, OData V4 - UI,
   same name.
3. Publish.
4. Push.

Step 4 is the one that matters beyond this tenant: abapGit then serializes the
binding **and its three companions** into the repository, and the next
installation gets a set that publishes. Six bindings — `ZSB_EDOC_AP`,
`ZSB_EDOC_APFLAT`, `ZSB_EDOC_SB`, `ZSB_EDOC_SBFLAT`, `ZSB_EINV_CONFIG`,
`ZSB_EINV_DOC` — over the six `ZSD_*` service definitions, which are ordinary
source and are already active.

Doing one first and pushing is enough for me to correct the generator for the
other five, if that is preferable to doing all six by hand.

The six `.srvb.xml` files are left in the repository for now. They carry the
right name, description, binding type and service definition reference, so
they are a starting point rather than an obstacle; say the word and they come
out, on the same principle as §25.

### 26.2 No new checker rule

A rule that refuses a `.srvb.xml` without its companions would fire on all six
right now, which is the intended state until they are recreated. Same reason
§25.1 added none for the dangling launchpad references: a rule that fires on
the state you meant to be in is noise, not a check. The checker stays at
**51 rules**.


## 27. OData V2, and the one thing that had to change for it

The V2 binding wizard refused the sales service:

```
Result Cardinality '[0..*]' of Action 'PICKUPDOCUMENTS'
of Entity 'ZCDS_CUN_EINV_DOC' is not supported
```

and the same dialog carries SAP's own guidance, which settles the V2/V4
question for this package:

> If you're using the implementation type managed without draft and you want
> to use Fiori Elements, you use OData V2 to expose your service. In all other
> scenarios, OData V4 is strongly recommended.

Every business object here is **managed without draft** — §13 and the comment
at the top of `ZCDS_INT_EINV_DOC` explain why a draft store would have been
three shadow tables for nothing. So V2 is not a retreat from V4; it is the
exposure this design asked for, and choosing V4 was my mistake.

### 27.1 `PickUpDocuments` gives up its result

OData V2 has no concept of an action returning a collection. One action in the
package did:

```abap
static action PickUpDocuments parameter ZCDS_ABS_EINV_PICKUP result [0..*] $self;
```

It now returns nothing. The handler loses its `RESULT` parameter and the
read-back that filled it — twenty lines that re-read the rows it had just
created.

Nothing is lost in the cockpit. The rows are on the database, the messages are
in `REPORTED`, and the list report refreshes onto them; the result table was
only ever a way of handing the same rows back a second time.

Every other action is `result [1] $self`, which V2 supports: `SubmitEInvoice`,
`RefreshStatus`, `RequestPrintout`, `SellerAction`, `CancelEInvoice`, and
`SendAction` on both e-document business objects.

### 27.2 Nothing else had to move

The annotation set was already V2 territory — `@UI.facet` (`#STANDARD`,
`#IDENTIFICATION_REFERENCE`, `#LINEITEM_REFERENCE`, `#FOR_ACTION`),
`@UI.lineItem` with `dataAction` and `criticality`, `@UI.selectionField`,
`@UI.hidden`, `@Consumption.semanticObject`, `@Consumption.valueHelpDefinition`,
`@Search.*`. No `@Analytics`, no `@UI.chart`, no aggregation. The
`@ObjectModel.virtualElement` that would have been a problem went in §15 for
an unrelated reason.

`BIND_TYPE_VERSION` is now `V2` in both generators, so the repository matches
what you build in ADT.

### 27.3 What V2 costs

- The Fiori Elements apps are built from the **V2** List Report / Object Page
  template in BAS, not the V4 one.
- The two flat *All Data Query* services lose `$apply` aggregation pushdown.
  They still query; grouping and totals happen client-side.
- A V2 binding ships as four objects the same way the inherited ones do
  (§26), which is the incidental benefit: once created and pushed, the whole
  set round-trips through abapGit.

### 27.4 Where the checker stands

**52 rules.** Rule 52 refuses any action whose `result` cardinality contains
`*`, which is the V2 restriction stated as a repository check.


## 28. Two empty tables the app generator exposed

The generated page map for `ZSD_EINV_DOC` is right:

```
ListReport_EInvoice  ->  ObjectPage_EInvoice  ->  ObjectPage_EInvoiceError
```

and it showed up a gap nothing in the repository could see. The object page
has three facets (§19 design): an identification block and two
`#LINEITEM_REFERENCE` tables onto `_Exchange` and `_Error`. Fiori Elements
renders such a facet from the **child entity's own** `@UI.lineItem` — and
neither child had any.

`ZCDS_CUN_EINV_DOC_ERR` and `ZCDS_CUN_EINV_DOC_STAT` had no metadata
extension at all. The AP and self-billed sides have one per child
(`zcds_met_edoc_api`, `_app`, `_apt`, `_apa`, `_apn`, `_apr`, `_apx` and the
seven `_sb*` twins) because `gen_apx.py` writes them. The sales cockpit's
children are hand-written, and they were simply never written.

The result would have been an app that generates, activates, deploys and
opens — with two tables on the object page and no columns in either. And
`ObjectPage_EInvoiceError`, which the generator creates from the `_Error`
facet, would have been blank.

### 28.1 What was added

`ZCDS_MET_EINV_DOC_ERR` — six columns: number, date, time, code, source,
message. The HANA cockpit concatenated these into one string on the header
row, which is why only the first was ever readable.

`ZCDS_MET_EINV_DOC_STAT` — eight columns across the platform's pipeline:
document id, PA exchange and its message, invoice submission, lifecycle
submission, rejection, refusal, payment; plus the six response messages in
the identification block. The HANA cockpit showed one `STATUS` column on the
header and kept the rest in the API response.

Both carry an `#IDENTIFICATION_REFERENCE` facet, so the sub-object-page the
generator creates has content.

### 28.2 Where the checker stands

**53 rules.** Rule 53 resolves every `#LINEITEM_REFERENCE` facet through the
projection to its interface view, finds the composition or association it
names, follows that to the child's own projection, and requires the child to
carry `@UI.lineItem` somewhere — in the view or in a metadata extension.

This is the first rule aimed at a defect that is invisible in the tenant.
Everything through §27 was something activation or a wizard refused. An empty
table refuses nothing; it activates, deploys and opens, and the first person
to notice is a user.


## 29. The filter bar's labels

The AP cockpit runs. The first thing it shows is a cosmetic defect the
repository could not have reported:

```
Invoice Nu:    Status:    Match Stat:    Issue Date:    Invoice Ty:    Seller:    Buyer:
```

Three labels cut off. The column headers beside them are fine — *Invoice
number (BT-1)*, *Invoice issue date* — because a `@UI.lineItem` carries its
own `label:`. **That label names the column, not the filter.** A filter field
takes its text from the element's `@EndUserText.label`, and with none set
Fiori falls back to the data element's *short* DDIC label, which is ten
characters.

`_SellerParty` and `_BuyerParty` already had explicit labels, which is exactly
why those two render in full and the other five do not.

`gen_apx.py` now writes `@EndUserText.label` beside every
`@UI.selectionField` on both header projections: Invoice Number, Status, Match
Status, Issue Date, Invoice Type. Fourteen annotations, AP and self-billed.

### 29.1 Not a checker rule

A rule could require a label on every `@UI.selectionField`, but it would fire
on any element whose own DDIC label is already right — most of them. The
check that matters is "is the fallback label too long", and the repository
does not know the DDIC short text. This one is caught by opening the app,
which is the correct place to catch it.

### 29.2 The empty list is not a defect

*"Let's get some results — start by providing your search or filter criteria"*
is the normal first state of an OData V2 list report: it does not auto-load.
For a worklist over a document table that is the right default. If an
auto-load is wanted later it is a manifest setting on the generated app
(`initialLoad`), not a backend change.


## 30. The Fiori app inventory

Fifteen apps, each generated from the SAP Fiori generator over a service
binding this package ships. Six names are decided per app. Three of them have
to be right first time: the **module name** is embedded in `package.json`,
`manifest.json` (`sap.app.id`), `ui5.yaml` and the component path, so it
cannot be fixed by renaming the folder; the **SAPUI5 ABAP repository** is the
object that appears in ADT and the only handle `npm run undeploy` has; and
**semantic object + action** must be unique across the tenant.

The repository name is capped at 15 characters, which is why it is not the
module name in upper case.

### 30.1 Cockpits

| Service binding | Main entity | Module name | SAPUI5 ABAP repository | Semantic object | Action | Title |
|---|---|---|---|---|---|---|
`ZSB_EINV_DOC` | `EInvoice` | `zsdeinvdoc` | `ZEINVDOC` | `ZEINV_DOC` | `manage` | Sales e-Invoice Cockpit |
`ZSB_EDOC_AP` | `EDocument` | `zsdedocap` | `ZEDOCAP` | `ZEDOC_AP` | `manage` | Inbound e-Invoice (AP) |
`ZSB_EDOC_SB` | `EDocument` | `zsdedocsb` | `ZEDOCSB` | `ZEDOC_SB` | `manage` | Self-Billed e-Invoice |
`ZSB_EDOC_APFLAT` | `EDocumentData` | `zsdedocapflat` | `ZEDOCAPFLAT` | `ZEDOC_AP` | `display` | Inbound e-Invoice - All Data |
`ZSB_EDOC_SBFLAT` | `EDocumentData` | `zsdedocsbflat` | `ZEDOCSBFLAT` | `ZEDOC_SB` | `display` | Self-Billed - All Data |

A flat app shares its cockpit's semantic object with the action `display`:
the same business object, seen read-only.

### 30.2 Configuration

All ten are `ZSB_EINV_CONFIG` - one service definition, one binding, one
publish. Only the generator answers differ.

| Main entity | Module name | SAPUI5 ABAP repository | Semantic object | Action | Title |
|---|---|---|---|---|---|
`CountryRegistration` | `zsdeinvcntry` | `ZEINVCFGCNTRY` | `ZEINV_COUNTRY` | `maintain` | e-Invoice Country Registration |
`ApiEndpoint` | `zsdeinvapi` | `ZEINVCFGAPI` | `ZEINV_API` | `maintain` | e-Invoice API Endpoints |
`Constant` | `zsdeinvconst` | `ZEINVCFGCONST` | `ZEINV_CONSTANT` | `maintain` | e-Invoice Constants |
`RelevanceMapping` | `zsdeinvinvmap` | `ZEINVCFGMAP` | `ZEINV_RELEVANCE` | `maintain` | e-Invoice Relevance Mapping |
`DocumentType` | `zsdeinvdoctyp` | `ZEINVCFGDOCTYP` | `ZEINV_DOCTYPE` | `maintain` | e-Invoice Document Types |
`StatusMapping` | `zsdeinvstatus` | `ZEINVCFGSTATUS` | `ZEINV_STATUSMAP` | `maintain` | e-Invoice Status Mapping |
`VatRegistration` | `zsdeinvvat` | `ZEINVCFGVAT` | `ZEINV_VAT` | `maintain` | e-Invoice VAT Registration |
`ActionType` | `zsdeinvaction` | `ZEINVCFGACTION` | `ZEINV_ACTIONTYPE` | `maintain` | e-Invoice Action Types |
`ReasonCode` | `zsdeinvreason` | `ZEINVCFGREASON` | `ZEINV_REASON` | `maintain` | e-Invoice Reason Codes |
`StatusText` | `zsdeinvstattx` | `ZEINVCFGSTATTX` | `ZEINV_STATUSTEXT` | `maintain` | e-Invoice Status Texts |

### 30.3 Why the action is a verb

An earlier draft of this table used one semantic object, `ZEINV_CONFIG`, for
all ten and put the table name in the action: `#ZEINV_CONFIG-country`. That is
backwards. The semantic object names the thing and the action names what you
do to it, so each intent reads as a sentence - *maintain a VAT registration*,
*display an inbound e-invoice*. It also makes them navigable: the AP cockpit
can link a company code straight to `#ZEINV_VAT-maintain`, which
`#ZEINV_CONFIG-vat` could never be a target for.

Launchpad grouping comes from the business catalog and the launchpad page,
not from a shared semantic object, so nothing is lost by splitting them.

### 30.4 Settings that are the same for every app

Template **List Report Page**; package **ZZCLR_GEINV**; navigation entity
**None** - the facets already put the children on the object page, and a
navigation entity produces the spurious third page §19 showed. Table type
**Grid** for the five cockpits, **Responsive** for the ten configuration apps.
The object page is kept everywhere except the two flat apps, whose views carry
`@UI.lineItem` but no facet and would open blank.


## 31. IAM apps, business catalogs and launchpad content

Everything from §30 onwards lives in the tenant, not the repository, because
each object carries an identifier the system mints. This section is the
mapping, so the names are decided once rather than per installation.

### 31.1 What the package already ships

Four IAM apps of type `SAJC`, one per e-invoice job:

```
ZAJC_EINV_PICKUP_SAJC    ZAJC_EINV_SUBMIT_SAJC
ZAJC_EINV_STATUS_SAJC    ZAJC_EINV_FETCH_SAJC
```

The `IBS` IAM app for each inbound service is created by *Local Publish* on
the service binding - like the inherited `ZSB_ELT_CONFIG_IWSG_IBS` - and is
never written by hand.

### 31.2 One IAM app of type EXT per Fiori app

| Fiori app | IAM app | Description |
|---|---|---|
`ZEINVDOC` | `ZIAM_EINVDOC_EXT` | Sales e-Invoice Cockpit |
`ZEDOCAP` | `ZIAM_EDOCAP_EXT` | Inbound e-Invoice (AP) Cockpit |
`ZEDOCSB` | `ZIAM_EDOCSB_EXT` | Self-Billed e-Invoice Cockpit |
`ZEDOCAPFLAT` | `ZIAM_EDOCAPFLAT_EXT` | Inbound e-Invoice (AP) All Data Query |
`ZEDOCSBFLAT` | `ZIAM_EDOCSBFLAT_EXT` | Self-Billed e-Invoice All Data Query |
`ZEINVCFGCNTRY` | `ZIAM_EINVCNTRY_EXT` | e-Invoice Country Registration |
`ZEINVCFGAPI` | `ZIAM_EINVAPI_EXT` | e-Invoice API Endpoints |
`ZEINVCFGCONST` | `ZIAM_EINVCONST_EXT` | e-Invoice Constants |
`ZEINVCFGMAP` | `ZIAM_EINVMAP_EXT` | e-Invoice Relevance Mapping |
`ZEINVCFGDOCTYP` | `ZIAM_EINVDOCTYP_EXT` | e-Invoice Document Types |
`ZEINVCFGSTATUS` | `ZIAM_EINVSTATUS_EXT` | e-Invoice Status Mapping |
`ZEINVCFGVAT` | `ZIAM_EINVVAT_EXT` | e-Invoice VAT Registration |
`ZEINVCFGACTION` | `ZIAM_EINVACTION_EXT` | e-Invoice Action Types |
`ZEINVCFGREASON` | `ZIAM_EINVREASON_EXT` | e-Invoice Reason Codes |
`ZEINVCFGSTATTX` | `ZIAM_EINVSTATTX_EXT` | e-Invoice Status Texts |

**Create each one from scratch, do not copy an inherited IAM app.** The
inherited ones predate the IAM content migration, and a copy inherits that
status. A migrated business catalog then refuses it:

```
Not migrated IAM App ZIAM_EINVDOC_EXT cannot be assigned
to migr. Business Catalog ZBC_EINV_PROCESS
```

The repair is *Migrate IAM App* on the app in ADT - pick the restriction
types, confirm - and *Migrate Business Catalog* if the catalog ends up on the
wrong side. Beyond unblocking the assignment, migration converts restriction
types into authorization objects and fields, which is what lets an app be
granted individually inside a business role. An unmigrated app is all or
nothing per catalog, and `ZBC_EINV_CONFIG` holds ten of them.

### 31.3 Three business catalogs

A catalog is a permission bundle, not a folder, so these follow who needs
what rather than one per app. The four inherited catalogs stay as they are.

| Catalog | Description | Holds | For |
|---|---|---|---|
`ZBC_EINV_PROCESS` | Business Catalog for e-Invoice Processing | the five cockpit IAM apps | AR and AP clerks |
`ZBC_EINV_CONFIG` | Business Catalog for e-Invoice Configuration | the ten configuration IAM apps | implementation / key user |
`ZBC_EINV_JOBS` | Business Catalog for e-Invoice Background Jobs | the four `*_SAJC` apps | administrator |

A clerk processing invoices has no business editing API endpoints, and
whoever maintains configuration does not need to schedule jobs.

`ZBC_EINV_JOBS` can be built as soon as the package is active - its four IAM
apps ship here. The other two wait on their Fiori apps, but create the shells
early and add each app as it goes live; a catalog is a container you keep
extending.

### 31.4 Launchpad descriptors and pages

| Module | LADI | Semantic object | Action | Title |
|---|---|---|---|---|
`zsdeinvdoc` | `ZEINVDOC_UI5R` | `ZEINV_DOC` | `manage` | Sales e-Invoice Cockpit |
`zsdedocap` | `ZEDOCAP_UI5R` | `ZEDOC_AP` | `manage` | Inbound e-Invoice (AP) |
`zsdedocsb` | `ZEDOCSB_UI5R` | `ZEDOC_SB` | `manage` | Self-Billed e-Invoice |
`zsdedocapflat` | `ZEDOCAPFLAT_UI5R` | `ZEDOC_AP` | `display` | Inbound e-Invoice - All Data |
`zsdedocsbflat` | `ZEDOCSBFLAT_UI5R` | `ZEDOC_SB` | `display` | Self-Billed - All Data |
`zsdeinvcntry` | `ZEINVCNTRY_UI5R` | `ZEINV_COUNTRY` | `maintain` | e-Invoice Country Registration |
`zsdeinvapi` | `ZEINVAPI_UI5R` | `ZEINV_API` | `maintain` | e-Invoice API Endpoints |
`zsdeinvconst` | `ZEINVCONST_UI5R` | `ZEINV_CONSTANT` | `maintain` | e-Invoice Constants |
`zsdeinvinvmap` | `ZEINVMAP_UI5R` | `ZEINV_RELEVANCE` | `maintain` | e-Invoice Relevance Mapping |
`zsdeinvdoctyp` | `ZEINVDOCTYP_UI5R` | `ZEINV_DOCTYPE` | `maintain` | e-Invoice Document Types |
`zsdeinvstatus` | `ZEINVSTATUS_UI5R` | `ZEINV_STATUSMAP` | `maintain` | e-Invoice Status Mapping |
`zsdeinvvat` | `ZEINVVAT_UI5R` | `ZEINV_VAT` | `maintain` | e-Invoice VAT Registration |
`zsdeinvaction` | `ZEINVACTION_UI5R` | `ZEINV_ACTIONTYPE` | `maintain` | e-Invoice Action Types |
`zsdeinvreason` | `ZEINVREASON_UI5R` | `ZEINV_REASON` | `maintain` | e-Invoice Reason Codes |
`zsdeinvstattx` | `ZEINVSTATTX_UI5R` | `ZEINV_STATUSTEXT` | `maintain` | e-Invoice Status Texts |

The app id is `<module>.<module>`, so `zsdeinvdoc.zsdeinvdoc`. `_UI5R`
follows the inherited `ZEVENT_LOG_UI5R`.

Three launchpad pages, one per catalog:

| Page | Title |
|---|---|
`ZLPP_EINV_PROCESS` | e-Invoice Processing |
`ZLPP_EINV_CONFIG` | e-Invoice Configuration |
`ZLPP_EINV_JOBS` | e-Invoice Background Jobs |

A page's tile reference is `{ladiId, tileId}` and the tile id is generated.
That is exactly what went stale in §21.2 and why these files left the
repository in §25. Create them in ADT, let the system mint the ids, and never
copy them between systems.

### 31.5 The order

Per app: deploy from BAS - LADI - IAM app (migrate it) - assign to catalog -
publish the catalog locally - place the tile on the page - assign the catalog
to a business role - assign the role to users. The IAM app must exist before
it can be assigned, and nothing is visible in the launchpad until the last
step.

## 32. Not every key field is mandatory

The config generator flagged every key field of every configuration table
`mandatory : create`. That looked safe - a key must be filled, so make the
UI say so - but it is wrong wherever the on-premise data model used a
**blank key as a wildcard**.

`ZTEINV_INVMAP` (Relevance Mapping) is the case that surfaced. Its key is
eight fields wide:

    PROJECTID  SYSID  LAND1  BUKRS  FKART  BLART  DOC_TYPE  SUP_TYPE

`FKART` (billing type) and `SUP_TYPE` (supply type) are routinely left
blank. The customer's own data makes the meaning clear - rows with a blank
billing type carry `BLART` DG or DR and describe **FI documents that have
no SD billing document**, while rows with `F2`/`G2`/`L2` carry `BLART = RE`
and describe billing-driven ones. Blank is not a wildcard; it is "this
mapping is for documents with no billing document". Flagging those fields
mandatory made the rows the old system depends on impossible to enter: the
Fiori create form renders a red asterisk and RAP rejects the create.

The converted logic already handles the split correctly.
`ZCDS_INT_EINV_REL_JRNL` joins the journal entry on `BLART + BUKRS` alone,
and `ZCDS_INT_EINV_RELEVANT` then **left outer** joins `I_BillingDocument`
on billing type - so a blank-`FKART` row still yields a candidate, with
`BillingDocument = ''`. Nothing needed changing there.

The fix is to drop the mandatory flag only - the fields stay keys, and
they stay `readonly : update`, because a key can never be changed after
creation. A blank CHAR key is perfectly storable; nothing in the table,
the CDS view or the behaviour pool objected. The only thing standing in
the way was the flag the generator added.

    field ( mandatory : create ) ProjectId, SystemId, Country, CompanyCode;
    field ( readonly : update )  ProjectId, SystemId, Country,
                                 CompanyCode, BillingDocumentType,
                                 AccountingDocumentType, DocumentTypeCode;

`gen_config_rap.py` now carries an `OPTIONAL_KEYS` map, keyed by table, so
a regeneration does not reintroduce it.

**This is not checkable statically.** Whether a blank key is meaningful is
a functional fact about the data, not a property of the repository, so no
checker rule can decide it - which is why it only came to light when the
app was opened and someone who knew the data looked at the form. The other
nine configuration objects carry the same blanket flag and have not been
reviewed against their real data:

| Object | Keys flagged mandatory |
|---|---|
| `ZCDS_INT_EINV_ACTION`  | EInvoiceType, ActionType |
| `ZCDS_INT_EINV_API`     | ProjectId, SystemId, Country, CompanyCode, Functionality, Sequence |
| `ZCDS_INT_EINV_CNTRY`   | ProjectId, SystemId, Country, CompanyCode, Sequence |
| `ZCDS_INT_EINV_CONST`   | ProjectId, SystemId, Product, Country, CompanyCode, LabelCode, Sequence |
| `ZCDS_INT_EINV_DOCTYP`  | ProjectId, SystemId, Country, CompanyCode, TransactionType, DocumentTypeCode |
| `ZCDS_INT_EINV_REASON`  | ActionType, ReasonCode |
| `ZCDS_INT_EINV_STATTX`  | StatusCode |
| `ZCDS_INT_EINV_STATUS`  | ProjectId, SystemId, Country, CompanyCode, Sequence, ProcessingMode |
| `ZCDS_INT_EINV_VAT`     | ProjectId, SystemId, Country, CompanyCode, Sequence |

The cheapest way to settle them is to query the existing on-premise tables
for blank key values - any column that has blanks in production data needs
removing from its mandatory list.

## 33. SUP_TYPE dropped from the relevance mapping

`ZTEINV_INVMAP` lost its eighth key field. `SUP_TYPE` (supply type, `B2B`
in the customer data) was carried from the table through
`ZCDS_INT_EINV_REL_JRNL` and `ZCDS_INT_EINV_RELEVANT` as a key - and read
by nothing. No ABAP in the package consumes it, it never reaches
`ZTEINV_DOC`, and it is not part of any portal payload. It was pure
carriage, and as a *key* field it also widened the fan-out the worklist
then had to collapse.

Removed from: the table, `ZCDS_INT_EINV_INVMAP`, `ZCDS_CUN_EINV_INVMAP`,
the behaviour definition (field control and `mapping for`),
`ZCDS_MET_EINV_INVMAP`, `ZCDS_INT_EINV_REL_JRNL` and
`ZCDS_INT_EINV_RELEVANT`. `ZDE_EINV_SUPTYPE` and `ZDO_EINV_SUPTYPE` are
left in place - harmless, and cheaper to keep than to re-add if a later
requirement wants the field back.

**`DOC_TYPE` was deliberately kept**, against an initial request to drop
it alongside `SUP_TYPE`. It is not decorative: it is the only source of
the code submitted to the portal.

    zteinv_invmap.doc_type
      -> ZCDS_INT_EINV_REL_JRNL.DocumentTypeCode
      -> ZCDS_INT_EINV_RELEVANT.DocumentTypeCode
      -> ZCL_EINV_WORKLIST       doc_type = ls_raw-DocumentTypeCode
      -> ZCL_EINV_PICKUP_JOB     DocumentTypeCode = ls_rel-doc_type
      -> ZTEINV_DOC.doc_type
      -> ZCL_EINV_API_CLIENT     ls_request-documenttypecode

`ZTEINV_DOCTYP` cannot take over the job: it is keyed on transaction type
and holds descriptions, so it *labels* codes rather than deriving them
from a billing or accounting document type. Dropping `DOC_TYPE` would have
sent every e-document out with an empty document type code. It stays a key
field and is now optional on create, so a blank is possible - but a blank
there is a real consequence, not a shrug, and the behaviour definition
says so in a comment at the point of decision.

**Key change - existing rows need attention.** The key went from

    PROJECTID SYSID LAND1 BUKRS FKART BLART DOC_TYPE SUP_TYPE

to

    PROJECTID SYSID LAND1 BUKRS FKART BLART DOC_TYPE

Two on-premise rows differing *only* in `SUP_TYPE` now collapse to one.
Check for that before loading legacy data:

    SELECT projectid, sysid, land1, bukrs, fkart, blart, doc_type,
           COUNT(*) AS cnt
      FROM /clr/einv_invmap
      GROUP BY projectid, sysid, land1, bukrs, fkart, blart, doc_type
      HAVING COUNT(*) > 1

Any row returned is a collision that has to be resolved by hand - the
flags (`EINVOICE`, `EWAYBILL`, `NONIRN`, `B2C`, `PURCHASE`) of the
surviving row must be the ones intended. In the eight-row sample seen
during the conversion there were no collisions.

## 35. Rebased on the tenant-pushed repository

The working copy was rebased on `Global_eInvoice_public_cloud-main` as
pushed from the tenant on 07/10/2026. That repository is authoritative
from here on; it is a superset of what the conversion generated, because
objects created in the tenant have been pushed back into it.

**82 files arrived that the generator never produced**, and they are the
right ones - the tenant is where they are minted:

| What | Count |
|---|---|
| IAM apps `ziam_*_ext.sia6.xml` (incl. `ZIAM_ELT_CONFIG_EXT`, `ZIAM_EVENT_LOG_EXT`) | 17 |
| Business catalogs `zbc_einv_*.sia1.xml` | 3 |
| Catalog/app assignments `*.sia7.xml` | 19 |
| Launchpad app descriptors `*_ui5r.uiad.json` | 20 |
| Launchpad pages `zlpp_*.uipg.json` | 2 |
| Authorization usage `*ht.sush.xml` | 16 |

This is section 25 and section 31 playing out as described: objects that
carry a system-minted identifier belong to the tenant, and the repository
holds them only once the tenant has created them. The deletion of the
launchpad descriptors earlier in the conversion was correct at the time -
they did not exist yet - and their return now is equally correct.

### Two things worth knowing about the rebased state

**`ZCDS_ABS_EINV_VATSPLIT` is back.** It was deleted from the repository
when the VAT split was flattened into `VatRate1..4` / `VatAmount1..4`
(section on the deep action parameter), but it was never deleted in the
tenant, so the push brought it back. It is referenced nowhere except in
two comments that explain why it is not used. Harmless, and dead. Delete
it in ADT if you want it gone.

**Six service bindings ship without their inbound services.** Rule 51
flags `ZSB_EDOC_AP`, `_APFLAT`, `_SB`, `_SBFLAT`, `ZSB_EINV_CONFIG` and
`ZSB_EINV_DOC`: each claims `<PUBLISHED>true</PUBLISHED>` but none of
the three companion objects is in the repository. Compare the two
inherited bindings, which are complete:

    zsb_elt_config.srvb.xml
    zsb_elt_config_iwsg.sco2.xml
    zsb_elt_config_iwsg_ext.sia6.xml
    zsb_elt_config_iwsg_ibs.sia6.xml

So abapGit can serialise these objects; they simply were not in this
push. In the dev tenant nothing is broken - the apps work, because the
objects exist there. The consequence is for the next system: imported as
it stands, those six bindings resolve to an inbound service that does not
exist, which is the exact error seen on 06/10
(`Inbound service ZSB_EDOC_AP_0001_G4BA does not exist`).

The fix is a push, not a code change: confirm each binding is published
in ADT, check the three companion objects are assigned to `ZZCLR_GEINV`
rather than a local or different package, and push again. The finding
stays in the checker until they are in the repository, because it is
true: this repository cannot currently be imported into a clean tenant.

## 36. The asterisk on a key field is decoration, not a constraint

Correcting section 32. That section said the `mandatory : create` flag was
what stopped a blank billing type being entered. The flag was part of it,
but not the part that was visible, and the two halves are independent:

* **Backend.** `field ( mandatory : create )` makes RAP reject an initial
  value on create. Removing it is what lets a blank actually be saved.
* **Frontend.** Fiori Elements renders a red asterisk on **every key
  field** of the entity in a create form, whatever the behaviour
  definition says. It is not driven by the flag and it does not block
  Save.

The proof is in the form itself. After the removal, only `ProjectId`,
`SystemId`, `Country` and `CompanyCode` carry the flag - yet
`BillingDocumentType`, `AccountingDocumentType` and `DocumentTypeCode`
still showed asterisks, and a row with a blank billing type saved without
complaint:

    AE10  F3Y  AE  AE10  <blank>  DR  380  e-Invoice: Yes
    AE10  F3Y  AE  AE10  <blank>  DZ  380  e-Invoice: Yes

So: do not chase the asterisk on a key field. Chase whether the save
succeeds. Section 32's conclusion - that blank is meaningful in this table
and the blanket mandatory flag was wrong - still stands; only its account
of what the user was seeing was wrong.

### What each of the three fields actually does

Worth recording, because it says which blanks are useful and which are
simply dead configuration:

| Field | Role in the determination | Blank means |
|---|---|---|
| `FKART` Billing Type | not in `ZCDS_INT_EINV_REL_JRNL`'s join; **left outer** join to `I_BillingDocument` in `ZCDS_INT_EINV_RELEVANT` | the row still yields a candidate with `BillingDocument = ''` - correct for FI-posted documents. A sentinel such as `NA` behaves identically, because neither matches a real billing type |
| `BLART` Accounting Doc. Type | **in** the join: `je.AccountingDocumentType = map.blart` | the row matches no journal entry and never fires. Dead configuration |
| `DOC_TYPE` Document Type Code | in no join; submitted to the portal as `documenttypecode` | the e-document goes out without a type code |

Only the first is a blank worth having. The other two want real values,
which is why their asterisks happen to give the right advice even though
they are not enforcing anything.

## 37. LOWERCASE on a domain, or the DDIC quietly shouts

The API Endpoint app stored `X-CLEAR-COUNTRY-CODE` where the user had
typed `X-Clear-Country-Code`, and would have done the same to an endpoint
URL and a bearer token. The cause is a DDIC default: a CHAR domain with no
`<LOWERCASE>X</LOWERCASE>` runs the input conversion and upper-cases every
entry on save. The form shows what was typed; the database holds capitals.

The generator created 59 character domains and set the flag on three of
them. The inherited ELT domains (`ZDO_ELT_C10` ... `ZDO_ELT_C255`) all had
it - the original developers got this right and the conversion did not
carry the habit across. Same family of defect as the blanket
`mandatory : create` in section 32: a default applied uniformly where the
answer depends on what the field holds.

### What changed

`<LOWERCASE>X</LOWERCASE>` set on 22 domains:

| Group | Domains |
|---|---|
| The three the symptom named | `ZDO_EINV_URL`, `ZDO_EINV_PARAM`, `ZDO_EINV_PARAMVAL` |
| Config value (holds the auth token) | `ZDO_EINV_VALUE` |
| Messages and codes from the portal | `ZDO_EINV_ERRMSG`, `ZDO_EINV_RESMSG`, `ZDO_EINV_ERRSRC`, `ZDO_EINV_ERRCODE`, `ZDO_EINV_RESCODE` |
| External identifiers | `ZDO_EINV_DOCID`, `ZDO_EINV_IDENT`, `ZDO_EINV_CMDID` |
| Free text | `ZDO_EINV_NAME`, `ZDO_EINV_REASONTXT`, `ZDO_EINV_ACTDESC`, `ZDO_EINV_DOCTDESC` |
| Inherited, fixed on instruction | `ZDO_ELT_STRING`, `ZDO_PROJECT_DIS` |
| Key fields, on instruction | `ZDO_EINV_INVNO`, `ZDO_EINV_STATUS` |
| Non-key, on instruction | `ZDO_EINV_VAT` |

Deliberately NOT changed: SAP keys and org units (`BUKRS`, `LAND1`,
`FKART`, `BLART`, `SYSID`, `PROJECTID`, ...), internal codes, and the
three whose descriptions mention "name" but whose content is an ABAP
identifier - `ZDO_EINV_USER`, `ZDO_EINV_HANDLER`, `ZDO_PROGRAM`. Those are
in the checker's exempt list so the rule does not nag about them.

Changing this flag is **not** a table conversion. `LOWERCASE` is a DDIC
input-conversion attribute, not a database column attribute, so the
domains activate normally - nothing like the SUP_TYPE deadlock in section
33.

### Two consequences that need testing

**Rows already stored are still in capitals.** The flag changes what
happens on the next save; it does not go back and repair history. The
API Endpoint entries, and any status or invoice number captured so far,
have to be re-entered to carry their real case.

**`ZDO_EINV_STATUS` is the one to watch.** Until now both sides of every
status comparison were upper-cased by the same DDIC default, so they
matched by accident. With the flag set, neither side is. If the Clear
platform returns `Pending` and the Status Mapping configuration holds
`PENDING`, the lookup that worked yesterday fails today. **Re-enter the
Status Mapping rows with the platform's exact casing and run one document
end to end before trusting it.** The same applies to `ZDO_EINV_INVNO`
where a stored uppercase number must match an incoming mixed-case one.

Both were flagged before the change and chosen deliberately; they are
recorded here so the failure mode is not a surprise.

### Rule 55

Flags a non-key CHAR/STRG domain that lacks `LOWERCASE` and whose
description contains url, endpoint, message, description, text, value,
token, header, parameter or source. Key-field domains are skipped on
purpose: a case-sensitive key lets two rows differ by case alone, which is
worse than upper-casing. Self-tested by removing the flag from
`ZDO_EINV_URL` and confirming the rule fires.

Note it caught two inherited objects the conversion had not touched. "It
is inherited" is not "it is right" - the same lesson as the missing
`mapping for` on `ZCDS_INT_EVENT_LOG`.

## 38. Second rebase, and a correction made in the tenant

Rebased again on the repository pushed from the tenant (second push of
07/10/2026). The file inventory is identical on both sides - 1134 files,
nothing added or removed - so the merge was a question of which version
of 32 files to keep.

The push carried the SUP_TYPE removal, so sections 32 to 34 are closed:
`ZTEINV_INVMAP` is seven keys wide on the database and the Relevance
Mapping app accepts a blank billing type. It did **not** carry the 22
LOWERCASE domains of section 37, which were re-applied on top.

### Two corrections that came from the tenant, not from here

**`APP_MIGRATION_STATUS` 3** now appears on `ZBC_ELT_CONFIG`,
`ZBC_ELT_EXECUTE_COMMAND_JOB`, `ZBC_EVENT_LOG` and `ZBC_INSTRU_EXECUTE`.
The IAM migration of section 31 is now recorded in the repository rather
than living only in the tenant.

**`ZIAM_ELT_CONFIG_EXT` was pointing at the wrong app.** It carried

    UI_APP_ID   ZSD_EINV_CONFIG_UI5R
    REL_NAME    ZSB_EINV_CONFIG  0001

which is the **e-Invoice** Configuration app and its binding - not the
ELT one. Corrected in the tenant to

    UI_APP_ID   ZSD_ELT_CONFIG_UI5R
    REL_NAME    ZSB_ELT_CONFIG   0001

Worth recording because the failure mode is quiet: the IAM app publishes,
the catalog accepts it, the tile appears - and it opens the wrong
application. Nothing in the repository could have caught it, because both
targets exist and both are valid objects. Only someone who knew which app
the catalog was supposed to grant would notice.

## 39. The AR cockpit is live again

The first conversion inverted the HANA cockpit's anchoring, and the symptom
was a dashboard that showed nothing however the configuration was
maintained.

### What /CLR/ELT_EINVOICE_COCKPIT actually did

The spine is **live**. `/CLR/ZCL_EINV_BASE~get_data` selects BKPF (and
VBRK) joined to `/CLR/EINV_INVMAP` on `BLART + BUKRS` and `FKART + BUKRS`
with `EINVOICE = 'X'`. Only then does `consolidate_data` ->
`add_final_entry` attach status, by **left lookup** into three staging
tables on `(BUKRS, BELNR, GJAHR)` falling back to `VBELN`:

| HANA | here |
|---|---|
| `fill_einv_status`  <- `/CLR/ZT_EINV`          | `ZTEINV_DOC` |
| `fill_async_status` <- `/CLR/ZT_EINV_ASY`      | `ZCDS_INT_EINV_DOC_ASY` |
| `fill_sales_status` <- `/CLR/ZT_EINV_SALES_ST` | `ZCDS_INT_EINV_DOC_STAT` |

A document with no staging row still appeared, with blank status. That
blank *is* the worklist's "to be processed" state. The staging row was
born at submit time, through the `einv_ewb_create` BAdI - never at
display time.

`ZCDS_INT_EINV_DOC` selects **from** `zteinv_doc`, so the entire model
hung off the staging table and a document was invisible until
`PickUpDocuments` had materialised it. The status-merge logic in
`ZCDS_INT_EINV_DOC_ENR` was correct all along; it was simply anchored on
the wrong side.

### What was built

    ZCDS_INT_EINV_RELEVANT ---+
                              +--> ZCDS_INT_EINV_CAND --> ZCDS_INT_EINV_LIVE
    ZCDS_INT_EINV_REL_BILL ---+                                  |
                                                                 v
                                                    ZCDS_CUN_EINV_WORKLIST
                                                    ZCDS_MET_EINV_WORKLIST

* **`ZCDS_INT_EINV_REL_BILL`** - the `NO_ACC` branch. `consolidate_data`
  ended by looping the mapping rows flagged `NO_ACC = 'X'` and adding the
  matching billing documents, which have no accounting document at all.
  `ZCDS_INT_EINV_RELEVANT` INNER JOINs `I_JournalEntry` and so could never
  produce them. `BELNR` and `GJAHR` are cast empty, exactly as
  `add_final_entry` left them when called with `is_vbrk` alone.
* **`ZCDS_INT_EINV_CAND`** - the two candidate sources unioned. Kept free
  of associations deliberately: a CDS union branch may not expose one, and
  splitting it also means the COALESCE chain is written once rather than
  per branch.
* **`ZCDS_INT_EINV_LIVE`** - the three status associations, all `[0..1]`
  and left, plus `IsProcessed`, `IsCancelled` and `StatusCriticality`.
* **`ZCDS_CUN_EINV_WORKLIST`** - read-only consumption view, exposed in
  `ZSD_EINV_DOC` as `EInvoiceWorklist`.

### Three fidelity decisions, taken deliberately

**Mandatory posting date.** The HANA report refused to run with both date
ranges empty - `AT SELECTION-SCREEN` raised `e015` and `get_data` returned
immediately as a second guard. A Fiori list report has no such gate and
would scan `I_JournalEntry` unfiltered, so Company Code and Posting Date
carry `@Consumption.filter.mandatory`.

**`NO_ACC` rows restored.** A real missing case rather than a design
choice - see above.

**Cancelled documents hidden again,** restoring
`DELETE gt_final WHERE cancel = 'X'`. This reverses the earlier conversion
decision that kept them for the audit trail. The rule is narrow: a
document that reached the portal keeps its `INVID` and is therefore never
hidden, so only never-submitted reversals disappear. The `NO_ACC` branch
has no reversal indicator at all, because `VBRK-FKSTO` has no released
counterpart.

### What this does NOT do

The worklist is **read-only**. The five instance actions (Submit, Refresh
Status, Print, Seller Action, Cancel) still live on `ZCDS_CUN_EINV_DOC`,
the managed BO over `ZTEINV_DOC`, because RAP cannot run a managed action
against a row that does not exist in the table. A processed row navigates
to that object page and behaves as before; an unprocessed one still needs
`PickUpDocuments` to materialise it first.

That matches HANA more closely than it first appears - there too, nothing
existed in `/CLR/ZT_EINV` until a submit created it. Putting the actions
on the worklist itself means an unmanaged BO with a hand-written save
sequence, which is a separate piece of work and was deliberately not
bundled with the view change.

### Rule 26 was wrong about unions

The key-contiguity rule scanned from the first `{` to the end of the file,
so the second branch of a union looked as though its keys followed the
first branch's plain elements. It now splits on `union [all]` and checks
each branch separately. Self-tested by moving a key below a plain element
in the first branch and confirming it still fires.

## 40. I_BillingDocument element names verified

The conversion carried a `>>> FIELD NAMES TO VERIFY IN ADT <<<` block on
`ZCDS_INT_EINV_RELEVANT` from the start, because the released billing
document view's element names were assumed rather than checked. A data
preview of `I_BillingDocument` in F3Y on 07/10/2026 settles them:

| On VBRK | On I_BillingDocument | Status |
|---|---|---|
| `VBELN` | `BillingDocument` | confirmed |
| `FKART` | `BillingDocumentType` | confirmed |
| `FKDAT` | `BillingDocumentDate` | confirmed |
| `ERDAT` | `CreationDate` | confirmed |
| `BUKRS` | `CompanyCode` | confirmed |

The verification notes on `ZCDS_INT_EINV_RELEVANT` and
`ZCDS_INT_EINV_REL_BILL` have been rewritten to say so, rather than left
as open warnings a future reader would re-investigate.

**One remains open.** `VBRK-FKSTO` still has no released counterpart under
the name `CancellationStatus`, so a cancelled billing document cannot be
recognised on the SD side. The consequence is confined to the `NO_ACC`
branch, which has no FI document to read a reversal indicator from and
therefore never hides a row - recorded in `ZCDS_INT_EINV_LIVE`'s
`IsCancelled` comment and in section 39.

## 41. A service definition takes no comments

Exposing the worklist in `ZSD_EINV_DOC` came with four `//` lines
explaining what the new entity was for. ADT answered, once per line:

    Comments are not supported and will be deleted on save

The source language of a `.srvd.srvdsrv` is annotations and `expose`,
nothing else - no `//`, no `/* */`. Mine, again, and the second comment
syntax this conversion has got wrong after the `"` in a behaviour
definition (section 34).

The warning is mild; the consequence is not. ADT does not refuse the
save, it **deletes the lines**. The tenant then holds a file that no
longer matches the repository, and the next push shows a diff nobody
made - the kind of drift that is only noticed much later, when someone
is trying to work out why two versions differ.

**Rule 56** flags any comment line in a `.srvd.srvdsrv`. Self-tested.
The explanation now lives where it can survive: in
`ZCDS_CUN_EINV_WORKLIST` itself and in section 39.

Three comment conventions, three source languages, and they do not agree:

| Source | Line comment | Block comment |
|---|---|---|
| ABAP (`.clas.abap`) | `"` and `*` | none |
| CDS / BDL (`.asddls`, `.asbdef`) | `//` | `/* */` |
| Service definition (`.srvdsrv`) | none | none |

Worth having written down, since two of the three cost an activation
round to discover.

## 42. Why the inbound service keeps disappearing

`Inbound service ZSB_EINV_DOC_IWSG does not exist`, on Publish Locally.
The same error hit `ZSB_EDOC_AP` on 06/10. It is worth setting out what
is actually happening, because the obvious fix is wrong and I applied it
once already (section 24).

Put the two bindings side by side. They are **structurally identical** -
same `CONTRACT`, same `BIND_TYPE_VERSION V2`, same
`<PUBLISHED>true</PUBLISHED>`, same `<BINDING_CREATED>true</BINDING_CREATED>`.
The only difference is what ships beside them:

    zsb_elt_config.srvb.xml          zsb_einv_doc.srvb.xml
    zsb_elt_config_iwsg.sco2.xml     (nothing)
    zsb_elt_config_iwsg_ext.sia6.xml
    zsb_elt_config_iwsg_ibs.sia6.xml

So the XML is not the differentiator - the companions are. And abapGit
clearly *can* serialise them, because it does for the inherited pair.

### The loop

1. The binding is published in the tenant. That creates `ZSB_EINV_DOC_IWSG`
   and its two IAM objects, in package `ZZCLR_GEINV`.
2. A pull brings the repository's version of the package. The three
   generated objects are in that package in the tenant but not in the
   repository, so the pull removes them.
3. The `.srvb.xml` still says `PUBLISHED=true`, so ADT believes the
   endpoint is there and Publish Locally tries to *activate* it rather
   than create it. It is not there. The error.

Every pull destroys the publish, and the flag then prevents the repair.
That is why this recurs rather than being fixed once.

### What was done

`<PUBLISHED>` set to `false` on the six e-invoice bindings - `ZSB_EDOC_AP`,
`_APFLAT`, `_SB`, `_SBFLAT`, `ZSB_EINV_CONFIG`, `ZSB_EINV_DOC`. The two
inherited bindings keep `true`, because theirs is honest: their companions
are in the repository.

`BINDING_CREATED` stays `true` - the binding object itself does exist; it
is only the endpoint that does not.

This is the same change as section 24, which that section recorded as
wrong. It was not wrong, it was **incomplete**: setting the flag false
lets the publish run, but nothing brings the companion objects back into
the repository, so the next pull destroys the endpoint again. The fix
only holds once step 3 below is done.

### Breaking the loop for good

1. Pull. The bindings now read unpublished, which matches reality.
2. **Publish Locally** on each. This creates `*_IWSG`, `*_IWSG_EXT` and
   `*_IWSG_IBS` afresh.
3. **Push.** Confirm all three objects per binding land in the repository,
   as the inherited pair's do. The `.srvb.xml` will come back with
   `PUBLISHED=true`, and from then on the flag is true *and* the
   companions are present, so a pull no longer removes them.

Step 3 is the one that matters. Steps 1 and 2 are a repair; step 3 is what
stops the repair being needed again. Rule 51 stays in the checker for
exactly this reason - it is true whenever the flag and the companions
disagree, in either direction.

> **Corrected twice.** Section 43 found the real blocker - orphaned
> authorization-defaults shells. And the mechanism described above is
> wrong: **abapGit pull is additive**. It adds and overwrites; it does not
> delete. Confirmed in the tenant on 08/10/2026, when a pull carrying
> twelve file deletions left all twelve objects in place. So pulls were
> never destroying the inbound services.
>
> The likelier history is the OData V4 -> V2 conversion of section 27: the
> six bindings were deleted and recreated in ADT, which dropped their
> endpoints, and the authorization-defaults shells survived as orphans. A
> later push then captured the shells into the repository, where they have
> been blocking the republish ever since.
>
> Keep the three steps below - they are still right. Only the explanation
> of how the state arose was wrong.


## 43. The authorization-defaults shell was the real blocker

With `PUBLISHED` cleared (section 42) the binding editor correctly showed
*Service Endpoint: Unpublished* with a **Publish** button - and Publish
still failed with the same `Inbound service ZSB_EINV_DOC_IWSG does not
exist`. So the flag was a real defect but not the cause.

The binding editor's header carries a link, **Default Authorization
Values: 35F7F5393514E6332F80365A039760HT**. Opening it shows one
authorization object, `S_SERVICE`, with Maintenance Status *No Default*,
and one error: *Default values might not be sufficient*. That object is in
the repository, as `35f7f5393514e6332f80365a039760ht.sush.xml`, and its
display name says what it is for:

    R3TR IWSV ZSB_EINV_DOC                       0001

### What publishing actually creates

Six objects per binding, not four:

| Object | File | In the repo for the six? |
|---|---|---|
| inbound service (IWSV) | `<b>_iwsg.sco2.xml` | no |
| IAM app, external | `<b>_iwsg_ext.sia6.xml` | no |
| IAM app, inbound service | `<b>_iwsg_ibs.sia6.xml` | no |
| auth defaults, IWSV | `<hash>ht.sush.xml` | **yes** |
| auth defaults, IWSG | `<hash>ht.sush.xml` | **yes** |

abapGit serialised the two SUSH shells and none of the three objects they
describe. For `ZSB_ELT_CONFIG` and `ZSB_EVENT_LOG` it serialised all five,
which is why those two publish and the other six do not.

**A half-carried publish is worse than no publish.** With no SUSH at all,
Publish Locally would simply create everything. With the shell present and
naming `ZSB_EINV_DOC_IWSG`, the publish believes the object is already
there and tries to work with it. Hence an error that reads like a missing
object when the actual fault is a present one.

### What was done

The twelve orphaned shells were deleted - two each for `ZSB_EDOC_AP`,
`ZSB_EDOC_APFLAT`, `ZSB_EDOC_SB`, `ZSB_EDOC_SBFLAT`, `ZSB_EINV_CONFIG` and
`ZSB_EINV_DOC`. The four belonging to the two inherited bindings stay,
because their inbound services exist. The six `SAJC` shells stay too:
those describe job catalog entries, and every `zajc_*.sajc.json` is in the
repository.

**Rule 57** flags a `.sush.xml` whose `DISPLAY_NAME` names an `IWSV`,
`IWSG` or `SAJC` object that is not in the repository. Self-tested by
removing `zsb_event_log_iwsg.sco2.xml` and confirming both of that
binding's shells were flagged.

### The sequence now

1. Pull - then **delete the twelve shells by hand in ADT**. A pull does
   not remove them: abapGit never deletes, so a file removed from the
   repository leaves the object sitting in the tenant. This is the step
   that catches people out, and it caught us.
2. **Publish Locally.** With nothing in the way this creates all five
   objects and the endpoint activates.
3. **Push, and confirm all five arrived** - compare against
   `ZSB_ELT_CONFIG`. If the shells come across again and the inbound
   service does not, rule 57 will say so on the next check rather than
   leaving it to the next failed publish.

Step 3 remains the one that matters, for the reason section 42 gave. What
section 42 missed is that until the shells were removed, step 2 could not
succeed at all.

## 44. abapGit pull does not delete

Worth stating on its own, because two sections were written on the
opposite assumption.

**A pull adds and overwrites. It never removes.** An object deleted from
the repository stays in the tenant until someone deletes it in ADT. The
pull dialog shows only *Add local object* and *Overwrite local object* -
there is no third action, and nothing warns that the repository no longer
contains an object the system still has.

Confirmed on 08/10/2026: a pull carrying twelve `.sush.xml` deletions left
all twelve objects in place.

Two consequences worth carrying forward:

**Removing something from the repository is half a deletion.** The other
half is manual, in ADT, and nothing prompts for it. Any future change that
deletes an object needs the deletion listed explicitly in NEXT_STEPS.md,
or it silently does not happen.

**The tenant is a superset, and drifts.** Every object ever created there
is still there unless deliberately removed - orphaned authorization
shells, the `ZCDS_ABS_EINV_VATSPLIT` of section 35, the stray
`ZSD_EINV_CONFIG_UI5R`. The repository is not a mirror of the tenant; it
is a mirror of what has been pushed. Rule 57 exists because that gap is
not otherwise visible.

## 45. The live worklist proven end to end

09/10/2026, tenant F3Y client 100. The worklist introduced in section 39
returns live candidates in the Fiori app:

    DZ  1400000000  AE10  AE  posting date 02.10.2026  status blank
    DR  1800000000  AE10  AE  posting date 02.10.2026  status blank

Neither has a row in ZTEINV_DOC. Both are visible because
ZCDS_CUN_EINV_WORKLIST reads I_JournalEntry joined to ZTEINV_INVMAP, not
the staging table. That is the behaviour section 39 set out to restore,
and it is now confirmed rather than asserted.

### What the blank status means

The OData payload for both rows:

    "EffectiveStatus": "", "EffectiveMessage": "",
    "IsProcessed": "", "IsSent": false,
    "CommandId": "", "EInvoiceNumber": "", "StatusCriticality": 0

Every status field is initial because the left lookups in
ZCDS_INT_EINV_LIVE find nothing to attach. This is the "to be processed"
state, exactly as the HANA ALV displayed an unprocessed line. It is not a
defect and not a missing join.

### The debugging ladder that found it

The app showed an empty table while the data was correct. Four levels,
each one ruling out everything below it:

1. **SQL Console on the consumption view** (Data Preview toolbar) -
   2 rows for `companycode = 'AE10'`, and 2 again for
   `postingdate BETWEEN '20260101' AND '20261231'`. Proves the CDS stack,
   the union, the joins and the `where IsCancelled = ''` are all correct.
   A view entity compiles to SQL and runs no ABAP, so the SQL Console is
   the debugger at this level - there is nothing to breakpoint.
2. **The ADT status bar** - `F3Y, 100`. Ruled out the client mismatch
   hypothesis: ZTEINV_INVMAP and I_JournalEntry are both client-dependent,
   and ADT on 080 against a launchpad on 100 would have produced exactly
   this symptom. It did not apply here, but it is the first thing to check
   whenever Data Preview and a Fiori app disagree.
3. **A direct OData GET**, bypassing UI5 entirely:

       https://my434389.s4hana.cloud.sap/sap/opu/odata/sap/ZSB_EINV_DOC
         /EInvoiceWorklist?$filter=CompanyCode eq 'AE10'&$top=10&$format=json

   Note the UI host, not the `-api` host ADT connects to - the browser
   session only exists on the UI host. Two entries came back, which proved
   the service definition, the service binding and the published metadata
   were all fine and moved the fault above the service.
4. **The date in the payload.** `"PostingDate": "/Date(1790899200000)/"`
   is 02.10.2026. The filter bar had been given `02/10/2026`, which the
   user's **MM/DD/YYYY** format read as 10 February. Entering `10/02/2026`
   returned both rows.

### Two traps worth recording

**A `#INTERVAL` filter accepts a single value silently.** PostingDate is
declared `@Consumption.filter: { mandatory: true, selectionType: #INTERVAL }`.
Typing one date turns it into an equality filter with no warning. Use the
date picker's range option; it also removes the format ambiguity.

**The date format is the user's, not the system's.** `02/10/2026` is
unambiguous to nobody. When comparing what an app shows against what a
view holds, read the date from the SQL Console as `YYYYMMDD` or from the
OData payload as epoch milliseconds, never from the rendered field.

### Open defect found while debugging

The list renders every field of the view in alphabetical order, which is
what Fiori Elements does when it finds no `@UI.lineItem` annotations. The
metadata extension ZCDS_MET_EINV_WORKLIST is therefore not reaching the
service. Cosmetic - the data is right - but it needs fixing: confirm the
extension is activated and that its `annotate entity` target names
ZCDS_CUN_EINV_WORKLIST exactly.

## 46. Actions on the live worklist

The worklist showed candidates but could do nothing with them. The five
cockpit buttons - Submit, Refresh Status, Request Printout, Seller
Action, Cancel - now exist on it too, plus Pick Up.

### Why this needed a new business object

`ZCDS_CUN_EINV_WORKLIST` is a read-only view over live data. A row is
there because a journal entry matches ZTEINV_INVMAP, not because anything
was stored, so there is no table to hang a managed behaviour on. The
cockpit's behaviour cannot be reused either: `ZCDS_CUN_EINV_DOC` is a
projection of a managed BO whose `persistent table` is ZTEINV_DOC, and an
unprocessed candidate has no row there by definition.

So the worklist gets its own **unmanaged** behaviour that owns no data:

    unmanaged implementation in class zbp_cds_cun_einv_worklist unique;
    define behavior for ZCDS_CUN_EINV_WORKLIST alias Worklist
    authorization master ( instance )
    {
      action ( features : instance, authorization : instance ) PickUp;
      action ( features : instance, authorization : instance ) SubmitEInvoice;
      ...
    }

No create, update or delete. Every action delegates to
`ZCDS_INT_EINV_DOC` with EML, so no HTTP call, status rule or message
text is duplicated - the worklist and the cockpit cannot drift apart
because there is only one implementation.

### Submit materialises first

`SubmitEInvoice` on an unprocessed candidate would have nothing to
submit, so the handler creates the ZTEINV_DOC row before executing the
action - PickUpDocuments and submit_data for one document, in one click.
The duplicate filter is `ZCL_EINV_WORKLIST~keep_new`, the same one
PickUpDocuments uses, so an already-picked-up row keeps its status
instead of being reset to NOT PROCESSED.

The HANA cockpit behaved this way without saying so: GT_FINAL held
unprocessed lines and &CREATE called `einv_ewb_create`, which inserted
the row before submitting it. The RAP version makes that explicit.

The other four actions do not materialise. They need a document the
platform already knows, and feature control greys them out on a row with
no Clear document id.

### Key translation is why the actions repeat themselves

The worklist key has eight fields - the four document fields plus the
four that the join to ZTEINV_INVMAP contributes - and the business object
key has four. Going down is a projection. Coming back up, so that a
message raised against a document reaches the worklist row that asked for
it, is a lookup in the action's own key table. Each action repeats those
ten lines rather than calling a shared helper because a RAP derived type
(`REPORTED ...`, `FAILED ...`) is not accepted in a method signature -
the same constraint already recorded on `read_documents` in
ZBP_CDS_INT_EINV_DOC.

Without that relay the buttons would look silent: the message exists but
is addressed to a key the UI never sent.

### Two checker rules were wrong about this shape

Both were written when every behaviour in the package was managed:

**Rule 39/40 (keys must be flagged readonly)** fired on all eight
worklist keys. A behaviour with no `create` and no `update` has nothing
to protect them from, and `field ( readonly )` on a BO that declares no
update is itself rejected. The rule now runs only when the behaviour
declares create or update.

**Rule 19 (%action in an authorization handler needs instance
authorization)** fired on five of the six actions and was *right* - the
first draft declared `action ( features : instance )` only, and without
`authorization : instance` the component `%action-<name>` does not exist
in the authorization result at all. The fix was in the behaviour
definition, not the rule. The rule's regex was also too strict: it
demanded the parentheses contain nothing but `authorization : instance`,
so the normal combined form `( features : instance, authorization :
instance )` slipped past it. Now it matches inside the group.

Both rules were self-tested after the change by reintroducing the defect
they exist to catch.

### Still to verify in ADT

An unmanaged behaviour with actions but no standard operations is the one
part of this that cannot be checked from the repository. If the syntax
check asks for `lock master`, add it and implement a LOCK that does
nothing - there is nothing to lock, since the actions lock through the
business object they delegate to.

## 47. Multi-select on the worklist

Selecting several candidates and submitting them in one press needs three
things, and only one of them is in ABAP.

### The checkbox column is a manifest flag

`"multiSelect": true` in the list report's component settings
(`webapp/manifest.json`). That is the OData V2 form; the V4 equivalent
`tableSettings.selectionMode` does not apply, the service is V2. It puts
a checkbox in the first column and a select-all box in the column header.

Nothing in CDS controls this. A list report with action buttons but no
checkboxes is in single-select mode because the flag is missing.

### invocationGrouping: #CHANGE_SET is the part that matters

Added to the four parameterless actions in ZCDS_MET_EINV_WORKLIST. It
makes a multi-row press ONE request and one RAP LUW: twenty invoices
become twenty rows in a single save.

Without it the list report sends one call per selected row. Each is its
own LUW, so a failure on row eleven leaves ten invoices submitted and
nine not - which is exactly what the HANA `submit_data_batch` loop did,
and the one behaviour from it worth not inheriting.

SellerAction and CancelEInvoice are deliberately NOT grouped. Both carry
a parameter, so each selected row opens its own dialog; grouping would
mean one rejected row rolls back the ones the user already confirmed.

### Select All / Deselect All cannot be RAP actions

They change what the user has ticked and send nothing to the server. A
behaviour definition has no idea what is selected, so these are a
controller extension in the BAS project, not an action - see
`ui/worklist/README.md` for the controller and the manifest registration.

The standard header checkbox already selects everything, so these buttons
are parity with the HANA ALV's `&SELALL` / `&DESELALL` function codes
rather than new capability. Worth having for users coming off the old
cockpit; worth skipping if nobody asks.

### The backend needed no change

`SubmitEInvoice` already takes a table of keys and already materialises
the rows that have none, so mass submit was supported the moment section
46 went in. This section adds no ABAP at all.

## 48. A behaviour needs a root view entity

The first activation of section 46 failed with three messages:

    The type "ZCDS_CUN_EINV_WORKLIST" is not a root entity or is not
    released for BEHAVIOR implementations.          (behaviour definition)

    "ZCDS_CUN_EINV_WORKLIST" is not part of a composition hierarchy of
    CDS entities.                                   (behaviour pool)

    The field SUBC of the TRDIR entry in the current compilation unit ()
    contains the incorrect value 'B'.               (follow-on)

My defect. `ZCDS_CUN_EINV_WORKLIST` was written as `define view entity`
when every other view in this package that carries a behaviour -
ZCDS_INT_EINV_DOC, ZCDS_CUN_EINV_DOC, ZCDS_INT_EINV_INVMAP,
ZCDS_CUN_EINV_INVMAP - is `define root view entity`. A behaviour can only
be written for the root of a composition hierarchy, even when that
hierarchy has exactly one node and no children at all.

The fix is the word `root`. It adds no composition, changes no SQL and
changes no annotation; it only tells RAP that this entity may carry a
behaviour.

The third message is noise: a half-written generated include from the
failed activation. It clears when the first two do.

### Rule 58

Statically checkable, so it is now a rule: every `define behavior for X`
whose X is a CDS view in this repository requires that view to be
`define root view entity`.

Two exclusions, both found by running it:

* a **child** of a composition is correctly not root. In a managed
  definition it says so with `lock dependent by`; in a projection it says
  nothing at all, so the rule checks only the FIRST block of a behaviour
  definition - position is the reliable signal for which block is the
  root.

Self-tested by removing `root` again and confirming the rule fires.

### Why this class of defect keeps happening

Same shape as sections 32, 34, 37 and 41: a property that every existing
object in the package already has, applied by copying the surrounding
style rather than by knowing the rule. The worklist view was written as a
reporting view, before it had a behaviour, and nothing re-examined its
header when the behaviour arrived. The checker now re-examines it.

### 48a. Two more things an action-only behaviour still needs

The `root` fix cleared the first error and uncovered two more, both of
which contradict an assumption I had made explicitly.

**`lock master` is required, with no exemption.**

    The behavior definition is "strict", which means that every entity
    must be flagged either as a "lock master" or as a "lock dependent".

I had written in section 46 that this *might* be demanded and left it
out. strict ( 2 ) means every entity, including one with no create,
update or delete. The LOCK implementation is deliberately empty: the
worklist has no persistent state, and what does need locking - the
ZTEINV_DOC row - is locked by ZCDS_INT_EINV_DOC when the action's EML
modify runs. A second lock here would widen the window and protect
nothing.

**Keys must be flagged readonly, with no exemption either.** Eight
messages, one per key. This one I got actively wrong: when rule 39/40
flagged these keys I relaxed the rule, reasoning that a behaviour with no
create and no update has nothing to protect them from. The tenant
disagrees - the check is on the key, not on the operations. The rule is
restored to its original form and the bdef now carries

    field ( readonly ) CompanyCode, AccountingDocument, FiscalYear,
                       BillingDocument, ProjectId, SystemId, Country,
                       DocumentTypeCode;

Plain `readonly`, not `readonly : update`, since there is no update
operation for the qualified form to refer to.

**The lesson, which is the one worth keeping.** A checker rule that
fires on new code is evidence about the code, not about the rule.
Relaxing it because the new shape "obviously" does not need it cost a
round trip to the tenant. The right order is: satisfy the rule, and
relax it only when the tenant has demonstrated the rule is wrong - which
is how section 48's own exclusion for composition children was derived.

### 48b. IN LOCAL MODE belongs to one behaviour pool only

    The operation can only be used in implementations of behavior
    definition "ZCDS_INT_EINV_DOC".

Every EML statement in ZBP_CDS_CUN_EINV_WORKLIST carried
`IN LOCAL MODE`, copied from ZBP_CDS_INT_EINV_DOC where it is correct.
It is not correct here: `IN LOCAL MODE` bypasses the external layer and
is reserved for the handler of the business object it names. A call from
one BO's handler into another has to go through the external layer.

The other three messages in the same activation - `LS_REP-EINVOICE` is
unknown, `LS_R` is unknown, and the TRDIR SUBC noise - were all cascade
from the one statement failing to compile.

Dropping the addition is not a workaround, it is better behaviour. The
external layer evaluates ZCDS_INT_EINV_DOC's own feature control and
authorization, so the worklist cannot submit a document that the cockpit
itself would have refused. The called BO joins the same LUW and is saved
in the same save sequence, so no COMMIT ENTITIES is involved.

### Rule 59

Every `MODIFY|READ ENTITIES OF X ... IN LOCAL MODE` in a behaviour pool
whose behaviour definition does not define X. The class-to-BO map comes
from `implementation in class` in the behaviour definitions, so the rule
needs no naming convention. Self-tested by putting the addition back on
one statement.

Three rounds of activation errors on one object, all of the same kind:
properties and restrictions that every neighbouring object already
demonstrates, missed by writing the new object from the shape of the old
one rather than from the rules. Rules 58 and 59 close the two that are
statically decidable.

### 48c. What the external layer actually costs

Three more, all consequences of the same thing: once `IN LOCAL MODE` is
gone, this class is an ordinary consumer of ZCDS_INT_EINV_DOC and is held
to the business object's own contract.

**`SYNCSTATUS` cannot be modified.** It is `field ( readonly )` on
ZCDS_INT_EINV_DOC, and readonly is enforced on the external layer - the
only layer available here. ZBP_CDS_INT_EINV_DOC's own PickUpDocuments
sets it happily, because it runs IN LOCAL MODE inside its own pool.

The fix replaces the whole hand-written CREATE with an EXECUTE of
PickUpDocuments, one action row per document, naming the document in the
selection parameters. That is better than finding a way to set the field:
the duplicate filter (`ZCL_EINV_WORKLIST~keep_new`), the field defaults
and the relevance selection now stay in one place instead of being copied
into this class and left to drift. The helper lost twenty lines.

PickUpDocuments refuses a call with no date range and no document number,
so filling AccountingDocument (or BillingDocument, for a NO_ACC billing
row) is what gets each call past its own guard.

**LOB columns under FOR ALL ENTRIES.** `SELECT *` on the worklist picked
up SignedQrCode and SignedInvoice. FOR ALL ENTRIES implies DISTINCT, and
a LOB cannot take part in one. Replaced with an explicit sixteen-field
list and a local structure type; nothing in this class ever read either
column.

**READ and SAVER are mandatory.** An unmanaged behaviour must implement
both, even one that stores nothing:

* READ is one SELECT. The list itself is served by the query engine, not
  by the business object, so READ is reached only when the framework
  refreshes an instance after an action. A candidate that has vanished
  between two reads - journal entry reversed, mapping row deleted - is
  reported as NOT_FOUND rather than as an empty row, or the UI would show
  a blank line where a document used to be.
* The saver (`lsc_zcds_cun_einv_worklist`) is empty. Everything the
  actions change is written by ZCDS_INT_EINV_DOC, which has its own save
  sequence and joins this LUW through the EML calls.

### What this sequence of errors was really about

Four rounds on one object. Not four unrelated mistakes: one decision -
"the worklist gets its own behaviour" - whose consequences I worked out
by submitting it to the tenant instead of by reading what an unmanaged
behaviour is required to provide. The first error (`root`) and the third
(`IN LOCAL MODE`) were both avoidable from the package's own existing
code; the second (`lock master`) I had explicitly guessed at and guessed
wrong; the fourth only became visible once the third was fixed.

Rules 58 and 59 catch the two that are statically decidable. The rest is
a note for the next unmanaged behaviour in this package: it owes the
framework LOCK, READ and a saver before it owes anything to the feature.

## 49. Action names are flat across a service

The behaviour activated, then the service binding showed five errors:

    Duplicate action external name CancelEInvoice.
    Duplicate action external name RefreshStatus.
    Duplicate action external name RequestPrintout.
    Duplicate action external name SellerAction.
    Duplicate action external name SubmitEInvoice.

ZSD_EINV_DOC exposes ZCDS_CUN_EINV_DOC and ZCDS_CUN_EINV_WORKLIST, and
both declare those five names. RAP allows it - there the action is scoped
to its entity - but in OData V2 an action becomes a **FunctionImport in
one flat, service-wide namespace**, so the two sets collide. PickUp was
the only one that survived, because the cockpit has no action by that
name.

### The fix: a prefix

Every worklist action is now `Worklist<name>` - WorklistPickUp,
WorklistSubmitEInvoice, WorklistRefreshStatus, WorklistRequestPrintout,
WorklistSellerAction, WorklistCancelEInvoice. Three files change
together: the behaviour definition, the handler's method names and
`%action-` components, and the `dataAction` values in
ZCDS_MET_EINV_WORKLIST. The button **labels** are unchanged, so nothing
about the UI moves.

The EML inside the handler still names the cockpit's actions, not the
worklist's: `EXECUTE SubmitEInvoice` targets ZCDS_INT_EINV_DOC and must
keep its own name. The rename is only on the outward-facing side.

### The alternative, and why not

The worklist could have had its own service definition and binding
(ZSD_EINV_WORK / ZSB_EINV_WORK), which would have given it a namespace of
its own and decoupled it from the troubled ZSB_EINV_DOC binding
(sections 42-45). That is arguably the cleaner end state and worth doing
if the two apps ever diverge further.

It was not done now because the worklist app is already deployed against
ZSB_EINV_DOC: a new service means a new service URI, which means
redeploying the app with a changed manifest. The prefix costs one pull
and a republish. If the binding has to be recreated anyway, revisit this.

### Rule 60

Statically checkable from the service definition plus the behaviour
definitions: for every `expose`d entity in a `.srvdsrv`, collect its
actions (`action ...` in a base behaviour, `use action ...` in a
projection) and flag any name claimed by two different entities in the
same service. Self-tested by putting `SubmitEInvoice` back on the
worklist.

This one is worth having beyond this package. Nothing in the behaviour
definitions hints at the collision - each is locally correct, and the
error surfaces only when the binding is generated, two objects away from
where the mistake lives.

## 50. The first real submit: BEHAVIOR_ILLEGAL_STATEMENT

09/10/2026. The worklist rendered, the buttons appeared, a row was ticked
and **Submit e-Invoice** pressed. Short dump:

    Runtime Errors   BEHAVIOR_ILLEGAL_STATEMENT
    Short Text       Statement "INSERT <dbtab>" is not allowed with this status.
    Program          ZCL_INSTRU_EVENT_CLASS========CP

The call chain from the dump:

    LHC_WORKLIST=>WORKLISTSUBMITEINVOICE        (worklist)
      LHC_EINVOICE=>SUBMITEINVOICE              (cockpit BO)
        ZCL_EINV_SUBMIT=>SUBMIT_DOCUMENT
          ZCL_ELT=>GET_COMMAND
            ZCL_INSTRU_EVENT_CLASS=>LOG_TELEMETRY
              ZCL_INSTRU_EVENT_CLASS=>LOG_EVENT_DATA
                ZCL_INSTRU_EVENT_CLASS=>UPDATE_DB_TABLE   <-- dump

and the statement:

    INSERT ztevent_log FROM TABLE @gt_db_table.
    IF sy-subrc NE 0. ... ELSE. COMMIT WORK AND WAIT. ENDIF.

**This is not the worklist's defect.** The chain enters
ZBP_CDS_INT_EINV_DOC's own SubmitEInvoice, so pressing Submit in the
cockpit app would have terminated identically. It is the first time any
document was actually submitted end to end, and it is the first time this
code was reached from inside a RAP LUW.

### Why it was listed as advisory and shipped anyway

`COMMIT WORK AND WAIT` in ZCL_INSTRU_EVENT_CLASS line 771 is one of the
fifteen advisory findings the checker has reported on every run since the
merge, under the heading "these activate in the customer tenant today".
That heading was true and beside the point: the question is not whether
inherited code activates, it is whether it is reachable from a behaviour
implementation. Activation and the RAP contract are checked at different
times, and nothing connected the two.

### The fix: defer, then flush in the save phase

A RAP LUW forbids database writes during the interaction phase and allows
them in the save phase. So the rows are held and written later:

* `ZCL_INSTRU_EVENT_CLASS` gains `gv_defer` (public, class-level) and a
  class-level `gt_pending`. With `gv_defer` set, `update_db_table` appends
  to `gt_pending` and returns instead of writing.
* `flush( )` writes `gt_pending` with no COMMIT - the RAP LUW commits.
* `discard( )` clears it.
* The six actions of ZBP_CDS_INT_EINV_DOC set `gv_defer` on entry;
  `save_modified` calls `flush( )` and `cleanup_finalize` calls
  `discard( )`, alongside the identical handling ZCL_EINV_PDF_STORE
  already had.

`gt_pending` is class-level because ZCL_ELT creates a new instrumentation
instance per call while the LUW that has to flush them spans many.

Callers outside RAP leave `gv_defer` unset and keep the original
immediate write, so nothing in the ELT package changes behaviour.

### What this costs

A LUW that is rolled back now loses its event-log rows. The HANA version
committed them immediately and therefore kept the diagnostics of a failed
call - which is exactly when telemetry is most wanted. That is a real
regression, and it is the price of the contract: the only way to keep
them would be a second LUW, which is a larger change than this one
deserves until someone asks for it.

### The general lesson, which the checker cannot reach

Any inherited class that writes to the database or commits is a latent
dump the moment it is called from a behaviour implementation. Deciding
that statically needs call-graph reachability from every handler method
through arbitrary class calls, which this checker does not attempt. The
practical substitute is a rule of thumb: when wiring an inherited service
class into a RAP action, read it for DML and COMMIT first. ZCL_ELT and
everything under it had never been read with that question in mind.

### 50a. Backticks do not survive the round trip

Noticed on this rebase, not caused by it. Every behaviour definition that
came back from the tenant has its comment backticks doubled:

    /* The tenant asks for ````readonly```` on every key field ... */

written as `readonly` on the way out. Nine `.bdef.asbdef` files carry the
mangling, including ones that predate this work, so it is the serializer
on the round trip rather than anything in the source.

Harmless - BDL comments are not parsed - but it accumulates on every
push/pull cycle, and it is a reason to stop using backticks for emphasis
in behaviour definition comments. Plain quotes or nothing at all.

## 51. ZSB_EINV_DOC is finally whole

The 09/10/2026 push contains `zsb_einv_doc_iwsg.sco2.xml`. The inbound
service that sections 42, 43 and 44 chased for four rounds now exists in
the tenant AND in the repository. Nothing was deleted and nothing was
recreated: it came back when the binding was republished after the
worklist entity was added. The three mechanisms proposed along the way -
the PUBLISHED flag, the orphaned authorization shells, and pulls deleting
the object - were all wrong, and section 44 was right that the honest
answer was the V4-to-V2 recreation of section 27 having dropped it.

Three bindings now ship complete: ZSB_EINV_DOC, ZSB_ELT_CONFIG,
ZSB_EVENT_LOG.

### Five still do not

Rule 57 and the PUBLISHED check now agree on exactly five:

    ZSB_EDOC_AP       ZSB_EDOC_APFLAT    ZSB_EDOC_SB
    ZSB_EDOC_SBFLAT   ZSB_EINV_CONFIG

Each claims `<PUBLISHED>true</PUBLISHED>`, ships ten orphaned
authorization-defaults shells between them, and ships no inbound service.
That is the section 43 shape, and the resolution is the one that worked
for ZSB_EINV_DOC: publish each in the tenant, then push, and the
`_IWSG` + `_IWSG_EXT` + `_IWSG_IBS` objects arrive with it. Nothing in the
repository needs editing first.

The fifteen findings are left standing rather than silenced. They are an
accurate description of a repository that cannot yet rebuild the tenant
from scratch, and they will clear themselves on the next push after the
five are published.

### 51a. A conflict marker reached the tenant

    Unexpected token "<". Expected was "@" or "annotate".
    ZCDS_MET_EINV_WORKLIST, line 1

`<<<<<<< HEAD` was line 1. A merge in GitHub Desktop was committed with
the markers still in the file, and the next pull carried them into ADT.

The conflict itself was empty: the two sides of
`zcds_met_einv_worklist.ddlx.asddlxs` differed by one leading blank line.
It arose because Git was converting LF to CRLF on checkout
(`core.autocrlf`) while abapGit always writes LF, so a file the tenant had
not touched still looked changed on both sides.

Two fixes, and the second is the one that stops it recurring:

* clean the markers out of the file, commit, and replace the source in
  ADT - the broken version sits there inactive until it is overwritten;
* `git config core.autocrlf false` in the repository, or a `.gitattributes`
  carrying `* -text`. The tenant writes LF; anything that rewrites line
  endings on the way in manufactures conflicts out of nothing.

### Rule 61

`<<<<<<<` or `>>>>>>>` anywhere in a source file. Nothing in this package
has a legitimate reason to contain either, the check costs one string
search per file, and it turns a failed activation into a message before
the push. Self-tested.

## 52. The e-invoice ELT chain was never converted

10/10/2026. Debugging a submit showed `ZCL_EINV_SUBMIT` calling
`ZCL_ELT~get_command` where the HANA trigger called
`get_command_einvoice`. Confirmed, and it is wider than one method.

Method counts:

    /CLR/ZCL_ELT   (HANA, package /CLR/ELT)   38 methods
    ZCL_ELT        (cloud, package ZZCLR_ELT) 27 methods

The eleven missing include the complete e-invoice chain - seven methods,
about 730 lines:

    create_files_einvoice          118
    get_command_einvoice           241
    get_exec_program_einvoice       10
    ingest_files_einvoice          220
    ingestion_writeback_einvoice    22
    insert_table_einvoice           72
    trigger_ingestion_einvoice      49

Each is a near-twin of its generic counterpart in line count, so they are
copies with the e-invoice specifics threaded through rather than a
different algorithm.

### What the e-invoice variants actually do differently

Not cosmetic. Three substantive differences:

**A different endpoint.** `get_command_einvoice` reads config
`label_type = 'GET_COMMAND_EINV'`; the generic reads `'GET_COMMAND'`.
Likewise `trigger_ingestion_einvoice` reads `'PRESIGN_URL_EINV'` rather
than the generic presign key.

**A document-specific request.** The e-invoice variant POSTs

    { "action":"EINVOICE_GLOBAL", "commandType":"DATA_EXTRACTION",
      "commandParameter": { "salesDoc":"&SDOC&", "accountingDoc":"&ADOC&",
                            "fiscalYear":"&FYEAR&", "companyCode":"&CCODE&" } }

with the four values substituted. The generic `get_command` takes NO
importing parameters at all - it is a poll for whatever command the
platform has queued. Asking it to submit a named document is a category
error: it has no way to know which document.

**A write-back.** `ingestion_writeback_einvoice` parses the IRN response
and writes it onto the document. The generic chain has no equivalent.

### My defect

I found this gap during the conversion and wrote around it. Two comment
blocks in ZCL_EINV_SUBMIT record the decision:

    "!  3. get_command_einvoice / trigger_ingestion_einvoice do not exist
    "!     on the converted ZCL_ELT of ZZCLR_ELT - only the generic
    "!     get_command / trigger_ingestion do. The generic pair is used,
    "!     which is the better outcome anyway: the e-invoice flow no longer
    "!     needs its own copy of the command engine.

and a second one making the same move for the missing country parameter.
"The better outcome anyway" was a rationalisation of a missing dependency,
not an engineering judgement. The correct response was to stop and report
that the package this conversion depends on is incomplete.

The code activates, the checker passes, and the submit path has been
wrong since it was written. No static check would have caught it: both
methods exist, both compile, and only the HANA source shows that one of
them is the wrong one.

### The decision

Two ways forward, and it is not mine to make:

1. **ZZCLR_ELT gains the seven methods**, which is where their generic
   twins already live and where the HANA original had them. Architecturally
   right; depends on who owns that package and when they can ship.
2. **Port the chain into ZZCLR_GEINV**, using the cloud HTTP client rather
   than CL_HTTP_CLIENT. Self-contained and under our control, but it is a
   second copy of ~730 lines of command engine - precisely what the comment
   above claimed to be avoiding.

Either way the configuration needs `GET_COMMAND_EINV` and
`PRESIGN_URL_EINV` rows, which the generic path never read.

## 53. The command half, reimplemented

10/10/2026. Section 52 established that the e-invoice chain never reached
ZZCLR_ELT. This section is what was done about it.

### ZCL_EINV_ELT_COMMAND

A new class in ZZCLR_GEINV reimplementing `get_command_einvoice`:

* reads the config row labelled **GET_COMMAND_EINV** - a different
  endpoint from the generic GET_COMMAND;
* POSTs the document, with the HANA payload template verbatim:

      { "action":"EINVOICE_GLOBAL", "commandType":"DATA_EXTRACTION",
        "commandParameter": { "salesDoc":"&SDOC&", "accountingDoc":"&ADOC&",
                              "fiscalYear":"&FYEAR&", "companyCode":"&CCODE&" } }

* returns the command for that document, so its command_id is the one the
  ingestion step and the later status refresh quote.

The HANA method is 241 lines; this one is about 60. The difference is all
CL_HTTP_CLIENT construction, proxy handling and duplicated error branches,
none of it legal in ABAP Cloud and none of it needed -
CL_WEB_HTTP_CLIENT_MANAGER covers it, as ZCL_EINV_API_CLIENT already
does for the platform APIs. What IS copied verbatim is the config key,
the payload template and the error texts, so the same words reach a
support call from either system.

**Configuration comes from the ELT instance, not a second SELECT.** The
ZCL_ELT constructor already calls `get_erp_config( )` and leaves the rows
in the public `gt_erp_config`, so the class takes the engine instance and
reads from there. Two reasons: the two must never disagree about which
rows are current, and ZCL_ELT's own selection filters on `SY-SYSID`,
which is not released for ABAP Cloud. Inherited code may use it; new code
in this package may not, and the checker says so.

### The ingestion half is NOT reimplemented

`trigger_ingestion_einvoice` differs from the generic `trigger_ingestion`
in two ways: it posts the extract straight to the endpoint configured as
**PRESIGN_URL_EINV** instead of asking the platform for a presigned URL,
and it then runs `ingestion_writeback_einvoice` to put the IRN back on
the document.

The extraction itself is not e-invoice specific - diffing
`create_files` against `create_files_einvoice` shows the only differences
are removed telemetry calls and a commented-out parameter - so the
generic path does the right work with the wrong upload target.

This is left as the generic call, but **the substitution is now reported
instead of hidden**. If PRESIGN_URL_EINV is maintained, the platform
expects the e-invoice endpoint and this code is not using it, so
ZCL_EINV_SUBMIT puts that in the result message. The submission still
runs, so the rest of the chain can be tested with real responses.

That is a deliberate half-measure and it is worth being explicit about
why. Porting `ingest_files_einvoice` (220 lines of multipart upload) and
`insert_table_einvoice_ingst` (dynamic write-back into the platform's
schema) blind, with no way to test either against the platform, is how
the original defect was produced. The command step is the one that can
be verified now: it either returns a command for the document or it does
not.

### What has to be configured

Two rows in ZTELT_CONFIG that the generic path never read:

    GET_COMMAND_EINV    the e-invoice command endpoint path
    PRESIGN_URL_EINV    the e-invoice upload target

If GET_COMMAND_EINV is missing the submit now fails with
`API to get command not maintained in custom table` - the HANA wording -
rather than silently calling the wrong endpoint.

### 53a. A VALUE clause is a literal

    Unable to interpret "&&".
    ZCL_EINV_ELT_COMMAND, line 100

Mine. The payload template was carried over from the HANA source as

    CONSTANTS gc_payload TYPE string VALUE
      '{ "action":"EINVOICE_GLOBAL", ...' &&
      '  "commandParameter": ...' &&
      '  "fiscalYear": ...'.

which is how it reads in `/CLR/ZCL_ELT` - but there it is an assignment
to a local variable, where an expression is allowed. A `CONSTANTS ...
VALUE` clause takes a literal. Split into `gc_payload_1..3` and
concatenated at the point of use, which keeps the three lines identical
to the original.

Rule 62: `VALUE '<literal>' &&`. Narrow, but it costs one regex and the
mistake is easy to make precisely when porting a multi-line literal out
of older ABAP - which is most of this project. Self-tested.

### 53b. STRING does not pass into a C(30) formal

    The type "STRING" of "ZCL_ELT=>GC_HOSTNAME" is unsuitable for the
    type "C(30)" of "IV_LABEL".
    ZCL_EINV_ELT_COMMAND, line 154

Mine again, and the same shape as 53a: typing a thing after where it is
stored rather than after where it comes from. `config_value` took
`iv_label TYPE ztelt_config-labeltype`, because the label is a column of
that table - but every caller passes one of ZCL_ELT's constants, and
those are `TYPE string`. ABAP Cloud will not convert a STRING actual into
a C(30) formal on the way in.

The parameter is now `TYPE string` and the conversion happens once,
explicitly, in the table expression that does the lookup. The two local
constants `gc_cfg_get_command` and `gc_cfg_presign` moved to STRING with
it, so all six labels in this class now have one type.

Both 53a and 53b are the same class of error and both were found by the
tenant rather than by the checker: a type or syntax rule that holds in
ABAP generally but not in the exact position used. Neither is worth a
rule - 53a got one because the regex is trivial; this one would need a
method-signature index to decide, which the checker does not build.

## 54. The command half works; the extraction dumps in ZZCLR_ELT

10/10/2026, second attempt after section 53. New dump, and it is progress:

    OBJECTS_TABLES_NOT_COMPATIBLE
    Two internal tables are not compatible or convertible.
    ZCL_ELT, method STORE_TABLE_DATA, line 165

### What this proves

The call reached the extraction. Stack:

    LHC_WORKLIST=>WORKLISTSUBMITEINVOICE
      LHC_EINVOICE=>SUBMITEINVOICE
        ZCL_EINV_SUBMIT=>SUBMIT_DOCUMENT
          ZCL_ELT=>TRIGGER_INGESTION
            ZCL_ELT=>CREATE_FILES
              ZCL_ELT=>STORE_TABLE_DATA   <-- dump

`trigger_ingestion` is only reached when the command came back HTTP 200
with `command = DATA_EXTRACTION`. And the schema in the dump is real:

    IS_TABLE = { I_BILLINGDOCUMENTITEM_1 ; X ; ... ; X ;
                 I_BILLINGDOCUMENT ; ... ; { I_BILLINGDOCUMENTITEM ; i_bdi ; ... } }

That is the platform returning an e-invoice extraction schema for the
document that was submitted. ZCL_EINV_ELT_COMMAND does what section 53
set out to do. The GET_COMMAND_EINV endpoint and the document payload are
both working.

### Where it now fails, and why it is not in this package

The failing statement, in inherited ZZCLR_ELT code:

    INSERT LINES OF <lt_table_persist> INTO TABLE <lt_table_append>.

`<lt_table_append>` is the union accumulator; `<lt_table_persist>` holds
the subset of columns flagged persist (13 fields, 552 bytes in the dump).
`INSERT LINES OF ... INTO TABLE` needs compatible line types, and these
two are built independently.

The root cause is in the ELT conversion, not in the schema. HANA built
both tables through one helper:

    /CLR/ZCL_ALV_TABLE_CREATE_RTTC=>create_dynamic_table(
        it_fieldcatalog = ... IMPORTING ep_table = lr_data )

That class did not survive the conversion - there is no equivalent
anywhere in the package. Every call was replaced inline with

    struct_type = cl_abap_structdescr=>create( ltab_fieldcat_* ).
    table_type  = cl_abap_tabledescr=>create( p_line_type = struct_type ).
    CREATE DATA lr_data TYPE HANDLE table_type.

where each component type is resolved separately by
`cl_abap_typedescr=>describe_by_name( tabname && '-' && fieldname )`.
Two catalogues now produce two independently constructed structures,
where the single helper produced consistent ones. The conversion also
swapped `lvc_t_fcat` for `zstr_fcat_tt` and `char1`/`char2` for `string`
in the same method.

This is reachable only by a schema that sets **both** union and persist on
the same table. The generic ELT flows evidently never send one; the
e-invoice extraction does, which is why it surfaces here first.

### A candidate fix, deliberately not applied

The smallest change that keeps the intent would be to stop requiring the
two structures to be compatible:

    LOOP AT <lt_table_persist> ASSIGNING FIELD-SYMBOL(<ls_persist>).
      APPEND INITIAL LINE TO <lt_table_append> ASSIGNING FIELD-SYMBOL(<ls_append>).
      MOVE-CORRESPONDING <ls_persist> TO <ls_append>.
    ENDLOOP.

MOVE-CORRESPONDING is already what the surrounding lines use, and it
tolerates differing structures, which is the whole point.

It is NOT applied here. ZZCLR_ELT is not this project's package, the
method is shared by every ELT flow, and the two previous times today that
something inherited was adjusted on a reading rather than a test, the
reading was wrong. This belongs with whoever owns ZZCLR_ELT, together
with this dump.

### What it means for the worklist

Submit now gets as far as the platform and back, and fails in the
extraction engine. The e-invoice-specific work of sections 52 and 53 is
done and proven. What remains is one defect in the inherited ELT package
and the ingestion endpoint gap already recorded in section 53.

## 55. The async status table is dead in HANA, and stays dead here

### What was asked, and what was wrong with the answer

"Can you give me the AR async status update CDS view similar to
/CLR/ZT_SALES_ST."

The async table `/CLR/ZT_EINV_ASY` had been converted as far as
`ZTEINV_DOC_ASY` and `ZCDS_INT_EINV_DOC_ASY` and stopped there - no
to-parent association, no composition, no consumption view, no service
exposure, no metadata extension. That looked like the same kind of gap as
section 52, and a nine-file set was built to close it.

It was not a gap. Mohan: "table /CLR/ZT_EINV_ASY is not used in Hana
version so similar version is not required in public cloud also. only the
similar structure to /CLR/ZT_SALES_ST."

### What the HANA source says

Every reference to the table in the whole HANA package:

```
  #clr#zcl_einv_base.clas.abap:178    DATA gt_einv_asy TYPE TABLE OF ...
  #clr#zcl_einv_base.clas.abap:1972   SELECT ... FROM /clr/zt_einv_asy
  #clr#zcl_einv_base.clas.abap:2075   SELECT ... FROM /clr/zt_einv_asy
  #clr#elt_einvoice_sub.prog.abap:173 SELECT SINGLE error FROM ...
  #clr#elt_einvoice_sub.prog.abap:199 * commented out
  #clr#elt_einvoice_sub.prog.abap:238 * commented out
```

Four live statements, all of them SELECT. **There is no INSERT, MODIFY or
UPDATE on `/CLR/ZT_EINV_ASY` anywhere in the package.** Nothing writes
it, so it is empty in every system, so every one of those reads returns
nothing and every `coalesce( _Async.<x>, <x> )` falls through to the
document's own column. It is the remains of a design that was replaced by
`/CLR/ZT_SALES_ST`, left in place because a SELECT against an empty table
costs nothing and nobody deleted it.

So the right structure for the AR status is `/CLR/ZT_SALES_ST` ->
`ZTEINV_SALES_ST` -> `ZCDS_INT_EINV_DOC_STAT` -> `ZCDS_CUN_EINV_DOC_STAT`
-> `EInvoiceExchange` + `ZCDS_MET_EINV_DOC_STAT`, and that set already
exists, is exposed, and is on the object page as `ExchangeFacet`. Nothing
needed adding.

### What was reverted

Five new files deleted, seven restored to the pushed version:

```
- src/zcds_cun_einv_doc_asy.ddls.asddls / .xml / .baseinfo
- src/zcds_met_einv_doc_asy.ddlx.asddlxs / .xml
  src/zcds_int_einv_doc_asy.ddls.asddls    to-parent association removed
  src/zcds_int_einv_doc.ddls.asddls        composition removed
  src/zcds_int_einv_doc.bdef.asbdef        child behavior removed
  src/zcds_cun_einv_doc.ddls.asddls        redirect removed
  src/zcds_cun_einv_doc.bdef.asbdef        child behavior removed
  src/zsd_einv_doc.srvd.srvdsrv            expose removed
  src/zcds_met_einv_doc.ddlx.asddlxs       AsyncFacet removed, Error 30
```

Nothing was pulled into the tenant in between, so there is nothing to
undo there.

### What stays

`ZTEINV_DOC_ASY`, `ZCDS_INT_EINV_DOC_ASY`, and the `[0..1]` read
associations in `ZCDS_INT_EINV_DOC_ENR` and `ZCDS_INT_EINV_LIVE` with
their `coalesce( _Async.SyncStatus, status )`. Those are not an
enhancement - they are the faithful conversion of `fill_async_status`,
which does exactly this read in HANA and gets exactly nothing. They are
harmless, they are already activated, and removing them is a separate
decision about deleting a converted table from the tenant.

### The lesson, which is section 52's in reverse

Section 52 was finding a converted object that did less than its HANA
original and writing a justification instead of reporting it. This was
the opposite error: finding a converted object that did less than its
HANA original and assuming the shortfall was a defect, without checking
whether the original did anything at all. `grep` for the writes, not just
the reads. A table nothing writes is not a gap in the conversion.

## 56. The posting half of the ELT loop was never wired up

### What was asked

"In HANA report /CLR/ZELT_EXEC_COMMAND is scheduled as batch job and it
picks the report /CLR/ZELT_POSTING based on the response from GET_COMMAND
api. In this table /CLR/ZT_SALES_ST will be updated in method
insert_table_einvoice. Can you give the similar flow here."

### The HANA flow

```
  /CLR/ZELT_EXEC_COMMAND          (scheduled batch job)
    DO.
      get_command( )                            -> 3 tries, 60s apart
      get_exec_program( is_elt_command )        -> a REPORT NAME
          'DATA_EXTRACTION' | 'DATA_QUALITY'  -> /CLR/ZELT_INGESTION
          'DATA_POSTING'                      -> /CLR/ZELT_POSTING
      IF command = 'NO_COMMAND'. EXIT. ENDIF.
      SUBMIT (lv_program) WITH p_comm = command_id
                          WITH p_meta = metadata
                          WITH p_einv = 'X'      AND RETURN.
      IF elapsed >= 54000. EXIT. ENDIF.
    ENDDO.

  /CLR/ZELT_POSTING
    trigger_posting( is_file_details, iv_einvoice = 'X' )
      get_posting_file( )                 -> download from the S3 URL
      per line of the file:
        deserialize into /CLR/ZSTR_ELT_POSTING
        idempotency check against /CLR/ZT_ELT_SUCC
        IF iv_einvoice IS INITIAL. insert_table( ). ENDIF.   <- skipped
        check_precondition( ) / get_context_data( )
        CASE posting_type
          WHEN 'BAPI_ACC_DOCUMENT_POST'. bapi_acc_document_post( ).
          WHEN 'IRN_WRITEBACK'.          insert_table_einvoice( ).
        ENDCASE.

  insert_table_einvoice
    per entry in schema-insert_table:
      CREATE DATA ... TYPE (<name>)          <- the platform names the table
      fill components by name from the JSON
      MODIFY (<name>) FROM TABLE             <- for AR this is /CLR/ZT_SALES_ST
      one /CLR/ZT_ELT_SUCC row per record written
```

The table is never named in the code. The platform's posting file says
which table to write, and for the AR status flow it says
`/CLR/ZT_SALES_ST`. That is the design, and it is worth preserving: the
same method serves the next write-back the platform defines.

### What is in the converted package

Four things are missing, and they are missing in a chain, which is why
none of them has been noticed.

**1. `ZCL_ELT~elt_exec_command` never dispatches.** It calls
`elt_ingestion` for every command whose `command_id` is filled. There is
no `CASE` on the verb. A `DATA_POSTING` command is handed to the
ingestion path.

**2. `ZCL_ELT~get_exec_program` is an empty shell.** Every statement in
its body is commented out and it has no `RETURNING` parameter:

```abap
METHOD get_exec_program.
  IF is_elt_command-result-command EQ 'DATA_EXTRACTION' OR
     is_elt_command-result-command EQ 'DATA_QUALITY'.
*   rv_program_name = 'ZCL_ELT'."'/CLR/ZELT_INGESTION'.
  ELSEIF is_elt_command-result-command EQ 'DATA_POSTING'.
*   rv_program_name = '/CLR/ZELT_POSTING'.
  ...
ENDMETHOD.
```

That is understandable - it returned a report name, and ABAP Cloud has no
reports - but gutting it without replacing the decision removed the
decision.

**3. `ZCL_ELT~trigger_posting` has no caller** anywhere in the
repository, and its `CASE posting_type` has both branches commented out.
Even when reached it does nothing per row.

**4. `ZCL_ELT~insert_table_einvoice` does not exist.** It is one of the
eleven e-invoice methods recorded as missing in section 52 - the same
hole that swallowed `get_command_einvoice`.

**So nothing in the converted package has ever written `ZTEINV_SALES_ST`.**
The table, `ZCDS_INT_EINV_DOC_STAT`, `ZCDS_CUN_EINV_DOC_STAT`, the
`EInvoiceExchange` entity and the Exchange Status table on the object page
are all correct, all activated, and all permanently empty. This is the
same class of finding as section 52, reached from the other end: there the
missing method was found by debugging a submit, here by asking what writes
a table.

### The cloud flow

Two reports become no reports. The driver/child split existed in HANA
because `SUBMIT ... AND RETURN` was the only way to give each command its
own LUW and its own dump boundary; a method call is enough.

```
  ZCL_EINV_ELT_EXEC_JOB                       (Application Job)
    if_apj_rt_exec_object~execute
      DO.
        NEW zcl_elt( ) / NEW zcl_einv_elt_posting( )
        get_command( )                        -> P_RETRY tries
        get_action( ls_elt_command )          -> I / P / N / ?
          N -> log, EXIT
          P -> trigger_posting_einvoice( metadata-file_details )
          I -> not this job's work: log and EXIT, command stays queued
          ? -> log and EXIT
        IF elapsed >= P_MAXSEC. EXIT. ENDIF.
      ENDDO.
      write_log( )                            -> ZAJL_EINV_EXECUTION

  ZCL_EINV_ELT_POSTING
    get_action                -> the get_exec_program branch, as a decision
    trigger_posting_einvoice  -> /CLR/ZELT_POSTING with p_einv = 'X'
    insert_table_einvoice     -> the dynamic MODIFY + ZTELT_SUCCESS ledger
```

Both classes are in `ZZCLR_GEINV`. `ZCL_ELT` is not this project's
package, it is shared by every ELT flow in the tenant, and section 53 set
the precedent when the command half was reimplemented rather than patched
in place. The four `ZZCLR_ELT` defects above are reported, not fixed here.

### Five places the cloud version is not a copy

**`WAIT UP TO` is not released.** HANA waits 60 seconds between
`get_command` retries. There is no released way to sleep in ABAP Cloud, so
the retries are immediate and the back-off is the job schedule: a run that
cannot reach the platform ends and the next scheduled run tries again.

**The timeout was fifteen hours, not fifteen minutes.** The HANA comment
says `"15 minutes time elapsed"` and the code says `IF ( lv_secs >= 54000 )`.
54000 seconds is 15 hours - someone multiplied by 60 once too often. The
converted `elt_exec_command` carries the same number. `P_MAXSEC` here is a
job parameter defaulting to 900, which is the fifteen minutes the comment
always claimed. The inherited 54000 is left alone.

**`insert_table( )` is NOT called.** HANA guards it:
`IF iv_einvoice IS INITIAL. insert_table( ). ENDIF.` - on the e-invoice
path only the `IRN_WRITEBACK` branch writes. The converted
`ZCL_ELT~trigger_posting` dropped that guard and calls it unconditionally,
so if it were ever reached on an e-invoice command it would write every
row twice. Omitting it here is deliberate, and is commented as such in the
source so it does not look like the same omission.

**Dynamic SY access replaced by three explicit fields.** HANA does
`ASSIGN COMPONENT <value> OF STRUCTURE sy`, which ABAP Cloud does not
allow. The platform only ever asks for `DATUM`, `UZEIT` and `UNAME`, so
those three are served from `cl_abap_context_info`; anything else is left
initial rather than silently wrong.

**The dynamic table name is restricted to this package.**
`cl_abap_dyn_prg=>check_table_name_str` is what makes the dynamic `MODIFY`
legal at all. `ZCL_ELT~insert_table` passes `packages = VALUE #( )`,
meaning any table in the system. Here it is `packages = 'ZZCLR_GEINV'`,
which turns "the platform may write any table" into "the platform may
write our tables". If a future write-back legitimately targets a table
outside the package, this is the line that will reject it, and it should
be widened deliberately rather than removed.

### An important operational constraint

`ZCL_ELT_EXEC_COMMAND_JOB` and `ZCL_EINV_ELT_EXEC_JOB` consume the same
command queue, and a command handed to the wrong one is lost: the platform
marks it delivered and the work never happens.

While `ZZCLR_ELT` is unfixed:

* the generic job consumes a `DATA_POSTING` command and discards it,
* this job declines an extraction command and stops, leaving it queued.

So this job is safe to schedule alongside the generic one, and the generic
one is not. If both must run, run them at different times, or wait for the
`ZZCLR_ELT` fix and then use only the generic job with a working dispatch.

### What is still needed in the tenant

1. Pull `ZCL_EINV_ELT_POSTING` and `ZCL_EINV_ELT_EXEC_JOB`, activate.
2. Create the **Application Job Catalog Entry** for
   `ZCL_EINV_ELT_EXEC_JOB` in ADT (New > Other ABAP Repository Object >
   Application Job Catalog Entry) and a **Job Template** for it. Those two
   objects carry generated ids, so they are created in the tenant rather
   than shipped as hand-written XML - the same way the existing
   `ZBC_ELT_EXECUTE_COMMAND_JOB` catalog was made.
3. Add the catalog entry to a business catalog and the role, so Schedule
   Jobs can see it.
4. Schedule it. Frequency follows how quickly the platform is expected to
   return write-backs; every 15 minutes with `P_MAXSEC = 900` gives a
   continuously draining queue with no overlap.

### What is NOT covered

`BAPI_ACC_DOCUMENT_POST`. That branch belongs to the generic engine, not
to this package, and a posting file reaching `trigger_posting_einvoice`
with that type is counted and skipped rather than written. The AP posting
flow is a separate conversion.

## 57. The ingestion upload went to the wrong endpoint

### What was asked

"When I am submitting e-invoice, for getting pre sign url it should read
from PRESIGN_URL_EINV and not GENERATE_PRESIGN."

Correct, and the gap is larger than the URL.

### What HANA does

```abap
METHOD trigger_ingestion_einvoice.
  create_files_einvoice( it_tables = is_config-tables ).

  READ TABLE gt_erp_config ASSIGNING FIELD-SYMBOL(<lfs_presign_url>)
      WITH KEY label_type = 'PRESIGN_URL_EINV'.
  IF sy-subrc EQ 0.
    DATA(lv_url) = <lfs_presign_url>-low.
  ELSE.
    ls_einv-error = 'Presigned URL not maintained in custom table'.
    MODIFY /clr/zt_einv FROM ls_einv.
    RETURN.
  ENDIF.

  ingest_files_einvoice( ... iv_presigned_url = CONV #( lv_url )
                         IMPORTING ev_response = DATA(lv_response) ).
  IF lv_status_code EQ '200'.
    ingestion_writeback_einvoice( is_irn_response = lv_response ... ).
  ENDIF.
ENDMETHOD.
```

No `generate_pre_sign` call anywhere on this path. The config row is read
and posted to directly.

### What the submit was doing

`ZCL_EINV_SUBMIT` called `ZCL_ELT~trigger_ingestion`, which runs

```
  create_files -> generate_pre_sign -> ingest_files -> post_command
```

Section 53 recorded that as a known substitution and had the action say
so in its result message. That was better than hiding it and still too
generous: the comment said "the generic trigger_ingestion does the right
work with the wrong upload target". Only the first half of that is true.
Comparing the two methods line by line:

| | generic `ingest_files` | `ingest_files_einvoice` |
|---|---|---|
| URL | one-time URL from `GENERATE_PRESIGN` | `HOSTNAME` + `PRESIGN_URL_EINV` |
| verb | `PUT` | `POST` |
| auth | none - the presigned URL carries it | `x-clear-auth-token`, `x-erp-instance-id` |
| idempotency | none | `x-idempotency-key` = command id |
| content type | set by the presign response | `application/zip` |
| response body | read into a local and **discarded** | returned as `ev_response` |
| followed by | `post_command` | `ingestion_writeback_einvoice` |

Four independent defects, not one:

1. **The endpoint.** Two different APIs, two different config rows.
2. **The verb.** A PUT to a Clear API endpoint is not a POST to it.
3. **The headers.** With no `x-clear-auth-token` the e-invoice endpoint
   would reject the upload outright. And with no `x-idempotency-key`, a
   resubmitted command does not collapse onto the existing IRN - the
   platform has nothing to key on, so one invoice can end up with two.
4. **The response.** `ingest_files` assigns the body to `lv_json_response`
   and never exports it. On the generic path that is fine, because the
   answer arrives later through `post_command` and the platform's
   write-back. On the e-invoice path the body **is** the IRN. The generic
   path throws away the thing the whole submission is for.

So the submission could not have worked even with the right URL patched
in. This is the third finding of the same shape as section 52, and the
pattern is now clear enough to state plainly: **when the conversion
dropped a `*_einvoice` method, the generic method next to it was wired up
in its place, and the difference between them was assumed rather than
read.** `get_command` for `get_command_einvoice`, nothing at all for
`insert_table_einvoice`, `trigger_ingestion` for
`trigger_ingestion_einvoice`.

### What was built

`ZCL_EINV_ELT_INGEST`, in `ZZCLR_GEINV` - the third of three classes that
restore the e-invoice chain outside the inherited package:

```
  ZCL_EINV_ELT_COMMAND   get_command_einvoice            (section 53)
  ZCL_EINV_ELT_INGEST    trigger_ingestion_einvoice      (this section)
                         ingest_files_einvoice
  ZCL_EINV_ELT_POSTING   insert_table_einvoice           (section 56)
                         the dispatch, trigger_posting
```

`trigger_ingestion( )` does what the HANA method does, in order:
`create_files( )` for the extract, `PRESIGN_URL_EINV` for the endpoint,
the error text `'Presigned URL not maintained in custom table'` verbatim
when the row is missing, then the POST with the four headers and the zip
as a binary body, returning status, reason and **response**.

`create_files( )` is the one thing still shared with the generic path.
HANA has `create_files_einvoice`, but the two differ only in which
telemetry actions they log - the extraction logic is identical - so the
generic one is called rather than copied. That is a substitution too, and
unlike the four above it is safe: the bytes produced are the same bytes.
It is named here so the next person does not have to rediscover that it
was a choice.

`ZCL_EINV_SUBMIT` now calls it, and the apologetic message about using the
generic endpoint is gone because the generic endpoint is gone.

### Still missing

`ingestion_writeback_einvoice`. The response is now captured instead of
discarded, so the write-back has something to parse when it is built, but
until then the IRN reaches the log and not the document. That is the last
unported method of the e-invoice chain and the natural next piece of work.

### Configuration

`ZTELT_CONFIG` needs `PRESIGN_URL_EINV` maintained with the path from the
HANA system, alongside `GET_COMMAND_EINV` from section 53. Neither has a
default and neither can be guessed - the submission now fails with
`'Presigned URL not maintained in custom table'` rather than quietly
posting somewhere else, which is the point.

## 58. Two activation errors the checker should have caught

### What the tenant said

```
The use of Data Element SYTABIX is not permitted.    ZCL_EINV_ELT_POSTING  128
The use of Data Element SYTABIX is not permitted.    ZCL_EINV_ELT_POSTING  192
Redundant conversion for type SYTABIX.               ZCL_EINV_ELT_POSTING  192
Redundant conversion for type STRING.                ZCL_EINV_ELT_POSTING  302
Redundant conversion for type VALUE.                 ZCL_EINV_ELT_INGEST   187
```

Everything else in that list is `ZCL_ELT` in client 100 - inherited code,
reported as *Syntax Check Problems* rather than activation problems, and
not introduced by this work. They are the same eight advisory findings the
checker already lists under "code inherited verbatim from ZZCLR_ELT".

### `SYTABIX` is not `sy-tabix`

`SY-TABIX` the system field is fine. `SYTABIX` the DDIC **data element** is
not released for ABAP Cloud, along with `SYSUBRC`, `SYDBCNT` and the rest
of that family. The two look identical at a glance and the inherited
`ZCL_ELT` uses `TYPE sy-tabix`, which is the released form - copying its
*shape* while typing the data element name got the wrong one.

```abap
  iv_row_no TYPE sytabix          " data element - rejected
  iv_row_no TYPE sy-tabix         " system field component - fine
  iv_row_no TYPE i                " what it is used as - also fine
```

Changed to `TYPE i`. A row number is an integer and nothing here needs it
to be anything more specific; the conversion to `sy-tabix` happens on the
call to `check_precondition`, which is typed that way in the inherited
class.

### "Redundant conversion" is an error here, not a warning

Three `CONV`s wrapped something that already had the target type:

```abap
  DATA(lv_row_no) = CONV sytabix( sy-tabix ).        -> = sy-tabix.
  val = CONV string( <ls_insert_table>-name )        -> val = ...-name
  value = CONV #( iv_command_id )                    -> value = iv_command_id
```

In classic ABAP each is a warning. In a strict ABAP Cloud class it stops
activation. All three came from copying an expression together with the
`CONV` that wrapped it in a context where it *was* needed.

### A missing log subobject, found while fixing these

`ZCL_EINV_ELT_EXEC_JOB` logs to `ZAJL_EINV_EXECUTION` subobject
`JOB_LOG_ELT_POST`, which was not declared in
`zajl_einv_execution.aplo.json`. It would not have failed activation - the
`save_log` is inside a TRY and a logging failure is deliberately swallowed
so a job never dies over a log entry - so the first run would simply have
produced no log at all, which is a worse way to find out. Added alongside
the four existing subobjects.

### Rule 63

Both error classes are decidable from the source, so they are now rules:
non-released `SY*` data elements in this package's own classes, and
`CONV string( )` around something already declared `TYPE string`. Verified
by reintroducing the `SYTABIX` declaration and watching the count go 15 ->
16 with the right message, then restoring it.

The `CONV #( )` shape is only partly catchable - deciding redundancy there
needs the target parameter's type, which the checker does not resolve - so
rule 63 covers the explicit-type shape and the inferred one stays a
tenant-side finding. Worth saying plainly rather than implying the rule is
complete.

### The pattern worth noting

This is the fourth round in this session where new code was written by
copying the shape of neighbouring code rather than from the rules, and the
differences surfaced one activation at a time. Sections 48 and 48a are the
long version. What is different here is that both errors were statically
decidable and the checker simply had no rule for them - which is the best
case, because it is fixable once.

## 59. One config row is a path, the other is a URL

### What the debugger showed

```
IV_URL = https://api.mea.cleartax.comhttps://api.mea.cleartax.com/one-integration/sync/EINVOICE_GLOBAL
```

`ZCL_EINV_ELT_INGEST` built the upload URL as `HOSTNAME` + `PRESIGN_URL_EINV`.
`PRESIGN_URL_EINV` already contains the host, so the host appeared twice.

### Why, and why the two rows differ

The HANA source treats the two e-invoice config rows differently, on
purpose:

```abap
" get_command_einvoice, line 4118
url = CONV #( lv_hostname && lv_url )      " GET_COMMAND_EINV is a PATH

" ingest_files_einvoice, line 4390
url = iv_presigned_url                     " PRESIGN_URL_EINV is a URL
```

In `ingest_files_einvoice`, `lv_hostname` is read but never concatenated -
it is a **guard**, deciding which branch runs: a maintained HOSTNAME means
"go out over HTTP to the URL given", an empty one means "use the RFC
destination". There is no RFC branch in the cloud, so an empty HOSTNAME is
simply an unconfigured system, and the guard stays.

The converted generic `ZCL_ELT~ingest_files` does the same thing - it
passes `iv_presigned_url` straight to `create_by_url` - which is the
second place the correct shape was sitting in plain sight.

### The mistake

`ZCL_EINV_ELT_COMMAND` was written first and concatenates, correctly.
`ZCL_EINV_ELT_INGEST` was written next, and the URL construction was
copied from its sibling rather than read from the HANA method it was
replacing.

That is the same error as sections 52, 56 and 57, at one level smaller:
there, a `*_einvoice` method was replaced by the generic method beside it
without reading the difference; here, one new class copied another new
class without reading the difference. Four rounds of the same habit. The
rule that would have caught all four is not a checker rule - it is to read
the HANA method being replaced, line by line, every time, including the
parts that look boilerplate. URL construction looks like boilerplate.

### The fix

`lv_url` is used as-is. HOSTNAME is still read and still required, as the
guard it is in HANA. One addition that is not in the HANA source: a row
maintained as a path rather than a full URL now fails with

```
PRESIGN_URL_EINV must be a full URL (starting http), not a path: <value>
```

rather than inside `create_by_url` with a message about the destination.
The two rows look alike in the config table and nothing else distinguishes
them, so the code should say which one is wrong. The check is
case-insensitive - `CP`/`NP` are not, and a hand-maintained row may read
`HTTPS://`.

Both classes now carry a comment naming the asymmetry and pointing at the
other, so the next person does not "fix" the one that is right.

### Configuration, restated

| row | shape | example |
|---|---|---|
| `HOSTNAME` | scheme + host | `https://api.mea.cleartax.com` |
| `GET_COMMAND_EINV` | path, HOSTNAME prepended | `/one-integration/...` |
| `PRESIGN_URL_EINV` | **absolute URL** | `https://api.mea.cleartax.com/one-integration/sync/EINVOICE_GLOBAL` |


## 60. The IRN write-back payload needs seven field renames

### What was supplied

The platform-side `IRN_WRITEBACK` posting schema for the HANA system - the
JSON that `/CLR/ZELT_EXEC_COMMAND` fetches and `insert_table_einvoice`
turns into a `MODIFY /CLR/ZT_SALES_ST`.

### Seven of its field names do not exist in the cloud table

`insert_table_einvoice` matches every `name` in the payload against a
component of the target structure, and **skips silently** when there is no
match:

```abap
ASSIGN COMPONENT <lfs_data_row>-name OF STRUCTURE <lfs_row> TO <lfs_value>.
IF sy-subrc IS INITIAL.
  ...
ENDIF.
```

So a renamed column is not an error. It is a column that quietly never
gets written. The row lands with those values empty and nothing anywhere
says why.

Comparing `/CLR/ZT_SALES_ST` with `ZTEINV_SALES_ST` column by column:

| HANA / payload | Public Cloud |
|---|---|
| `PA_EXCHG_STAT_RESCODE` | `PA_EXCHG_RESCODE` |
| `PA_EXCHG_STAT_RESMSG` | `PA_EXCHG_RESMSG` |
| `PPF_LCPMNTCOLL_STAT` | `PPF_LCPMNT_STAT` |
| `PPF_LCPMNTCOLL_RESCODE` | `PPF_LCPMNT_RESCODE` |
| `PPF_LCPMNTCOLL_RESMSG` | `PPF_LCPMNT_RESMSG` |
| `EINVOICE_IDENTIFIER` | `EINV_IDENTIFIER` |
| `EINVOICE_TYPE` | `EINV_TYPE` |

The other twenty-four names match exactly.

### Why they were renamed, and why it is a problem

The two HANA tables disagree with each other: `/CLR/ZT_EINV` calls these
`EINV_IDENTIFIER` and `EINV_TYPE`, `/CLR/ZT_SALES_ST` calls them
`EINVOICE_IDENTIFIER` and `EINVOICE_TYPE`. The conversion normalised the
status table onto the document table's spellings, and shortened
`PPF_LCPMNTCOLL_*` and `PA_EXCHG_STAT_*` while it was there.

As tidying, defensible. As a conversion decision, it broke the stated
principle of this package - recorded in `ZCL_EINV_SUBMIT` and honoured
exactly by `ZTEINV_DOC`, which keeps all twenty-two of `/CLR/ZT_EINV`'s
names unchanged:

> only the table NAME in the platform-side schema has to change, not the
> field mapping.

`ZTEINV_DOC` holds to that. `ZTEINV_SALES_ST` does not, and the cost is
that the platform schema has to be edited per field rather than per table.

Renaming the columns back was considered and rejected: the table is
already activated in the tenant, and `ZCDS_INT_EINV_DOC_STAT`, the
behaviour mapping, `ZCDS_CUN_EINV_DOC_STAT` and
`ZCDS_MET_EINV_DOC_STAT` all name them. Seven lines in a JSON schema is
the cheaper side of that trade. It is a trade, though, not a free choice,
and the next table converted should keep the names.

### Two more things in the payload

**`insertTable` has no `name`.** The supplied JSON is
`"insertTable":[{"data":[[...]]}]` with no `"name"` key. `CREATE DATA ...
TYPE (<name>)` cannot work without it, so either the real payload carries
it and it was trimmed, or it is genuinely missing and the HANA posting
dumps. The cloud mapping below supplies `"name":"ZTEINV_SALES_ST"`
explicitly - worth confirming against the live HANA schema.

**`zsigned_inv` is lower case** where the other thirty-one names are upper.
`ASSIGN COMPONENT` on a structure is not reliably case-insensitive, and a
name that does not match is skipped by the same silent `sy-subrc` test
above - so that one column could have been the only one never written.
`ZCL_EINV_ELT_POSTING~insert_table_einvoice` now wraps the lookup in
`to_upper( )`, which costs nothing and removes the class of problem.

**`UNIQUE_IDENTIFIER`** is not a column of `/CLR/ZT_SALES_ST` either, so
HANA skips it today. Left in the cloud mapping for parity; it is ignored
at both ends.

### The mapping

`doc/irn_writeback_public_cloud.json` in this repository.

## 61. The ingestion write-back: what exists, what does not, and the payload

### What was asked

Whether the logic of `/CLR/EINV_EWAY_TRIGGER_ELT` - and the
`ingestion_writeback_einvoice` it leads to - exists in the cloud version,
plus the response mapping.

### The function module itself IS converted

`/CLR/EINV_EWAY_TRIGGER_ELT` is sixty lines and does three things:

```abap
DO 2 TIMES.                                   " retry, WAIT UP TO 3 SECONDS
  lo_elt->get_command_einvoice( ... ).
  IF lv_status_code = 200. EXIT. ENDIF.
ENDDO.
IF ls_elt_command-result-command NE 'DATA_EXTRACTION'.
  ls_einv-error = 'Command Not Found'.  MODIFY /clr/zt_einv.  RETURN.
ENDIF.
lo_elt->trigger_ingestion_einvoice( ... ).
```

That is exactly `ZCL_EINV_SUBMIT~submit_document`, which now calls
`ZCL_EINV_ELT_COMMAND` (section 53) and `ZCL_EINV_ELT_INGEST` (section
57), checks for `DATA_EXTRACTION` and returns the same
`'Command Not Found'`. The only deliberate difference is the retry: the FM
waits 3 seconds and tries twice, which is neither legal in ABAP Cloud nor
sensible inside a RAP action a user is waiting on.

So the trigger is there. What is not there is what happens to the answer.

### `ingestion_writeback_einvoice` is NOT converted

It and `insert_table_einvoice_ingst` are the last two of the eleven
missing e-invoice methods from section 52. The chain in HANA:

```
  ingest_files_einvoice  -> 200 -> ingestion_writeback_einvoice( ev_response )
    SPLIT response AT newline, one JSON document per line
    CASE posting_type
      WHEN 'IRN_WRITEBACK' or 'NOT_APPLICABLE_TRANSACTION'
        -> insert_table_einvoice_ingst  -> MODIFY /CLR/ZT_EINV
```

`ZCL_EINV_ELT_INGEST` now **captures** that response rather than
discarding it, which the generic `ingest_files` did not - so the input to
the write-back exists. Nothing consumes it yet.

### `insert_table_einvoice_ingst` is not `insert_table_einvoice`

The two look alike and differ in one block that matters: after mapping the
payload, the ingestion variant **backfills** from its own parameters.

```abap
CRDAT    = sy-datum          " always, regardless of payload
CRTIME   = sy-uzeit          " always
CRUSER   = sy-uname          " always
VBELN / BUKRS / BELNR / GJAHR = iv_*        when the payload left them initial
STATUS   = 'NOT APPLICABLE TRANSACTION'     when the payload left it initial
COMMAND_ID = iv_command_id                  when the payload left it initial
```

This is why the payload's `CRDAT`/`CRTIME` entries are `"type":"SYSTEM"`
with an empty `value`: the dynamic `ASSIGN COMPONENT '' OF STRUCTURE sy`
fails, the field stays initial, and the backfill fills it a moment later.
A cloud implementation must do the backfill explicitly - section 56
already replaced dynamic `SY` access with three named fields for the
posting variant, and the same applies here.

### The payload: no renames needed, one probable typo

Unlike the sales-status table of section 60, `ZTEINV_DOC` keeps every one
of `/CLR/ZT_EINV`'s column names. The only change the mapping needs is the
table name.

| payload field | `/CLR/ZT_EINV` | `ZTEINV_DOC` |
|---|---|---|
| `STATUS`, `ERROR`, `INVID`, `UUID`, `VBELN`, `BELNR`, `BUKRS`, `GJAHR`, `DOC_TYPE`, `B2C`, `CRDAT`, `CRTIME` | yes | yes |
| `ZSIGNED_QR_CODE` | **no** | no - the column is `ZSIGNED_QRCODE` |
| `VALID_DATE`, `VALID_TIME`, `CANCEL_DATE`, `CANCEL_TIME`, `UNIQUE_IDENTIFIER`, `UNIQID` | no | no |

**`ZSIGNED_QR_CODE` against a column called `ZSIGNED_QRCODE`.** One
underscore. `ASSIGN COMPONENT` misses, `sy-subrc` is non-zero, the field
is skipped without a word - so the signed QR code is not being stored in
HANA either, and has not been for as long as this payload has been in use.
That is worth raising with whoever maintains the platform schema; it is
not a conversion defect. The cloud mapping below spells it `ZSIGNED_QRCODE`
so it actually lands.

The other six have no column in either table. They look like a different
country variant's schema (validity and cancellation timestamps, a
composite unique id) carried along in a shared template. They are ignored
at both ends and are kept in the mapping for parity.

### The mapping

`doc/irn_writeback_ingest_public_cloud.json`.

### What building the write-back will require

Not a line-for-line port. `MODIFY ZTEINV_DOC` cannot be issued from where
this code runs: `ZCL_EINV_SUBMIT` is called from a RAP action, and a direct
table write in the interaction phase is exactly the
`BEHAVIOR_ILLEGAL_STATEMENT` of section 50. Two options, and the choice is
a real one rather than a detail:

1. **Through the business object.** Map the payload onto
   `ZCDS_INT_EINV_DOC` fields and `MODIFY ENTITIES` - keeps the BO as the
   only writer, gets locking and authorization, but means a static mapping
   and loses the point of the dynamic schema.
2. **Deferred to the save phase**, like the telemetry fix of section 50 -
   keeps the dynamic write but puts a raw table write back into a package
   that had just stopped doing them.

Option 1 is the better fit for a table this package owns and whose shape
is known; the dynamic form earns its keep in the posting flow, where the
platform genuinely chooses the table. Say the word and I will build it
that way.

## 62. The ingestion write-back, through the business object

Closes the last of the eleven methods from section 52. The e-invoice
chain is now complete end to end.

### The split

HANA does the mapping and the write in one method. Neither form of write
is available where this code runs, so the two are separated:

```
  ZCL_EINV_ELT_INGEST~parse_writeback          the mapping and the backfill
    -> returns a filled ZTEINV_DOC work area, touches no database

  ZCL_EINV_SUBMIT~submit_document              carries it in RS_RESULT
    -> RS_RESULT-WRITEBACK, RS_RESULT-HAS_WB

  ZBP_CDS_INT_EINV_DOC~submiteinvoice          applies it
    -> merged into the LT_UPDATE the action already builds,
       written by the MODIFY ENTITIES it already issues
```

Two separate rules force the split, and it is worth having both on the
record because each was learned the hard way earlier in this conversion:

* a direct `MODIFY ZTEINV_DOC` in the interaction phase is the
  `BEHAVIOR_ILLEGAL_STATEMENT` of section 50;
* `MODIFY ENTITIES ... IN LOCAL MODE` is legal only inside the behaviour
  pool of the BO it names - section 48a, and checker rule 59 exists
  because of it. `ZCL_EINV_ELT_INGEST` is not that pool.

**The dynamic mapping is not lost.** `parse_writeback` still resolves
every field by `ASSIGN COMPONENT` against a `ZTEINV_DOC` work area, so the
platform still names the fields. What moved is the write, not the
mapping - and a local structure is not a database, so the dynamic part is
legal exactly where it was.

### One update, not two

The write-back fields are merged into the row the action had already
appended for that document, rather than appended as a second row or
written by a second `MODIFY ENTITIES`. One document, one row, one update,
one LUW. A second update would have been two versions of the same row in
one change set, which RAP resolves in an order nobody should rely on.

`UPDATE FIELDS ( ... )` had to grow from four names to fourteen. **A field
left out of that list is ignored even when its `%control` flag is on** -
which is a completely silent way to lose the entire write-back, and the
kind of thing that would have been debugged for an afternoon.

### Three deliberate differences from HANA

**The platform's status wins.** `insert_table_einvoice_ingst` writes the
payload's `STATUS`; the submit result's `'SUBMITTED'` is set first and
overwritten when a write-back arrives. A platform answering `FAILURE` with
thirteen validation messages is more use than `SUBMITTED`. With no
write-back, the submit status stands.

**`CRDAT` / `CRTIME` / `CRUSER` are not carried over.** HANA sets them on
every write-back, which quietly turns "created" into "last answered". Here
the row already exists with its real creation stamp from
`PickUpDocuments`, and overwriting it would destroy the only record of
when the document entered the worklist. `LocalLastChangedAt` already
answers "when did this last change". The backfill still fills them in the
work area, for parity and for any caller that writes a new row.

**The last write-back line wins.** HANA loops every line in the response
and writes each one immediately. `parse_writeback` returns one structure,
so the last `IRN_WRITEBACK` or `NOT_APPLICABLE_TRANSACTION` line wins -
identical for a single document, which is all this path ever submits, and
it avoids handing back a table the caller has no key for. If the platform
ever returns several documents in one response this is the line to change,
and it is marked in the source.

**`NOT_APPLICABLE_TRANSACTION` is handled**, not just `IRN_WRITEBACK`.
HANA accepts both and treats them identically - the platform saying "this
document is out of scope" is a result, not an error.

### SYSTEM-typed fields

The payload sends `CRDAT` and `CRTIME` as `"type":"SYSTEM"` with an
**empty** value. In HANA the dynamic `ASSIGN COMPONENT '' OF STRUCTURE sy`
fails, the field stays initial, and the backfill fills it a moment later.
So the SYSTEM branch never does anything on this payload. ABAP Cloud does
not allow dynamic `SY` access at all, and the branch is an explicit no-op
with that reasoning in a comment - the same treatment section 56 gave the
posting variant, where the three fields the platform actually asks for are
served by name.

### A failure mode worth stating

A caller that ignores `RS_RESULT-WRITEBACK` gets the old behaviour -
submitted, no IRN on the document - rather than a dump. That is the right
failure mode for an optional field on a result structure, and it means the
scheduled submit job keeps working unchanged until it is taught the same
merge.

## 63. The upload returns a different shape than the write-back parses

### What came in

The actual body returned by the upload endpoint:

```json
{ "ErrorDetails": [...],
  "Success": "false",
  "DocumentResponses": [ { "DocumentId": null, "Success": "false",
                           "UniqueId": null, "ErrorDetails": [...],
                           "WarningDetails": null, "CustomFields": null } ] }
```

### It is not what section 62 parses

`ZCL_EINV_ELT_INGEST~parse_writeback` deserializes into
`ZSTR_ELT_POSTING` and looks for `postingType` and `insertTable`. This
envelope has neither, so the parser finds no write-back line, returns
`has_wb = abap_false`, and the document is updated with the submit status
only. No IRN, no error detail, **and no complaint** - the same silent-skip
behaviour that hid the field renames in section 60.

Two shapes are in play:

| | shape | self-describing? |
|---|---|---|
| **A** posting file | `{ idempotencyKey, postingType, insertTable[{name,data}] }` | yes - names its own table and columns |
| **B** sync envelope | `{ Success, ErrorDetails, DocumentResponses[] }` | no - a fixed API contract |

Section 61's sample was shape A, supplied as "the response received in
`ingest_files_einvoice`", and section 62 was built to parse it. This is
shape B, from the live system. Both are real. The parser has to accept
both, and it has to say which one it got rather than returning "nothing
found" for an unknown shape and an empty response alike.

This is the fifth time in this conversion that a sample has turned out not
to be the whole story. The pattern is consistent enough to name: **one
sample is an example, not a specification.** Where the platform's contract
is involved, the code should recognise what it is given and say so when it
cannot, rather than assume the shape it was first shown.

### Where shape B's fields go

`doc/sync_response_mapping.md` has the field-by-field table. The parts
that are decisions rather than mappings:

**`ZTEINV_SALES_ST` should not be written from this response.** The sync
body is a submission acknowledgement; the exchange-status pipeline - PA
exchange, invoice submission, lifecycle, rejection, refusal, payment - is
filled later by the async `IRN_WRITEBACK` posting file the batch job
fetches (sections 56 and 60). Writing a half-filled row from here puts a
line in front of the one that is coming, and the Exchange Status table
then shows one row disagreeing with itself. `DocumentResponses[0].Success`
onto `PA_EXCHG_STAT` is the specific trap: that column carries `SUBMITTED`
/ `PROCESSING` in the async payload, a pipeline state, not a boolean.

**`ErrorDetails` belongs in `ZTEINV_ERR`,** not only joined onto
`ZTEINV_DOC-ERROR`. That table is behind `ZCDS_CUN_EINV_DOC_ERR` and the
API Errors facet, so it is the difference between "FAILURE" on the object
page and "FAILURE, and here are the four reasons". Written through
`_Error` from the behaviour pool, same rule as section 62.

**`CustomFields` carries the SAP keys, and also an Oracle EBS payload.**
`VBELN`, `BELNR`, `BUKRS` and `GJAHR` come back echoed from what the
extract sent. Alongside them sit `MODULE: "AR"`, `TRXID`, `ORGID`, `TRN`
and `TRXNUM` — the envelope is shared with an EBS integration, and
`TRXNUM` must not be mapped to `VBELN`: it is EBS's transaction number and
resembles a billing document only by coincidence.

On the sync path the echo is a **cross-check, not the source**. The submit
call still holds the four keys in scope, so write from those and compare
the echo: equality is a free end-to-end confirmation that the answer
belongs to the document just submitted, and a mismatch means the platform
replied about something else and the row must not be written at all.

**`WarningDetails` has nowhere to go,** and in the success sample it
carries `DUP-202`: *"Invoice is already submitted, we are returning the
response from the Previously submitted Invoice"*. A replayed submission is
indistinguishable from a fresh one without it. It needs a column, a row in
`ZTEINV_ERR` marked as a warning, or at minimum a message in the action's
`reported`.

**`UniqueId`** has no column in either table - and neither did HANA's
`UNIQID` / `UNIQUE_IDENTIFIER` in `/CLR/ZT_EINV` (section 61). Consistent,
but it means the composite business key the platform echoes back is
discarded at both ends.

### Three mechanical traps

**`Success` is the string `"true"`, not a boolean.** Deserialized into an
`abap_bool` it is `'X'` either way, because both strings are non-empty.
Every failure would record as a success.

**`einvoice-type` is hyphenated.** `/ui2/cl_json`'s `pretty_name` cannot
produce an ABAP component name from it, so without an explicit
`name_mappings` entry the field is dropped and `EINV_TYPE` ends up empty
with nothing in the log.

**`ERROR` and `ERRORMESSAGE` are CHAR 250.** The section 61 sample's
joined message ran to roughly 700 characters: thirteen repetitions of *"Tax
exemption reason is required"* followed by the one real error. The
informative part is the part that gets cut. Deduplicate before joining,
and rely on the per-error rows rather than the header string.

### Not yet built

The parser still only handles shape A. The mapping document is the
specification for extending it; the work is not done, and section 62's
write-back does nothing against a live system until it is.

## 64. A third response shape, and the one with no SAP key

### What came in

The async status document the platform pushes after validation and
government reporting:

```json
{ "flow": "SALES/PURCHASE", "invoiceNumber": "mea-qa-36",
  "invoiceTypeCode": "389", "documentStatus": "VALIDATED",
  "governmentReportingStatus": "ACCEPTED", "updateTimestamp": "1788241519374",
  "uniqueId": "1005020990_mea-qa-36_389_2026",
  "documentId": "6a96666e0bcde70f13bc688f", ... }
```

Flat. No `postingType`, no `insertTable`, no `DocumentResponses`. That is
three distinct shapes from the same platform:

| | shape | self-describing | carries a SAP key |
|---|---|---|---|
| A | posting file | yes | yes |
| B | sync envelope | no | no, but the caller holds it |
| C | async status | no | **no, and the caller is gone** |

`doc/async_response_mapping.md` has the field table. What follows is the
part that is design rather than mapping.

### The join: `customFields` first, `documentId` second

Shapes A and B arrive while the submitting process still has
`VBELN`/`BELNR`/`BUKRS`/`GJAHR` in scope. Shape C does not — it arrives
out of band, long after the submission returned — so how it identifies its
document matters more here than anywhere else.

`customFields` carries the four keys, echoed back from the extract. When
populated they **are** the key: read them and write the row, no lookup.
The sample shows `"customFields": null`, so the fallback has to work too,
and the only other join is `documentId` → `ZTEINV_DOC-INVID`. `uniqueId`
is seller TRN, invoice number, type code and year — the platform's key,
not ours, and no column holds it.

**`INVID` is not a key of `ZTEINV_DOC` and has no index**, so the fallback
is a full scan per status document. Whether that matters depends on
something only the platform team can answer: is `customFields` guaranteed?
If it always arrives, the lookup is a rare path and the index can wait. If
it is usually null, the index is the difference between a status job that
keeps up and one that does not. The sample says null, and that is the only
evidence there is.

When both routes are available, compare them. A disagreement means one of
the two is about a different document and neither should be trusted. When
neither identifies a document, the status belongs to a submission this
system did not make — skip and log; there is no key to create a row
with.

### Write only the mapped columns

Seven fields map. The rest of `ZTEINV_SALES_ST` — the signed invoice, the
QR code, the UUID, the whole `PPF_LCSUB_*` / `LCREJ_*` / `LCREF_*` /
`LCPMNT_*` lifecycle block — is not in this document. A `MODIFY` from a
structure filled only from here blanks all of it, and nothing else will
put the signed invoice back.

### Two status fields, two pipeline legs

`documentStatus` is the platform's own verdict and belongs in
`PA_EXCHG_STAT`, which carries `SUBMITTED` in the section 60 payload.
`governmentReportingStatus` is the reporting leg and belongs in
`PPF_INVSUB_STAT`, which carries `PROCESSING` there. The two
`*ErrorReason` fields go to the matching `*_RESMSG` columns.

Store the platform's raw words, untranslated. Both columns are
`ZDE_EINV_STATUS`, `CHAR 40` with no fixed value list, so any vocabulary
fits and none of it is validated. Whatever transformation the UI wants
belongs on the read side, where the original is still there and a changed
vocabulary is a view change rather than a data fix.

### `updateTimestamp` has no column, and that is a hole

Status documents can arrive out of order, and the one generated last is
the truth rather than the one that arrived last. There is nowhere to store
`updateTimestamp`, so there is currently no way to tell: a stale
`PROCESSING` landing after `ACCEPTED` overwrites it and the invoice looks
stuck forever, with nothing in the data showing why.

Three options - a timestamp column compared before write; refusing a write
that moves a status backwards through a defined sequence, which means
writing that sequence down first; or accepting last-writer-wins as a known
hole. It needs a decision, not a default.

### `flow` is a discriminator, not a column

`SALES` selects `ZTEINV_SALES_ST`, `PURCHASE` the AP side. The sample
value is the literal `"SALES/PURCHASE"`, which documents the field rather
than instantiating it - worth confirming what the live payload sends, and
failing loudly on an unrecognised value rather than defaulting to sales.

### Where this leaves the integration

Three shapes, two of them unparsed:

```
  A  posting file    parsed by ZCL_EINV_ELT_POSTING (section 56)
                     and ZCL_EINV_ELT_INGEST~parse_writeback (section 62)
  B  sync envelope   mapped (section 63), NOT parsed
  C  async status    mapped (this section), NOT parsed, and needs an
                     inbound path of its own - nothing in the package
                     currently receives a pushed status document
```

B is the response to a call this package makes, so it belongs in
`parse_writeback`. C is pushed, so it needs something to receive it: an
inbound service, or a poll, or the batch job picking it up as a command.
Which of those is a question for the platform team - how does this
document reach the system at all? - and it should be answered before any
of it is built.

## 65. AP: the eight inbound tables, mapped to JSON

### What was asked

The JSON field mapping for the AP side in Public Cloud, given the HANA AP
ELT mapping (old tables → JSON) and the new AP structure mapping (new
tables → XML).

### The tables already exist, and they match exactly

`ZTEDOC_APH` / `API` / `APP` / `APA` / `APT` / `APN` / `APR` / `APX` are in
`ZZCLR_GEINV` today, and every one matches its `/CLR/EINV_ELTAP*`
counterpart field for field:

| Public Cloud | HANA | fields |
|---|---|---|
| `ZTEDOC_APH` | `/CLR/EINV_ELTAPH` | 82 |
| `ZTEDOC_API` | `/CLR/EINV_ELTAPI` | 41 |
| `ZTEDOC_APP` | `/CLR/EINV_ELTAPP` | 34 |
| `ZTEDOC_APA` | `/CLR/EINV_ELTAPA` | 17 |
| `ZTEDOC_APT` | `/CLR/EINV_ELTAPT` | 12 |
| `ZTEDOC_APN` | `/CLR/EINV_ELTAPN` | 7 |
| `ZTEDOC_APR` | `/CLR/EINV_ELTAPR` | 22 |
| `ZTEDOC_APX` | `/CLR/EINV_ELTAPX` | 12 |

227 fields, zero divergence - no renames, no omissions, nothing extra.
Worth stating plainly because it is the opposite of section 60, where
`ZTEINV_SALES_ST` quietly renamed seven columns of `/CLR/ZT_SALES_ST` and
broke the platform payload. The AP conversion did not do that.

### How the JSON was obtained

Neither supplied workbook answers the question on its own. The HANA
mapping gives **old table → JSON**; the new structure mapping gives **new
table → XML**. The bridge is the *Old to New* sheet, so:

```
  new field  --Old to New-->  old field  --HANA AP mapping-->  JSON path
```

That resolves **135 of 227**. The rest split two ways:

* **43 derived.** Fields with no old counterpart - the ones the new
  structures added (`CUSTOMIZATION_ID`, `UBL_VERSION`, `VAT_TOTAL_TAXCUR`,
  `TAX_EXC_DATE`, line `LINE_ACC_COST`, and the whole unlimited-row
  redesign of notes, references, allowances and tax subtotals). There is no
  HANA JSON to inherit, so the path is converted from the UBL element name
  by camelCase convention - `UBLVersionID` → `ublVersionID`.
* **49 not in the payload.** `MANDT`, `UUID`, `DOCUMENTID`, `STATUS`,
  `ACTION_TYPE`, `JSON_PAYLOAD`, the `CREATED_*` / `CHANGED_*` block - set
  by SAP or taken from the Clear response, not read from the invoice.

**The 43 derived rows are plausible, not verified**, and every one is
marked as such in the workbook with the UBL element it came from. They are
the rows to check against a live payload first; the 135 confirmed ones
carry the HANA mapping's own wording and comments, including the array
rules ("First item in array", "Concatenate all items separated by...").

### SBDH is deliberately not derived

Six header fields - `SBDH_SENDER_ID`, `SBDH_RECEIVER_ID`,
`SBDH_DOC_TYPE_ID`, `SBDH_PROCESS_ID`, `SBDH_COUNTRY`, `SBDH_CREATED_TS` -
come from the Standard Business Document Header, which is the transport
envelope around the invoice rather than part of it. Whether the Clear JSON
payload carries the envelope at all is a question for the platform, not
something to guess from an XPath, so they are listed as unmapped rather
than given an invented path. `UUID` is in the same position and is the
more urgent one: it is the key of all eight tables.

### What this does not cover

The mapping says where each field comes from. It does not say who reads
the payload and writes the rows - the AP inbound path itself. Sections 56
and 62 settled that question for the AR side (dispatch, posting, and the
write through the business object); the AP equivalent has not been looked
at in this conversion, and the five unpublished AP service bindings in the
standing checker findings are the visible edge of it.

### The file

`doc/AP_public_cloud_json_mapping.xlsx` - one sheet per table, with the
key flag, type and length, description, JSON path, source, the old HANA
field it came from, the transformation rule, and a sample value.

## 66. AP posting: the code is already there, the config is not

### The flow, as described

```
  /CLR/ZELT_EXEC_COMMAND  (batch)
    get_command -> 'DATA_POSTING'
      -> /CLR/ZELT_POSTING
         -> trigger_posting
            -> insert_table_einvoice
               -> MODIFY /CLR/EINV_APHEAD, /CLR/EINV_APITEM, ...
```

This is the same chain as the AR status write-back of sections 56 and 60.
The only thing that differs is which tables the posting file names.

### So the AP path needs no new ABAP

`ZCL_EINV_ELT_POSTING~insert_table_einvoice` is generic by design -
exactly as the HANA method is. It loops `insertTable`, and for each entry
does `CREATE DATA ... TYPE (<name>)`, fills components by name and issues
`MODIFY (<name>) FROM TABLE`. It does not know or care whether the entry
says `ZTEINV_SALES_ST` or `ZTEDOC_APH`. Section 56 called that out as the
reason not to hard-code the table, and this is the case it was kept
general for.

Two conditions, both already met:

* **Package.** `check_table_name_str( packages = 'ZZCLR_GEINV' )` restricts
  the dynamic write to this package. All eight `ZTEDOC_AP*` tables are in
  it, so they pass.
* **Multiple tables per command.** `insertTable` is an array and the loop
  handles every entry, so one `DATA_POSTING` command writes header, lines,
  parties and the rest in one pass.

One thing to confirm rather than assume: `trigger_posting_einvoice`
dispatches on `posting_type = 'IRN_WRITEBACK'`. If the AP posting file
uses a different `postingType`, that `CASE` needs the extra value - it is
one line, but it is a line nobody will think of until the first AP command
is silently skipped.

### The config does need rewriting, and substantially

The supplied *Writeback config (Updated)* names two tables and 306 field
slots. The Public Cloud structures are eight tables and 227 fields. The
difference is not cosmetic:

**70 of the 306 slots are numbered duplicates** - `INV_NOTE1..3`,
`CONTRACT_DOC_ID1..3`, `ADDITIONAL_DOC_*1..3`, `BILLING_REF_*1..3` and the
rest of the fixed 1..4 slots. Those collapse into variable rows of
`ZTEDOC_APN`, `ZTEDOC_APR`, `ZTEDOC_APA`, `ZTEDOC_APT` and `ZTEDOC_APX`.
The platform now emits **n rows** where it used to fill **four slots and
drop the fifth**, which is the whole point of the redesign.

**Many fields were renamed**: `ISSUE_DT` → `ISSUE_DATE`, `INV_TYP_CODE` →
`INV_TYPE_CODE`, `START_DT` → `PERIOD_START`, and so on. `ASSIGN COMPONENT`
skips a name that does not match **in silence** - section 60 is the record
of what that costs - so every renamed field is a column that quietly stops
being written.

`doc/ap_writeback_config_public_cloud.json` is the rebuilt config: eight
`insertTable` entries, 194 fields, new names, in DDIC order. Child tables
show one row each; the platform emits as many as the document has.

### UUID is mandatory now and the current config does not send it

The new tables are keyed on `MANDT + UUID` (plus `LINE_ID`, `SEQ`,
`PARTY_ROLE`, `REF_TYPE`, `ATTR_TYPE` on the children). The old tables were
keyed on `DOCUMENTNUMBER`, and the structure mapping records that the old
`UUID` and `DOCUMENTID` key fields were "always blank".

**The supplied config contains no `UUID` entry at all.** Every row it
writes into the new tables would land on a blank key - which means one row
per table, overwritten by the next document, forever. The field's own rule
in the structure mapping says what to send: *"Mandatory. Same value as
response idempotencyKey. Must never be blank."* The posting file already
carries `idempotencyKey` at its top level, so the value is in hand; it
just has to appear in each table's field list. It is in the rebuilt config.

### What the config deliberately leaves out

25 fields, because the platform does not supply them:

* `DOCUMENTID`, `STATUS`, `ACTION_TYPE`, `REASON_CODE`, `MATCH_STATUS`,
  `COMMENT_TXT`, `API_MESSAGE`, `JSON_PAYLOAD` - SAP or Clear response.
* `CREATED_*` / `CHANGED_*` - set on write.
* `UNIT_SAP`, `PACK_UNIT_SAP`, `PRICE_UNIT_SAP` - derived from the ISO unit.
* `SUBJECT_CODE` on notes - derived from the `#CODE#` prefix of the note text.
* The six `SBDH_*` fields and `LINE_COUNT`. These are **open questions**,
  not decisions: SBDH is the transport envelope rather than part of the
  invoice, and `LINE_COUNT` is `count(InvoiceLine)` which the platform could
  easily compute. If the platform can send any of them, they belong in the
  config and the fields are already there to receive them.

### One field with nowhere obvious to go

`TAX_REP_COUNRY_SUBDIVC` appears in the old config and in no old table -
issue 17 of the structure mapping, "sent but not in table". Its home in
the new design is `ZTEDOC_APP-SUBDIV_CODE` on the row with
`PARTY_ROLE = 'TAX_REP'`, which exists for every role now. Worth routing
explicitly rather than leaving it to be dropped a second time.

## 67. DOCUMENTNUMBER as the second key field

### What was asked

`DOCUMENTNUMBER` to be a key field alongside `UUID` across the AP tables.

### It reached further than the tables

The DDIC change is eight `KEYFLAG` flips. What made this more than that is
that the AP stack above the tables was already built - nine internal
views, nine projections, a flat reporting view and a behaviour definition -
and a key field has to be a key field in all of them or the stack stops
agreeing with itself.

```
  8 tables          KEYFLAG X + NOTNULL X on DOCUMENTNUMBER
  8 internal views  `key documentnumber as DocumentNumber`
  1 ZCDS_INT_EDOC_APENR   second key added - it is a [1..1] association target
  9 projections     `key DocumentNumber`
  1 flat view       key, plus all three joins
  1 BDEF            readonly -> readonly : update, on all eight behaviours
```

**One piece of luck worth recording:** in every one of the eight tables,
`DOCUMENTNUMBER` already sat immediately after the last key field. DDIC
requires key fields to be contiguous and first, so had it been anywhere
else this would have meant reordering columns in a table that already has
data. It did not.

### The associations had to be widened

A to-parent association must determine exactly one parent row. Every child
view joined on `Uuid` alone, which stopped being the whole key:

```abap
  association to parent ZCDS_INT_EDOC_APH as _Document
    on  $projection.Uuid           = _Document.Uuid
    and $projection.DocumentNumber = _Document.DocumentNumber
```

Same for the header's own `_SellerParty`, `_BuyerParty` and `_Enrich`
associations, and for all three joins in `ZCDS_INT_EDOC_APFLAT`. Left as
they were, the ON conditions would still have activated in some releases
and silently returned a cross product in others.

### `field ( readonly )` had to become `readonly : update`

`DocumentNumber` was in the header behaviour's unconditional readonly list.
That form blocks CREATE as well, so every row the posting write-back
inserted would have carried a blank half-key - section 46 is where that
distinction was learned the expensive way, and section 48 is where the
checker rule for it came from.

### What this costs

`UUID` alone already identified a document. Adding `DOCUMENTNUMBER` to the
key does not make the identity tighter - it loosens it. Two rows with the
same `UUID` and different `DOCUMENTNUMBER`s used to be impossible; the
second write overwrote the first. Now they coexist, and a document whose
number changes between submissions leaves an orphan behind instead of
updating in place.

That is a real trade and it is being made deliberately: a key on
`DOCUMENTNUMBER` means it is indexed and never blank, which is what makes
"find the document by its invoice number" a cheap query rather than a scan.
Given that section 64 has exactly that problem on the AR side - `INVID` is
the only join from an async status document and it has no index - the
reasoning is consistent. Worth knowing which way the trade went, though.

### A checker rule that reported its own documentation

Adding the `readonly : update` comment made rule 16 fire:

```
  zcds_int_edoc_aph.bdef.asbdef: ZCDS_INT_EDOC_APH marks key field Uuid as
  `field ( readonly )` - that also blocks it on CREATE
```

False. The comment explaining the change *contains the string*
`` `field ( readonly )` `` and the word `Uuid`, and rule 16 read the file
without stripping comments. Rule 39/40 right beside it already stripped
them; this one never had.

Fixed in the rule rather than by rewording the comment. A checker that
reads a comment as code will keep doing it, and a conversion documented as
heavily as this one makes that a question of when rather than whether.

## 68. The five bindings: repository side cleared

Section 43 diagnosed this and fixed it for `ZSB_EINV_DOC`. The same thing
was never done for the other five, which is what the standing fifteen
checker problems have been since.

### What the repository now carries

```
  deleted  2a5356fc…ht.sush.xml   R3TR IWSV ZSB_EDOC_AP      0001
  deleted  eef023fc…ht.sush.xml   R3TR IWSG ZSB_EDOC_AP_0001
  deleted  556905d5…ht.sush.xml   R3TR IWSV ZSB_EDOC_APFLAT  0001
  deleted  ab3cdc67…ht.sush.xml   R3TR IWSG ZSB_EDOC_APFLAT_0001
  deleted  7d6be3f3…ht.sush.xml   R3TR IWSV ZSB_EDOC_SB      0001
  deleted  ffc9db68…ht.sush.xml   R3TR IWSG ZSB_EDOC_SB_0001
  deleted  ce13204b…ht.sush.xml   R3TR IWSV ZSB_EDOC_SBFLAT  0001
  deleted  b812bb32…ht.sush.xml   R3TR IWSG ZSB_EDOC_SBFLAT_0001
  deleted  d5f58d07…ht.sush.xml   R3TR IWSV ZSB_EINV_CONFIG  0001
  deleted  7c8ec751…ht.sush.xml   R3TR IWSG ZSB_EINV_CONFIG_0001

  PUBLISHED true -> false   zsb_edoc_ap, zsb_edoc_apflat, zsb_edoc_sb,
                            zsb_edoc_sbflat, zsb_einv_config
```

The twelve remaining `.sush.xml` files stay: four belong to the two
inherited bindings whose inbound services exist, six describe job catalog
entries that are all in the repository, and two belong to `ZSB_EINV_DOC`,
which was published in section 51.

Checker: **no inconsistencies found.** The only output left is the fifteen
advisory findings in `ZZCLR_ELT`, which are inherited and activate in the
tenant today.

### This does NOT fix the tenant

Section 44, stated again because it is the step that gets skipped: **a
pull does not delete.** The ten shells are still sitting in F3Y, and a
pull of this repository will leave them exactly where they are. Removing
them from the repository only stops them being re-imported into a fresh
system.

The tenant work, per binding, in client 080:

1. Open the binding in ADT. Its header carries a link,
   **Default Authorization Values: `<hash>`**. Follow it, and delete that
   object. Do the same for the second shell - each binding has two, one
   `IWSV` and one `IWSG`, and the table above names both.
2. Back on the binding, press **Publish Locally**. With nothing claiming
   the inbound service already exists, this creates all five objects and
   the endpoint activates.
3. Repeat for the remaining four.
4. **Push**, and confirm each binding now ships `<name>_iwsg.sco2.xml`.
   Rule 57 will say so on the next check if one is still missing, rather
   than leaving it to the next failed publish.

After step 4 the five bindings carry `PUBLISHED true` again legitimately,
because the object backing the claim will exist.

### Why not just leave the flag true

Because the flag is a claim about the tenant, and on import into a system
where the inbound service does not exist it is a false one. Section 42
cleared it for `ZSB_EINV_DOC` and section 43 found that clearing it was
necessary but not sufficient - the shell was the blocker. Both halves are
now done for all six.

## 69. AP: the same eight tables, mapped to XML

The counterpart to section 65. Same tables, same 227 fields, the UBL 2.1
XPath instead of the JSON path - `doc/AP_public_cloud_xml_mapping.xlsx`.

Unlike the JSON mapping, nothing here had to be derived: the supplied AP
structure mapping already carries an XPath per field, so every row is as
the structure designer wrote it. The work was classification, and that
turned out to be where the useful information is.

| source | fields |
|---|---|
| XML element | 178 |
| SBDH envelope | 14 |
| Row selector | 8 |
| Computed | 1 |
| Not in XML | 26 |

### Three classifications worth arguing about

**`UUID` is SBDH, not invoice.** Its XPath is
`/StandardBusinessDocument/StandardBusinessDocumentHeader/DocumentIdentification/InstanceIdentifier`
- the envelope that wraps the invoice, not the invoice. It is grouped with
the six `SBDH_*` fields for that reason, and it matters because it is the
first key field of all eight tables: if the envelope is not available to
whatever parses the payload, nothing can be keyed. Section 66 raised the
same point from the JSON side, where the answer is `idempotencyKey`.
Fourteen rather than seven because every child table carries `UUID` too.

**Row selectors are not "not in XML".** `PARTY_ROLE`, `REF_TYPE` and
`ATTR_TYPE` have no XPath of their own, but they are entirely determined
by the XML - they say *which parent element the row came from*. So is
`SEQ`, which is the position within that parent. Filing them under "not in
XML" would say the platform invents them, which is the opposite of true.
They have their own category, and the Roles & Types sheet lists every
value against the element it selects.

**26 fields genuinely are not in the XML**, and they are the same ones the
JSON mapping excluded: `DOCUMENTID`, `STATUS`, `ACTION_TYPE`,
`JSON_PAYLOAD`, the `CREATED_*` / `CHANGED_*` block, and the three
`*_SAP` unit fields that are converted from the ISO unit rather than read.

### The `<party>` and `<ref>` prefix

In `ZTEDOC_APP` an XPath like `<party>/cbc:IndustryClassificationCode` is
relative: `<party>` stands for whichever element the row's `PARTY_ROLE`
selects - `AccountingSupplierParty/Party` for `SELLER`,
`TaxRepresentativeParty` for `TAX_REP`, and so on. `ZTEDOC_APR` does the
same with `<ref>` and `REF_TYPE`, `ZTEDOC_APX` with `ATTR_TYPE`. Without
the Roles & Types sheet those three sheets cannot be read, which is why it
is in the workbook rather than left behind in the source file.

### DOCUMENTNUMBER on all eight sheets

Section 67 made it the second key field everywhere, so `/Invoice/cbc:ID`
now appears on every child sheet rather than only on the header. That is
the intended consequence - a child row carries the invoice number it
belongs to - but it is worth seeing stated, because a reader coming from
the HANA structures will expect it on the header alone.

### Cross-reference

The last column of every sheet is the JSON path for the same field, so
this workbook and `AP_public_cloud_json_mapping.xlsx` line up row for row.
Where it is blank, section 65's classification applies: either the field
has no JSON source, or it was one of the 43 derived paths and lives only
in the JSON workbook with its "Derived" marker.

## 70. The DATA_ZIP download, rebuilt as a stream

### What HANA does

At the end of `/CLR/ZCL_ELT~create_files_einvoice`:

```abap
READ TABLE gt_erp_config WITH KEY label_type = 'DATA_ZIP'.
IF sy-subrc IS INITIAL AND lwa_confg-low IS NOT INITIAL.
  CALL FUNCTION 'SCMS_XSTRING_TO_BINARY' ...
  cl_gui_frontend_services=>gui_download( filename = lwa_confg-low ... ).
ENDIF.
```

A diagnostic: when the `DATA_ZIP` config row holds a path, the extract
archive that is about to be uploaded is also written to the developer's
workstation, so somebody can open it and see what the platform was
actually sent. The converted `create_files` stops one statement earlier -
it builds the zip and the file name and never offers them.

### Why it cannot be a file on a workstation

`cl_gui_frontend_services` is SAP GUI and there is no GUI. But the
stronger reason is that **it never worked on the path that needs it**:
`gui_download` raises `NO_BATCH` in a background task, and the extract
normally runs in a scheduled job. On HANA this feature only ever fired for
a developer running the report in dialog.

### What was built

The same answer this package already gave for the PDF printout. That is
deliberate: `ZCL_EINV_PDF_STORE` replaced the `file_save_dialog` /
`SCMS_DOWNLOAD` tail of `call_print_pdf` with a table plus a stream, and
the two classes are now near-identical - a reader who understands one
understands the other, and a defect found in either should be looked for in
the other.

```
  ZTEINV_ZIP                 store: document key + COMMAND_ID, FILENAME,
                             MIMETYPE, CONTENT, CRDAT, CRTIME
  ZCL_EINV_ZIP_STORE         is_enabled / stage / save / discard
  ZCDS_INT_EINV_ZIP          composition child, CONTENT carries
                             @Semantics.largeObject
  ZCDS_CUN_EINV_ZIP          projection
  ZCDS_MET_EINV_ZIP          UI
  ZCDS_MET_EINV_DOC          ArchiveFacet, position 40
  ZSD_EINV_DOC               expose ... as EInvoiceArchive
```

The config gate is kept, label and all. On HANA the value is a file path;
here there is no path to honour, so any non-initial value means "keep the
archive" and `'X'` reads best. The label stays `DATA_ZIP` because the two
systems share a config table layout and an operator who knows to set it on
HANA should not have to learn a second name.

Staged during the action, written by `save_modified`, discarded by
`cleanup_finalize` - the section 50 contract, already in place for the
printout and the telemetry.

### Read-only, on purpose

The behaviour declares no create, update or delete. The archive is
evidence of what was uploaded, so the service may hand the bytes out and
nothing more. It also keeps this a plain **read** stream, which needs
nothing in the behaviour definition beyond the mapping - the
`@Semantics.largeObject` annotation on the view drives it. A writable
stream would need more, for no benefit.

`sizeCategory: #L` and no `@UI.lineItem` on the bytes themselves: the
stream is fetched by its own request when the link is pressed, not carried
in every list response.

### A gap found on the way

**`ZTEINV_PDF` is written and never read.** `ZCL_EINV_PDF_STORE`'s own
documentation says the printout is "stored in ZTEINV_PDF instead, which
the Fiori app offers as a stream download" - but there is no CDS view over
that table, no composition, no exposure. The bytes go in and nothing can
get them out. The printout needs the same five objects this section just
built for the archive; the pattern is now proven and the work is
mechanical, but it is not done.

### Two checker rules, both mine, both narrowed

Adding a read-only child made rules 39/40 and 16 contradict each other.

Rule 39/40 asks for a `readonly` declaration on **every** key of every
behaviour, including one that declares no operations - section 48, where
relaxing exactly that reasoning cost an activation round. Correct, and it
fired.

Rule 16 then objected that unconditional `field ( readonly )` on a key
"also blocks it on CREATE, so an EML create with external keys would
insert empty keys". That premise **requires a create to exist**, and this
behaviour has none - the table is written from the save phase, not through
the BO. The rule was too broad, so it now skips a behaviour that declares
neither `create;` nor an association with `{ create; }`. Self-tested by
reverting section 67's `readonly : update` on the AP header, which does
have creates: two hits, as expected, and silent again once restored.

The lesson of section 48a still stands - a rule firing on new code is
evidence about the code, not the rule - but it is not absolute. When two
rules contradict each other on the same line, one of them is wrong, and
the way to tell which is to check whether its stated premise holds.

## 71. DATA_ZIP carries a file name, and SEQUENCE was dropped

The QS4 config, as maintained:

```
  QS4  AUTH              0   sandbox.1.17e8dd97-...
  QS4  AUTH              1   sandbox.1.17e8dd97-...
  QS4  DATA_ZIP          1   C:\Users\...\Desktop\france\F2_1210021695_upd.zip
  QS4  ERP_INSTANCE_ID   0   5bf2e018-5922-467e-bdf3-8a4f1f06a807
  QS4  ERP_INSTANCE_ID   1   5bf2e018-5922-467e-bdf3-8a4f1f06a807
  QS4  GET_COMMAND       0   /one-integration/command/get
```

Two things in that picture, and the second is much bigger than the first.

### The file name is worth keeping

Section 70 treated `DATA_ZIP` as a switch - "any non-initial value means
keep the archive". Half right. The directory means nothing here, but the
operator who typed `F2_1210021695_upd.zip` wanted the download called
that, and discarding it loses something the configuration already says.

`ZCL_EINV_ZIP_STORE~file_name` now takes the last path segment when it
looks like a file name, and falls back to the generated timestamp name
otherwise. Both separators are accepted - the HANA value is a Windows
path, but nothing stops an operator typing a POSIX one. Checked against
the real value and the cases around it:

```
  C:\Users\Mohan.Ganjalagunte\...\F2_1210021695_upd.zip  ->  F2_1210021695_upd.zip
  /home/user/out/extract.zip                             ->  extract.zip
  myfile.zip                                             ->  myfile.zip
  X                                                      ->  <generated>
  C:\temp\                                               ->  <generated>
```

A segment with no dot is not a file name - it is `X`, or a trailing
directory - so it falls back rather than storing an extensionless archive
the browser will not know what to do with. Note the first case: the path
contains a dot in `Mohan.Ganjalagunte`, which is why the test is on the
last segment rather than on the whole string.

### SEQUENCE is a profile selector, and the conversion dropped it

`ZTELT_CONFIG` is keyed on **PROJECTID + SYSID + LABELTYPE + SEQUENCE**.
The sequence is not a line counter - it selects a whole configuration
profile. `/CLR/ZELT_EXEC_COMMAND` takes `p_seq` as a report parameter and
hands it to the engine, which filters on it:

```abap
" HANA
METHOD get_erp_config.
  SELECT label_type, low FROM /clr/zt_elt_cnfg
    WHERE sys_id = @sy-sysid AND sequence = @iv_seq
    INTO CORRESPONDING FIELDS OF TABLE @gt_erp_config.
```

The converted method:

```abap
" Public Cloud
METHOD get_erp_config.
  SELECT labeltype, low FROM ztelt_config
    WHERE sysid = @sy-sysid
    INTO CORRESPONDING FIELDS OF TABLE @gt_erp_config.
```

**No sequence filter, no sequence column in the buffer, and no `iv_seq` on
the constructor** - the parameter was removed from the signature
entirely. So `GT_ERP_CONFIG` holds every profile's rows mixed together,
and every lookup in the package - `READ TABLE ... WITH KEY labeltype`, and
the table expressions in `ZCL_EINV_ELT_COMMAND`, `ZCL_EINV_ELT_INGEST` and
`ZCL_EINV_ZIP_STORE` - takes **whichever row the database returned
first**.

On QS4 this has not bitten yet, by luck: `AUTH` and `ERP_INSTANCE_ID` hold
the same value at both sequences. But the set is already inconsistent -
`GET_COMMAND` exists only at sequence 0, `DATA_ZIP` only at sequence 1 -
so the code is reading a profile that exists in no row of the table. The
day two sequences hold different endpoints or different tokens, a
submission goes to whichever one sorted first.

### What was and was not done about it

Nothing. This is `ZCL_ELT` in `ZZCLR_ELT`, which is not this project's
package and is shared by every ELT flow in the tenant - sections 53, 56
and 57 all took the same position, and the reason holds here too.

It also cannot be worked around from this package. Section 53 chose to
read the shared `GT_ERP_CONFIG` rather than select again, precisely so the
two could never disagree about which rows are current; selecting
independently to get the sequence right would reintroduce exactly that
risk, and would be a second source of truth for the sake of a bug that
belongs upstream.

So it is reported, with the fix it needs:

1. `iv_seq TYPE ztelt_config-sequence OPTIONAL` back on the constructor.
2. `AND sequence = @iv_seq` back in `get_erp_config`.
3. A sequence parameter on the job classes that build a `ZCL_ELT`, so an
   operator can run profile 0 or profile 1 - `ZCL_ELT_EXEC_COMMAND_JOB`
   and `ZCL_EINV_ELT_EXEC_JOB` both pass nothing today.

Until then: **keep every label at one sequence only, or keep the values
identical across sequences.** That is what makes QS4 work now, and it is
worth saying out loud rather than leaving as an accident.

## 72. Four activation errors, and a rule that could not report

### The two behaviour-definition errors are activation order

```
The base entity "ZCDS_INT_EINV_ZIP" of "ZCDS_CUN_EINV_ZIP" does not define a behavior.
The behavior definition of the base entity "ZCDS_INT_EINV_DOC" of "ZCDS_CUN_EINV_DOC"
  must contain the association "_ARCHIVE" as a non-"internal" association.
```

Both say the same thing: `ZCDS_CUN_EINV_DOC`'s behaviour definition was
activated while `ZCDS_INT_EINV_DOC`'s was not yet active in the tenant.
The repository has both - `association _Archive;` on the root and
`define behavior for ZCDS_INT_EINV_ZIP` below it - and the checker agrees.
Nothing to fix in the code; the base behaviour definition has to activate
first, and the projection after it.

### Three real defects

**ABAP Doc does not allow bare angle brackets.** A comment reading
`` `MODIFY (<name>) FROM TABLE` `` is parsed as an unclosed HTML tag:

```
HTML tag <name> is not closed (HTML tags must be noted in a line).
HTML tag <name> is not supported in ABAP Doc.
```

`"!` is ABAP Doc, not a plain comment, and `<...>` means markup there.
Reworded. Worth remembering because this conversion quotes HANA source in
ABAP Doc constantly, and field symbols and dynamic tokens are full of
angle brackets - the rest of them happen to sit in plain `"` comments,
where they are fine.

**`ABP_BEHV_CID` is itself `STRING`**, so
`CONV abp_behv_cid( |PICK{ lv_seq }| )` is a string-to-string conversion
and the tenant rejects it as redundant. Declared and assigned instead.
Same family as section 58: a `CONV` copied along with the expression it
wrapped.

**`CONV #( lv_time_diff )`** in `ZCL_INSTRU_EVENT_CLASS` - `lv_time_diff`
is declared `TYPE string` eight lines above and the target is `TYPE
string`. Inherited code, in this package, so it has to activate here.

### The secondary-key message, and why the fix is not `KEY id`

```
The secondary key "ID" is completely covered. However, "ID" is not used in the statement.
```

`ASSIGN lt_update[ %tky = ls_doc-%tky ]` on a `TABLE FOR UPDATE`: the
derived type carries a secondary key, the expression supplies all of its
components, and the tenant wants it named.

Naming it - `lt_update[ KEY id COMPONENTS %tky = ... ]` - would silence
the message. The better fix was to stop looking the row up at all: the
write-back fills the row that was appended four lines above it, so

```abap
APPEND INITIAL LINE TO lt_update ASSIGNING FIELD-SYMBOL(<ls_upd>).
<ls_upd>-%tky = ls_doc-%tky.
...
```

holds the field symbol instead. No table expression, no key to name, and
it cannot find the wrong row - which the lookup could, if two documents in
one request ever shared a `%tky`.

### Rule 17 could not report what it found

The first error - a projection whose base entity has no behaviour at all -
was in rule 17's reach and the rule skipped it: `if bsec is None: continue`.
It checked that every `use` had a counterpart in the base, never that the
base existed.

Closing that was two lines. Then the self-test failed in a way worth
recording: the new branch called `_flag`, which is defined **below** rule
17 in the file, so the branch raised `NameError` the first time it was
reached - and because it had never been reached before, nothing noticed.
The surrounding rules use `problems.append` for exactly that reason.

A checker rule that has never fired has never run its own code. That is
the second time this conversion has been reminded that a rule needs a
deliberate self-test - section 43 self-tested rule 57 by deleting a file,
section 63 by reintroducing a declaration - and the first time the test
caught a fault in the rule rather than in the package.

Self-tested properly: removing `define behavior for ZCDS_INT_EINV_ZIP`
from the base produces

```
zcds_cun_einv_doc.bdef.asbdef: ZCDS_CUN_EINV_ZIP: its base entity
ZCDS_INT_EINV_ZIP has no `define behavior for` anywhere in the repository
```

and restoring it returns to clean.

## 73. The fifteen problems came back

Section 68 ended with *no inconsistencies found*. Pulling the tenant copy
back into the repository returned the count to fifteen:

```
  5 x  <binding>.srvb.xml   PUBLISHED=true but <binding>_iwsg.sco2.xml
                            is not in the repository          (rule 51)
 10 x  <hash>ht.sush.xml    authorization defaults for an IWSV/IWSG
                            object that is not here           (rule 57)
```

Two shells and one binding line each, for `ZSB_EDOC_AP`,
`ZSB_EDOC_APFLAT`, `ZSB_EDOC_SB`, `ZSB_EDOC_SBFLAT` and
`ZSB_EINV_CONFIG`.

Nothing regressed. Section 44 is the whole explanation, in its other
direction: **a pull does not delete, and neither does a push from a tenant
that still holds the object.** Deleting `<hash>ht.sush.xml` from `src/`
never touched F3Y, so the next serialisation of the package brought all
ten back. The repository half of section 68 was done; the tenant half was
not, and the repository half does not survive without it.

The instruction that followed was therefore: delete the ten shells by hand
in ADT, then Publish Locally on the five bindings. That instruction was
wrong, which is section 74.


## 74. The shells are not the blocker - correcting section 43

Deleting the first shell in ADT failed:

```
Deletion failed.  No change authorization for ABAP language version
```

The useful move at that point was not to look for a way around the
authorization error. It was to check the premise, because the premise had
a test sitting right next to it.

### The evidence that was already in the repository

Section 43 says, in the past tense, that twelve orphaned shells *were
deleted* - two of them `ZSB_EINV_DOC`'s. Both of `ZSB_EINV_DOC`'s shells
are in `src/` today. They have been there the whole time. And
`ZSB_EINV_DOC` is published and serving the cockpit.

So the shells were never deleted, and the binding published anyway.

The user then confirmed the same thing on a second binding from the
tenant: `ZSB_EDOC_AP` shows **Published**, with its authorization-defaults
shell in place, and one error on the auth-defaults object itself -
*Default values might not be sufficient*. That is a statement about the
authorization content of `S_SERVICE`, not a publish failure. The publish
succeeded with the shell present, twice.

### What section 43 got wrong

Section 43's mechanism - *"with the shell present and naming
`ZSB_EINV_DOC_IWSG`, the publish believes the object is already there"* -
is not what happens. The shell is a bystander. What actually blocked that
first publish was the `PUBLISHED` flag of section 42; once that was
cleared the publish went through, and the shell deletion recorded
alongside it never happened and was never needed.

### How a wrong sentence survived three repetitions

The sentence was mine, it was in the past tense, and it was treated as
evidence by everything downstream:

- section 43 asserted the deletion,
- section 68 repeated it and extended it to ten more files,
- section 73 issued it as an instruction to carry out in ADT.

All three while the files sat in `src/`, in the directory the checker
counts on every single run - and while rule 57 fired on exactly those
files every single run. The checker was not failing to report the
contradiction. It was reporting it, and its report was read as a to-do
list rather than as a disproof of the design document.

**A past-tense sentence in a design document is a claim about the
repository, not a fact about it.** When the two disagree the repository
wins, and the cheapest check in this entire conversion - `ls src/*.sush.xml`
- would have settled it at any point over three sections.

### What changed in the checker

**Rule 51** keeps firing but says something true now: the binding is
published in the tenant and abapGit did not serialise its inbound service,
so a *fresh import* gets a half-carried publish and has to Publish Locally
again. That is repository fidelity, not a blocker for F3Y.

**Rule 57** no longer repeats the same finding twice more per binding. A
shell whose binding is already reported is skipped; a shell with no
binding at all anywhere in the repository is still a genuine orphan and is
still flagged.

Fifteen problems became five - one per binding - and the five are
accurate.


## 75. The tenant push adopted as the base

The tenant export `Global_eInvoice_public_cloud-main 3.zip` replaces the
working copy as the baseline.

### The comparison that made adoption safe

```
  theirs   1176 files in src/
  mine     1166 files in src/
  only in theirs   the 10 .sush.xml shells  (section 73: they never left F3Y)
  only in mine     nothing
```

Every object written during this conversion came across. The only
divergence is the ten shells returning, which is expected and now
correctly reported as five findings rather than fifteen.

All five bindings carry `<PUBLISHED>true</PUBLISHED>` - the tenant work of
section 68 is done, and done *with the shells still in place*, which is
the third independent confirmation of section 74.

Three of the eight bindings have an `_iwsg.sco2.xml`: `ZSB_EINV_DOC`,
`ZSB_ELT_CONFIG`, `ZSB_EVENT_LOG`. The other five still do not serialise
their inbound service. Unchanged, understood, and no longer described as a
blocker.

### `acceptableMimeTypes` stays

The adopted `ZCDS_INT_EINV_ZIP` keeps

```abap
@Semantics.largeObject: { ..., acceptableMimeTypes: [ 'application/zip' ] }
```

which an earlier change removed on the grounds that it is upload-only and
the archive is download-only. The tenant activates it with zero problems -
the user's own screenshot - so the annotation is harmless and the removal
was an unnecessary deviation from what is running. Adoption restores it.

### Backtick corruption in nine behaviour definitions

Nine `.asbdef` files arrived carrying between 16 and 112 backticks each,
all inside `/* */` comments, none of them written by hand.

BDL has no backtick syntax at all - not a string literal, not a quoting
character. Every one of them is Markdown fencing: a comment was quoted
into a chat message or a document as `` `code` ``, the fencing came back
into the file on the next edit, and the round trip after that fenced the
fencing. The counts grew every cycle, which is why nine files reached
three figures without anyone touching those comments.

The tenant tolerates it - a backtick inside a `//` or `/* */` comment
activates - which is exactly why nothing caught it. All of them stripped,
and the spacing the strip left behind repaired (`there.readonly` back to
`there. readonly`).

**Rule 64** now flags any backtick in a `.asbdef`. Self-tested by
inserting one and confirming the report, then removing it and confirming
clean.

### Rule 57's unreachable branch had the section 72 fault

While narrowing rule 57 its remaining branch was deliberately exercised -
by moving `zsb_edoc_ap.srvb.xml` aside - and it printed

```
authorization defaults for {disp} but {needed} is not in the repository
```

Doubled braces in an f-string: `{{disp}}` renders as literal `{disp}`. The
branch had never fired, so it had never run its own code. That is section
72's lesson a third time, and it is now the standing practice here: a rule
that is changed gets fired on purpose before it is trusted, including the
branches that are supposed to stay quiet.

## 76. The Einvoice checkbox was never wired up

`/CLR/ZELT_EXEC_COMMAND` had three selection fields:

```
  [x] Run in background
      Sequence   [____]
      Einvoice   [_]
```

`ZAJT_ELT_EXECUTE_COMMAND_1` -> `ZAJC_ELT_EXECUTE_COMMAND` ->
`ZCL_ELT_EXEC_COMMAND_JOB` offered none of them:

```abap
  METHOD if_apj_dt_exec_object~get_parameters.
  ENDMETHOD.
```

An empty `get_parameters` means an Application Job with no parameters at
all, which is why both ELT job templates shipped without a `parameters`
block. The checkbox did not exist, so it could not be ticked, so the job
always ran the extraction path.

> **Section 77 corrects the two readings of `p_einv` and `Sequence` below.**
> `p_einv` is not a path selector in the driver, and the `SEQUENCE` column
> was never dropped. The structural finding - an empty `get_parameters`,
> so neither field existed - stands.

### Why that is worse than a missing field

`execute` went straight to `ZCL_ELT~elt_exec_command`, and that method
dispatches on nothing:

```abap
  IF ls_elt_command-result-command_id IS NOT INITIAL.
    lo_elt->elt_ingestion( ... ).
```

Any command with an id goes to ingestion, `DATA_POSTING` included. The
platform marks it delivered and the write-back never happens - section 56,
observed from the other end. So the scheduled job was not merely missing
the e-invoice option; it was positioned to swallow e-invoice commands.

Section 56 answered this by building `ZCL_EINV_ELT_EXEC_JOB` and leaving a
note to create a catalog entry and template for it. That note was never
carried out, and on reflection it should not be: HANA ran both paths from
one report and chose with a checkbox, and splitting them into two
independently schedulable jobs invents a way for both to poll one command
queue at once.

### What it does now

| Object | Change |
|---|---|
| `ZCL_ELT_EXEC_COMMAND_JOB` | `P_EINV`, `P_MAXSEC`, `P_RETRY` declared in `get_parameters`; `execute` delegates to `ZCL_EINV_ELT_EXEC_JOB->run_einvoice_posting( )` when `P_EINV = 'X'` |
| `ZCL_EINV_ELT_EXEC_JOB` | job body moved out of `execute` into public `run_einvoice_posting( iv_maxsec, iv_retry )`; still implements the APJ interfaces |
| `ZAJT_ELT_EXECUTE_COMMAND_1` | `P_EINV = 'X'` - this is the e-invoice posting template |
| `ZAJT_ELT_EXECUTE_COMMAND` | `P_EINV = ''` - extraction, as before |

One catalog entry, two templates, the same shape as the one report with
its checkbox. Scheduling `..._1` runs the posting loop; scheduling the
other runs extraction. They must not be scheduled to overlap, for the
reason above.

### Sequence is deliberately not declared

The HANA field selected the `ZTELT_CONFIG` profile by the `SEQUENCE`
component of its key. Section 71: that component was dropped in the
conversion, and the cloud key is `PROJECTID + SYSID + LABELTYPE`. A
`P_SEQ` parameter would have nothing to select and would read as a
working filter that silently does nothing - the failure mode this
conversion has hit four times already (sections 52, 56, 57, 59). If
per-sequence profiles are wanted, the key has to come back first and the
parameter after it.

### Not done by this change

`ZCL_ELT~elt_exec_command` still calls `elt_ingestion` for every command
regardless of verb. The checkbox routes around it rather than fixing it,
because the fix belongs to whoever owns that method. It stays on the list
for the `ZZCLR_ELT` owners alongside the four posting defects of section
56.

## 77. Reading the report instead of reasoning about it

Section 76 declared the Einvoice checkbox wired up and argued that
Sequence had nothing to select. Both conclusions came from the converted
code and from memory of the HANA chain. Reading
`/CLR/ZELT_EXEC_COMMAND` itself contradicts both.

### What `p_einv` actually does

The driver loop is identical whether the box is ticked or not:

```abap
  DATA(lv_program) = lo_elt->get_exec_program( is_elt_command = ls_elt_command ).
  ...
  IF p_einv IS INITIAL.
    SUBMIT (lv_program) WITH p_comm = ... WITH p_seq = p_seq AND RETURN.
  ELSE.
    SUBMIT (lv_program) WITH p_comm = ... WITH p_einv = 'X'
                        WITH p_seq = p_seq AND RETURN.
  ENDIF.
```

Same `get_exec_program`, same dispatch, same child. The only difference is
one extra `WITH`. It travels to `/CLR/ZELT_POSTING`, into
`trigger_posting( is_file_details, iv_einvoice )`, and guards exactly one
statement:

```abap
  IF iv_einvoice IS INITIAL.
    insert_table( is_schema = ls_posting_file ).
  ENDIF.
```

`insert_table_einvoice` is NOT behind that flag - it runs from
`CASE ls_posting_file-posting_type WHEN 'IRN_WRITEBACK'`, unconditionally.
So the checkbox means **"skip the generic writer"**, not "run the
e-invoice path".

Section 76 called it a path selector in the driver. It is not.

### Why it looks like one anyway

`/CLR/ZELT_INGESTION_SEL` declares `p_comm`, `p_meta`, `p_guid`,
`p_evt_ct`, `p_seq` - and no `p_einv`. So the second `SUBMIT` only works
when `get_exec_program` returned the posting report. Tick the box, receive
a `DATA_EXTRACTION` command, and the HANA driver submits an unknown
parameter into the ingestion report.

The flag therefore does behave as "this run is the posting run" - by
accident of the `SUBMIT`, not by design. Section 76's conclusion was
accidentally serviceable and its reasoning was wrong, which is the worse
of the two ways to be right.

`ZCL_EINV_ELT_EXEC_JOB` keeps reporting an extraction command and leaving
it queued, which is better than HANA's behaviour here, and now forwards
`iv_einvoice` to `trigger_posting_einvoice` so the generic writer can be
switched back on - previously it was hardcoded off with a comment
explaining that the parameter could not be expressed.

### `SEQUENCE` was never dropped

Section 71 said the component was dropped from `ZTELT_CONFIG`'s key in the
conversion, and section 76 refused to declare `P_SEQ` on that basis.

```
  CLIENT     KEY
  PROJECTID  KEY  ZDE_PROJECT_ID
  SYSID      KEY  SYSYSID
  LABELTYPE  KEY
  SEQUENCE   KEY        <-- it is right there
  LOW
  HIGH
```

What was dropped is the `WHERE` condition that used it:

```abap
" /CLR/ZCL_ELT                     ZCL_ELT, as converted
SELECT label_type, low             SELECT labeltype, low
  FROM /clr/zt_elt_cnfg              FROM ztelt_config
  WHERE sys_id   = @sy-sysid         WHERE sysid = @sy-sysid
    AND sequence = @iv_seq.
```

and, with it, the `IV_SEQ` parameter of the constructor that fed it.

This matters more than a missing selection field. `SEQUENCE` is a key
component, so an unfiltered read returns **every profile maintained for
the system**, and the `READ TABLE gt_erp_config WITH KEY label_type = ...`
that follows takes whichever row came back first. One profile: invisible.
Two: the job silently uses the wrong endpoint, token or project id, and
nothing reports it. That is a latent defect, not a missing convenience.

This is the fifth instance of the pattern this document keeps recording -
a converted method that does less than its original, with a plausible
substitute in its place (sections 52, 56, 57, 59). The new part is how it
was argued *for*: section 76 reasoned from the converted artefact to a
claim about the HANA original, then used that claim to justify not
restoring a parameter. The HANA source was on disk the entire time.

### What changed

| Object | Change |
|---|---|
| `ZCL_ELT` | constructor takes `iv_seq`; `get_erp_config` filters on it |
| `ZCL_EINV_ELT_POSTING` | `trigger_posting_einvoice( iv_einvoice )`; calls `insert_table( )` when it is initial, as HANA's guard does |
| `ZCL_EINV_ELT_EXEC_JOB` | `P_SEQ`; forwards `iv_seq` and `iv_einvoice` |
| `ZCL_ELT_EXEC_COMMAND_JOB` | `P_SEQ` declared and passed on both paths |
| `ZCL_EINV_SUBMIT` | `iv_seq`, as `/CLR/EINV_EWAY_TRIGGER_ELT` had it |
| both `ZAJT_ELT_EXECUTE_COMMAND*` | `P_SEQ` added |

The filter is applied only when a sequence is supplied:

```abap
IF gv_seq IS INITIAL.   " today's read, unchanged
ELSE.                   " HANA's read
```

Strictly faithful would filter always - blank means `sequence = 0`. The
rows in F3Y were maintained while this read ignored the column, so an
unconditional filter could blank a working configuration on the first run.
Confirm what sequences are maintained in `ZTELT_CONFIG`, then drop the
`IF` and keep the filtered `SELECT`.

### Not converted: the PARALLEL_RUN guard

Before its loop the HANA report checks whether another instance is
already running, unless configuration says concurrency is allowed:

```abap
SELECT SINGLE low FROM /clr/zt_elt_cnfg INTO @DATA(lv_check)
  WHERE sys_id = @sy-sysid AND label_type = 'PARALLEL_RUN'
    AND sequence = @p_seq.
IF lv_check EQ abap_false.
  CALL FUNCTION 'BP_FIND_JOBS_WITH_PROGRAM' ...
```

`BP_FIND_JOBS_WITH_PROGRAM` and `sy-batch` are both unavailable in ABAP
Cloud, and no released replacement has been identified. It is **not**
implemented, and it is recorded here rather than quietly omitted, because
its absence is exactly the condition section 76 warned about: two runs
polling one command queue. Until it exists, do not schedule the two
templates so they overlap.

## 78. The catalog entry is what makes a parameter visible

Pulling section 77 produced three activation errors:

```
Hidden parameter 'P_EINV'   should not be used in template   line 14
Hidden parameter 'P_MAXSEC' should not be used in template   line 18
Hidden parameter 'P_RETRY'  should not be used in template   line 22
```

Three of the four new parameters, and not `P_SEQ` at line 26 - the one
whose template value was blank. An unused parameter is not checked.

### "Hidden" does not mean a flag on the class

The word sends you looking for a visibility indicator in
`GET_PARAMETERS`, next to `CHANGEABLE_IND` and `MANDATORY_IND`. There
isn't one. The declaration that matters is in the **catalog entry**:

```
  .sajt.json  template   sets values            -> names a catalogName
  .sajc.json  catalog    DECLARES "parameters"  -> names a className
  class       ABAP       GET_PARAMETERS
```

A parameter the class offers but the catalog entry does not list is hidden,
and a template may not set it. Section 76 added the parameters to the class
and stopped there.

The package answered this itself, in a single query:

```
zajc_einv_status           ZCL_EINV_STATUS_JOB        [P_BUKRS, P_MAXROW]
zajc_einv_fetch            ZCL_EINV_EDOC_FETCH_JOB    [P_BUKRS, P_TYPE, ...]
zajc_elt_execute_command   ZCL_ELT_EXEC_COMMAND_JOB   ABSENT
```

Every catalog entry in the package declares its parameters. The ELT one
does not - because its class's `GET_PARAMETERS` was empty, so there was
nothing to declare and nobody noticed the block was missing.

`ZAJC_ELT_EXECUTE_COMMAND` now carries

```json
"parameters": [ { "name": "P_EINV" }, { "name": "P_SEQ" },
                { "name": "P_MAXSEC" }, { "name": "P_RETRY" } ]
```

and `ZAJT_ELT_EXECUTE_COMMAND_1` keeps `P_EINV = "X"`. The other three
template values are blank: `MAXSEC` and `RETRY` get 900 and 3 from the
class's `ET_PARAMETER_VAL`, which is where a default belongs.

### Two APJ styles, and why the detour was instructive

Checking the hypothesis meant reading `ZAJC_INSTRU_EXEC`, which turned out
to use the other style entirely:

| | parameters declared in | class implements |
|---|---|---|
| `ZCL_EINV_*_JOB`, `ZCL_ELT_EXEC_COMMAND_JOB` | class `GET_PARAMETERS` + catalog `parameters` | `IF_APJ_DT_EXEC_OBJECT` + `IF_APJ_RT_EXEC_OBJECT` |
| `ZCL_INSTRU_EXEC` | catalog only, with `sections`, `groups`, `enabledByParameter` | `IF_APJ_RT_RUN` |

`ZCL_INSTRU_EXEC` has no `GET_PARAMETERS` at all. The catalog entry is the
single place both styles agree on, which is why **rule 65** reads the
catalog rather than the class.

The first version of rule 65 read `GET_PARAMETERS` and reported thirteen
problems against `ZAJT_INSTRU_EXEC` - a working template whose job runs
today. A rule that disagrees with a production object is wrong about the
rule before it is right about the object, and following that disagreement
is what found the second style and the actual declaration site.

### `P_SEQ` is INT4 here, not INT2

`/CLR/ZT_ELT_CNFG-SEQUENCE` is `INT2`, and every HANA caller typed its
parameter accordingly - `p_seq TYPE int2`, `VALUE(IV_SEQ) TYPE INT2`. The
converted `ZTELT_CONFIG-SEQUENCE` is **INT4**. The parameter was first
declared `datatype = 'INT2' length = 5` from the HANA source while the
ABAP type behind it, `ztelt_config-sequence`, was INT4. Corrected to
`'INT4' length = 10` in both job classes.

Small, but it is the same habit as section 58: a type copied from the
original without checking what the conversion made of the field it
describes.

### Rule 65

Flags a `.sajt.json` parameter that its catalog entry does not declare.
Self-tested by removing the new `parameters` block and confirming it
reproduces the tenant's message for all four parameters across both
templates, then restoring it.

What it cannot see is activation state: a template whose catalog entry is
correct here is still rejected in the tenant if that catalog entry has not
been activated yet. Activation order for this change is in
`NEXT_STEPS.md`, and the catalog entry comes before the templates.

## 79. The government status, as its own column

The AR dashboard shows one **Status**. The request was to show what the
tax authority answered - `PA_EXCHG_STAT` and `PA_EXCHG_RESMSG` of
`ZTEINV_SALES_ST`, written by the IRN write-back of the `DATA_POSTING`
job.

### The join already existed

Nothing had to be built. `ZCDS_INT_EINV_LIVE` already carries

```abap
association [0..1] to ZCDS_INT_EINV_DOC_STAT as _Exchange
  on $projection.BillingDocument = _Exchange.BillingDocument and ...
```

and `ZCDS_INT_EINV_DOC_STAT` is the view over `zteinv_sales_st`, with all
six stages mapped. The four-field document key of `ZTEINV_SALES_ST`
(`VBELN`, `BELNR`, `BUKRS`, `GJAHR`) is exactly the dashboard's own key,
so the association is 1:1 and LEFT - a document with no authority response
still shows.

What was missing is that the dashboard only ever saw those fields
*folded in*:

```abap
coalesce( _Exchange.PaExchangeStatus,
          coalesce( _Async.SyncStatus, _Doc.status ) )  as EffectiveStatus
```

A single column cannot say which stage spoke. A row reading `COMPLETED`
may mean the authority validated the invoice, or merely that the
submission to the platform succeeded and the authority has said nothing -
and those are different facts to an AR clerk chasing a rejection.

### What was added

| Layer | Change |
|---|---|
| `ZCDS_INT_EINV_LIVE` | `GovernmentStatus`, `GovernmentResponseCode`, `GovernmentMessage` from `_Exchange`, plus `GovernmentCriticality` |
| `ZCDS_CUN_EINV_WORKLIST` | the four exposed; `GovernmentStatus` also a selection field |
| `ZCDS_MET_EINV_WORKLIST` | columns at 110, 120, 130, right after Message |

`EffectiveStatus` is unchanged and still leads with the government stage.
The two columns therefore agree whenever the authority has reported, which
is correct rather than redundant: Status answers "how far has this got",
Government Status answers "what did the authority say".

The behaviour definition needed no change. `ZCDS_CUN_EINV_WORKLIST` is
unmanaged with no create and no update, and its `field ( readonly )` list
covers the keys only (section 48), so read-only display fields are added
to the view alone.

### Blank is a state, not a defect

`ZTEINV_SALES_ST` is empty in client 100 today - the data preview
retrieves no rows. That is expected and it is not what this section fixes:
the table fills when a `DATA_POSTING` command is processed, and until
sections 76 to 78 the e-invoice job could not be scheduled to process one.

So `GovernmentCriticality` maps blank to 0, neutral - not red. An
unreported invoice is not a rejected one, and a dashboard that colours
silence as failure trains its users to ignore the colour. Unknown values
the platform may add later also fall to neutral for the same reason;
only the statuses actually listed get a colour.

### Order of operations

The columns appear as soon as the views are activated, blank. They fill
on their own once the posting job runs. There is no migration and nothing
to backfill - the write-back writes the table directly, and the dashboard
reads it live.

## 80. Refresh Status could erase the status

### The chain

```
Refresh Status                            ZCDS_MET_EINV_WORKLIST
  dataAction 'WorklistRefreshStatus'
    -> action WorklistRefreshStatus       ZCDS_CUN_EINV_WORKLIST (bdef)
      -> METHOD worklistrefreshstatus     ZBP_CDS_CUN_EINV_WORKLIST (locals)
           MODIFY ENTITIES OF zcds_int_einv_doc
             ENTITY einvoice EXECUTE RefreshStatus
        -> action RefreshStatus           ZCDS_INT_EINV_DOC (bdef)
          -> METHOD refreshstatus         ZBP_CDS_INT_EINV_DOC (locals)
               ZCL_EINV_CONFIG~get_transaction_type
               ZCL_EINV_API_CLIENT~get_status      <- the HTTP GET
               MODIFY ... UPDATE FIELDS ( SyncStatus ErrorText )
```

The worklist owns no data; its action exists only to delegate with EML to
the real business object, and the cockpit's own Refresh Status reaches the
same `refreshstatus`. HANA equivalent: `get_status` -> `call_get_status`
of `/CLR/ZCL_EINV_BASE`.

### What tracing it turned up

The screenshot that prompted the question shows `1400000000` with an empty
**Status**. An earlier screenshot of the same row shows `SUCCESS`. Between
them, Refresh Status was pressed.

`ZCL_EINV_API_CLIENT~get_status` returns an **empty** `status` on three
paths: a transport error (`RETURN` after setting `message`), an empty
response body, and a non-200 response. `refreshstatus` then wrote it
anyway:

```abap
APPEND VALUE #( %tky                = ls_doc-%tky
                %control-SyncStatus = if_abap_behv=>mk-on
                SyncStatus          = ls_status-status   " may be empty
                ErrorText           = ls_status-message )
  TO lt_update.
```

HANA does not. `call_get_status` wraps its `UPDATE /clr/zt_einv` in three
nested guards:

```abap
IF lv_status = 200.                 " HTTP 200 only
  IF ls_response IS NOT INITIAL.    " a body that parsed
    IF sy-subrc IS INITIAL.         " the row was found
      UPDATE /clr/zt_einv SET status = ... error = ...
```

All three were dropped in the conversion. One unreachable endpoint, one
expired token, one 500 from the platform, and every selected row's status
is replaced with blank - the single column this screen exists to show,
erased by the button meant to update it.

That it was found by answering "which method does Refresh Status call"
is worth recording on its own. The question needed four files read in
order; the defect was in the fourth, and nothing in the first three hinted
at it.

### The same destruction one level down

The old `ZTEINV_ERR` child rows were deleted **before** the loop, for
every selected key, because `ERRORNO` is part of the key and a second
refresh would collide with the first. So a document whose status call
failed also lost the error detail it already had, and got nothing back.

### Fixed

Nothing is written unless the platform answered:

```abap
IF ls_status-success = abap_false OR ls_status-status IS INITIAL.
  ... reported: "Status not refreshed: <reason>" ...
  CONTINUE.
ENDIF.
APPEND ls_doc TO lt_refreshed.
```

and the delete now runs against `LT_REFRESHED` rather than `KEYS`, after
the loop instead of before it. The `CREATE BY \_Error` moved out of the
loop with it: it was correct inside only because `LT_ERR_CREATE` was
`CLEAR`ed on every pass, and the table now accumulates. Both `MODIFY`
statements are guarded by `IS NOT INITIAL`, so a refresh where every call
failed issues no statement at all instead of an empty one.

A failed refresh is now reported as a warning carrying the platform's own
text, which is strictly more than the old behaviour said: previously the
only evidence was the status going blank.

### Why the blank looked plausible

`EffectiveStatus` coalesces exchange, then async, then sync status, so a
blank sync status with no exchange row produces a blank column rather
than an error. Section 79 had just added the government columns, which
are legitimately blank today. Two different blanks, one of them a bug,
arriving in the same screen at the same time.

## 81. The government reporting history

A 2026-10 HANA drop rewrote `call_get_status` and added
`/CLR/ZT_EINV_PPF`. The status call now does two things it did not do
before: it parses a `GovtReportingDetails[]` block, and it keeps that
block as a history table.

### The shape

```
GovtReportingDetails[]            -> SEQNO   (entry index)
  transactionId, action, actionType, status, receivedAt
  StatusReasons[]                 -> RSNNO   (reason index)
    code, messages[]              -> joined with '; ' into REASON_TEXT
```

The cross product is flattened into one table, and an entry with no
reasons still produces a row, at `RSNNO = 000`. That detail is easy to
drop and would lose the most ordinary case there is: a successful report
with nothing to complain about.

### What was built

| Object | |
|---|---|
| `ZTEINV_PPF` | 20 fields, 7 key - the table |
| 3 domains, 4 data elements | only where nothing existing fit: `TRANS_ID` 60, `PPF_ACTION`/`PPF_ACTTYP` 30, `REASON_TEXT` 1333 |
| `ZTEINV_DOC` + 3 fields | `GOVT_STATUS`, `GOVT_PPF_STATUS`, `GOVT_PPF_ACTION` |
| `ZCDS_INT_EINV_PPF` / `ZCDS_CUN_EINV_PPF` | `composition [0..*] of` the document, projection, behaviour |
| `ZCDS_MET_EINV_PPF` | a **Government Reporting** tab, newest first |
| `ZCL_EINV_API_CLIENT` | second deserialize pass, `iso_ts_split` |
| `lhc_einvoice~flatten_ppf` | `save_ppf_details`, minus the persistence |

Seven existing data elements were reused where the public cloud field is
the same or wider - `ZDE_EINV_DOCID` is CHAR 60 against HANA's CHAR 50,
`ZDE_EINV_STATUS` CHAR 40 against CHAR 20. Wider is safe; narrower would
truncate, which is the check worth doing before every reuse.

### Two deserialize passes of one body

`/ui2/cl_json` ignores JSON members the target type does not have, so one
response can be read twice into two different shapes. HANA does this to
keep `/CLR/EINV_STR_STATUS` - shared with other flows - untouched. Here
the reason is stronger: `ZSTR_EINV_STATUS_RES` is a DDIC structure, and
`GovtReportingDetails` nests `StatusReasons`, which nests a message
array. A DDIC structure cannot express that at all, so the second pass
targets a local `TYPES` hierarchy.

### `DELETE FROM` + `INSERT` is not available

`save_ppf_details` ends with

```abap
DELETE FROM /clr/zt_einv_ppf WHERE bukrs = ... AND vbeln = ...
INSERT /clr/zt_einv_ppf FROM TABLE lt_ppf ACCEPTING DUPLICATE KEYS.
```

Neither statement is legal in the RAP interaction phase (section 50), so
the full replace runs through the composition instead: read the
document's `_Ppf` children, `DELETE` them by EML, `CREATE BY \_Ppf` the
new set. `ACCEPTING DUPLICATE KEYS` needs no equivalent, because the
delete has already cleared the key range - it was guarding against a
re-insert the EML form cannot produce.

So `FLATTEN_PPF` returns rows and writes nothing. It also cannot take or
return a RAP derived type - `TABLE FOR CREATE` is not accepted in a
method signature, the same limitation already recorded for
`read_documents` - so it works in a plain `TY_PPF_ROW` structure that the
caller turns into `%target` entries.

### The latest entry

```abap
IF lv_key > lv_max_key OR
 ( lv_key = lv_max_key AND lv_seq >= lv_max_seq ).
```

Kept verbatim, including the `>=` that makes the LAST array index win a
tie. `LV_KEY` is the ISO timestamp reduced to `YYYYMMDDHHMMSSmmm` - fixed
width, all digits, so a character comparison orders instants correctly -
and an unparsable timestamp yields SPACE, which can never win.

`ISO_TS_SPLIT` is lenient by design and accepts what the authority
actually sends: with and without fractional seconds, with `Z`, with a
numeric offset, and with a space instead of `T`. `.1` means 100ms, so the
fraction is padded to three places rather than converted. No timezone
conversion: `/CLR/ZT_EINV_PPF` calls these fields UTC because that is how
the authority stamped them, and converting would silently restate someone
else's fact.

`EV_MSEC` is typed `ZDE_INT3`, not a bare `TYPE n` - which is NUMC length
**1**, and would have kept the first digit of the milliseconds and
dropped the other two. A one-character slip that no activation error and
no test without a sub-second tie would ever have caught.

### One deviation, for the same reason as section 80

HANA writes the three `GOVT_` fields unconditionally:

```abap
UPDATE /clr/zt_einv SET ... govt_status = lv_ppf_status
                           govt_ppf_status = lv_ppf_status
                           govt_ppf_action = lv_ppf_action
```

A status response without a `GovtReportingDetails` array therefore blanks
a government status that was previously reported. Its own
`save_ppf_details` header says an empty array "leaves the stored history
untouched", and a commented-out `IF lv_ppf_status IS NOT INITIAL.` still
sits directly above that `UPDATE`, so the intent is not in question.

Guarded here, through `%control`: the `GOVT_` fields and the QR code are
written only when the response carried them. The history is likewise
replaced only for documents that got a government block - `LT_PPF_CLEAR`
rather than every refreshed key.

### The dashboard column now has two sources

Section 79 wired **Government Status** to `PA_EXCHG_STAT`, written by the
posting job's IRN write-back. The PPF status is the same question
answered through a different channel, so the column coalesces rather than
duplicating:

```abap
coalesce( _Doc.govt_ppf_status, _Exchange.PaExchangeStatus )
```

PPF first because it is the pull - a refresh is a question asked just
now, where the exchange row is whatever the last posting run left behind.
**Government Action** joins it as its own column, since an action without
its status reads as nothing at all.

### Not ported

The status re-mapping through `/CLR/EINV_STATUS`
(`SYNC_STATUS -> SYNC_STATUS_TO_BE`, `SYNC_ICON`). `ZTEINV_STATUS` exists
here with the matching columns, but the raw platform status is stored as
before and the colour keeps coming from the `CASE` in the CDS view. That
is a decision, not an oversight: re-mapping silently changes what every
existing row means, and the table would have to be maintained in client
100 first or statuses would fall through unmapped.

## 82. The expose line, and what BAS is not responsible for

Section 81 built `ZCDS_CUN_EINV_PPF`, redirected it from the projection,
gave it a behaviour and a metadata extension - and did not add it to the
service definition.

```abap
define service ZSD_EINV_DOC {
  expose ZCDS_CUN_EINV_DOC      as EInvoice;
  expose ZCDS_CUN_EINV_DOC_ERR  as EInvoiceError;
  expose ZCDS_CUN_EINV_DOC_STAT as EInvoiceExchange;
  expose ZCDS_CUN_EINV_ZIP      as EInvoiceArchive;
  ...                                  " and no EInvoicePpf
}
```

`redirected to composition child` wires the projection. It does not put
the entity in the OData service; the `expose` line does. Everything
activates without it - view, projection, behaviour definition, metadata
extension, service binding - and the first symptom is an object-page tab
with nothing behind it.

**Which is exactly the kind of symptom that gets sent to the UI team.**
An empty facet in a Fiori Elements app looks like a front-end defect, and
the BAS project is where someone would start looking. The annotation is
right, the app is right, and the entity is simply not in the metadata
document.

**Rule 66** now flags any consumption view that redirects a composition
child which the service definition exposing that view does not expose.
Self-tested by deleting the new `expose` line and confirming the message,
then restoring it.

### What actually needs doing in BAS for sections 79 to 81

Nothing structural, and that is worth stating plainly rather than leaving
the question open.

`ZSB_EINV_DOC` is an **OData V2** binding, and a V2 Fiori Elements list
report builds its columns from `@UI.lineItem` in the service metadata at
runtime. New columns and a new `#LINEITEM_REFERENCE` facet appear on
their own once the metadata changes. No manifest entry, no local
annotation file, no rebuild.

Two things do get in the way, and neither is a code change:

* **The metadata is cached.** The OData metadata document is cached by
  the gateway and by the browser. Until it refreshes, the app serves the
  old shape and the new columns are simply absent.
* **Saved variants pin the column set.** A user whose variant was saved
  before the change keeps the old columns, because that is what a variant
  is for. The columns are present and unselected, not missing.

The BAS work that remains is the work that was already outstanding and is
unrelated to these sections: the `multiSelect` flag and the Select All /
Deselect All controller extension, both described in
`ui/worklist/README.md`. Those are genuine UI concerns - a selection mode
and client-side button handlers - which is precisely why they live there
and the government columns do not.

## 83. The auth header, checked against a working call

A working cURL for the status endpoint:

```
curl --location 'https://api.mea.cleartax.com/einvoice/v1/documents/6ad761f7.../status?EInvoiceType=SALES' \
--header 'x-cleartax-auth-token: sandbox.1.56e29681-...' \
--header 'x-clear-country-code: AE' \
--header 'x-clear-trn: 100375173000003'
```

### Three of the four were already right

| cURL element | Where it comes from |
|---|---|
| the URL, with `&1` = document id and `&2` = transaction type | `ZTEINV_API`, `FUNCTIONALITY = EINV_STATUS` |
| `x-clear-country-code` | derived from the company code's country, or an `API_PARAMETER` row |
| `x-clear-trn` | an `API_PARAMETER` row of `ZTEINV_API` |
| the token value | `ZTELT_CONFIG`, `LABELTYPE = AUTH`, by `PROJECTID` + `SYSID` |

`get_endpoint` reads the `API_PARAMETER` rows by country and company
code, with a country-only fallback, sorted by sequence, and
`build_headers` loops them onto the request - the same convention
`call_get_status` had.

### The fourth was the header NAME, and it was my doing

The class documentation said:

> The auth header name was inconsistent: `x-cleartax-auth-token` in
> `/CLR/ZCL_EINV_BASE` and `/CLR/AP_EINVOICE`, but `x-clear-auth-token`
> in `FORM call_action_api` of the AP cockpit. **ZZCLR_ELT's ZCL_ELT uses
> `x-clear-auth-token`, so that is the one value used everywhere now.**

Counting the call sites:

```
x-cleartax-auth-token   /CLR/ZCL_EINV_BASE        3 sites
x-cleartax-auth-token   /CLR/AP_EINVOICE          2 sites
x-clear-auth-token      AP cockpit call_action_api  1 site
```

Five against one. And `ZCL_ELT` is not a sixth vote, because it is not
calling the same service: it talks to the ELT platform at
`/one-integration/...`, while this class talks to the e-invoice API at
`api.mea.cleartax.com/einvoice/...`. **Two services, two header
conventions, both correct.**

So the "inconsistency" was one outlier, and the resolution picked the
outlier - on the strength of a class in another package that had no say
in the matter. Every call `ZCL_EINV_API_CLIENT` makes has been sending
the wrong auth header.

The constant is now `x-cleartax-auth-token`. `ZCL_ELT` and the ELT config
Ping keep `x-clear-auth-token`, which is right for them.

### What made it findable

Not the code. The code was self-consistent, activated, and carried a
comment explaining itself. It took a known-good request from outside the
system to show the header was wrong - the same role the user's debugger
screenshot played in section 59, and the screenshot of the published
binding in section 74.

The pattern across all three: **when converted code and an outside
observation disagree, the observation wins, including when the code
comes with an explanation.** An explanation is a claim about the
original, and this one was a miscount.

### A duplicate header, avoided while in there

`x-clear-country-code` is both derived in `build_headers` and a plausible
`API_PARAMETER` row - the AE setup has four such rows and this call needs
two of them. Appending both would put the name on the wire twice, and
which one the server honours is not worth leaving to chance. A configured
row now replaces the built-in of the same name: explicit customizing is
the more specific statement of intent.

### Still outstanding: `get_auth_token` ignores SEQUENCE

```abap
SELECT SINGLE low FROM ztelt_config
  WHERE labeltype = 'AUTH'
    AND projectid = @ls_scope-cntry-projectid
    AND sysid     = @ls_scope-cntry-sysid
```

`SEQUENCE` is part of that table's key and is not in the WHERE clause -
exactly the defect section 77 fixed in `ZCL_ELT~get_erp_config`. With
one profile maintained, as today, `SELECT SINGLE` returns the only row
and nothing is wrong. With two, it returns an arbitrary one and the
wrong token goes out.

Not fixed here, because threading a sequence through `ZCL_EINV_CONFIG`
and every `ZCL_EINV_API_CLIENT` caller is a larger change than this
section warrants. Recorded so it is a decision rather than an oversight.

## 84. What fills the three tabs

| Tab | Entity | Table | Written by |
|---|---|---|---|
| Exchange Status | `_Exchange` | `ZTEINV_SALES_ST` | the **DATA_POSTING background job** |
| API Errors | `_Error` | `ZTEINV_ERR` | **Refresh Status**, and **Seller Action** on rejection |
| Government Reporting | `_Ppf` | `ZTEINV_PPF` | **Refresh Status** |

Two of the three fill from a button. The first does not, and that is the
part worth being explicit about.

### Exchange Status comes from the job, never from the UI

`ZTEINV_SALES_ST` is written by `ZCL_EINV_ELT_POSTING~insert_table_einvoice`,
driven by an `IRN_WRITEBACK` row in a `DATA_POSTING` posting file. The
platform pushes that file; the job picks it up. No action on the object
page writes this table, so a document that has been submitted and never
had a posting command processed shows an empty Exchange Status tab
indefinitely - which is the current state of `1400000000`.

The route is: schedule `ZAJT_ELT_EXECUTE_COMMAND_1` (sections 76-78), let
it receive a `DATA_POSTING` command for the document, and the tab fills.

### API Errors is Refresh Status - and now Seller Action again

In HANA, `/CLR/ZT_EINV_ERR` has exactly two write sites, both inside
`call_seller_action`:

```abap
IF ls_response-_success = 'true'.
  DELETE FROM /clr/zt_einv_err WHERE checkbox = '' AND <document>.
ELSE.
  LOOP AT ls_response-_error_details ... APPEND to lt_error ...
  MODIFY /clr/zt_einv_err FROM TABLE lt_error.
ENDIF.
```

`call_get_status` does **not** write it - it concatenates the messages
into the single `error` field. This conversion deliberately added the
status path (section 72: the detail rows are persisted as children so the
object page can list them individually), which is why Refresh Status
fills the tab here and did not in HANA.

But the conversion of `call_seller_action` kept only the `IF` half. The
`ELSE` was dropped, so a **rejected seller action wrote no error rows**:
the whole explanation collapsed into the one-line `ErrorText`, and the
tab the detail belongs in stayed empty. The `ELSE` is restored, with the
same clear-then-renumber the status path uses, because `ERRORNO` is part
of the key.

This is the sixth instance of the pattern (sections 52, 56, 57, 59, 77):
a converted method that does less than its original. The new wrinkle is
that it was an `IF`/`ELSE` where only one branch survived - the method
looked complete, and the surviving branch even carried a comment quoting
the HANA statement it replaced.

### Government Reporting is Refresh Status

`ZTEINV_PPF`, from the `GovtReportingDetails` block of the status
response (section 81). Empty until a Refresh Status call returns that
block - and until section 83's header fix, no status call was succeeding
at all.

### Reading the screenshot

`1400000000` is *Submitted to exchange network* with all three tabs
empty, and that is consistent rather than broken:

* Exchange Status - no posting command has been processed for it yet.
* API Errors, Government Reporting - no successful Refresh Status yet,
  which section 83 explains.

The order to bring them to life: pull section 83, press Refresh Status
(fills API Errors if the platform reports any, and Government Reporting),
then schedule the posting job (fills Exchange Status).

## 85. What ZTEINV_CONST is for

`/CLR/EINV_CONST`, converted. A generic key/value table - scope columns
`PROJECTID + SYSID + PRODUCT + LAND1 + BUKRS + ZLABEL + SEQUENCE`, value
columns `LOW` and `HIGH` - so a new per-country or per-company-code
setting needs a row rather than a field.

HANA used four labels. This package reads two.

| Label | HANA | Public cloud |
|---|---|---|
| `EXCLUDE_DOC` | read by `einv_ewb_create` | **read** - `ZIF_EINV_COUNTRY~is_document_excluded`, `LOW` = `BLART` or `FKART` |
| `CANCEL_WINDOW_H` | - | **read** - `check_cancel_allowed`, `LOW` = hours |
| `AUTO_IRN` | transaction-code whitelist, `LOW` = `sy-tcode` | not ported |
| `AUTO_IRN_FI_WAIT`, `AUTO_IRN_SD_WAIT` | `LOW` = `sy-tcode`, `HIGH` = seconds, then `WAIT UP TO` | not portable |

### Why two of them are gone

The `AUTO_IRN` whitelist asked "was this document entered through one of
these transactions". There is no `sy-tcode` behind a Fiori app, so the
question cannot be asked - and the intent, "only auto-generate for these
entry channels", is better expressed as a document-type restriction in
`ZTEINV_INVMAP`, which the relevance check already evaluates.

The two `WAIT` labels are doubly unavailable: keyed on `sy-tcode`, and
implemented with `WAIT UP TO n SECONDS`, which blocks a work process and
is not released for ABAP Cloud (same reason the retry loop went from
section 52's trigger). They existed to let the posting transaction finish
writing before the e-invoice was generated; in RAP that ordering is the
LUW's job, not a sleep's.

### `CANCEL_WINDOW_H` is new here

HANA hardcoded the 72-hour cancellation window in message 089 of
`/CLR/ZME_EINV`. Making it a constant rather than a literal is the one
addition to this table, and it is why `check_cancel_allowed` takes a
company code at all - `get_constants` derives the country from it.

### Empty is the correct state

Both live labels default safely with no rows at all:

* no `EXCLUDE_DOC` row - nothing is excluded,
* no `CANCEL_WINDOW_H` row - 72 hours, HANA's literal.

So an empty Constants list is not something to fill in. Maintain a row
only to exclude document types from auto-generation, or to change the
cancellation window for a country or company code.

Worth noting what `EXCLUDE_DOC` used to do: the HANA
`is_document_excluded` had an **empty body** and therefore always
answered "excluded". Maintaining that constant in HANA suppressed every
document. The rule the configuration was evidently meant to express -
`LOW` matches the accounting or billing document type - is implemented
here, so the row now does what its name says.

### Lookup resolution, and three key columns nothing filters

`get_constants` takes company-code rows first and falls back to
country-wide rows (`BUKRS = space`), matching on `PRODUCT`, `ZLABEL`,
`LAND1` and `BUKRS`. `PRODUCT` defaults to `'EINV'`.

`PROJECTID`, `SYSID` and `SEQUENCE` are key columns and **no lookup
filters on any of them** - `load_all` reads the table with no WHERE
clause at all. With one project, one system and one sequence per label
this is invisible; beyond that the first matching row wins arbitrarily.
Same family as sections 77 and 83, recorded rather than changed, because
the scope of a fix is every caller of `get_constants` and the table is
empty today.

## 86. ZTEINV_STATTX: dead in HANA, left dead here

Two columns, `STATUS_CODE` and `STATUS_TEXT`, wired to the F4 behind the
cockpit's **Status** filter:

```
ZCDS_INT_EINV_STATTX -> ZVH_EINV_STATUS -> @Consumption.valueHelpDefinition
                                            on ZCDS_CUN_EINV_DOC.EffectiveStatus
```

Nothing else reads it - no ABAP, no other view.

### The HANA counterpart exists, and is dead

The first version of this section said there was **no** HANA counterpart
and that the conversion had invented the table. Wrong. It is
`/CLR/YT_STATUS` - `MANDT`, `STATUS_CODE`, `STATUS_TEXT` - and it was
missed because the search was for `EINV_STATTX`-shaped names while the
original is `Y`-prefixed and described simply as "Status".

In HANA the table has nothing but its generated SM30 maintenance function
group, and the one place that would have opened it is commented out:

```abap
*    WHEN rc10.
*      CALL  TRANSACTION '/CLR/YT_STATUS'.
```

Not merely unread - unreachable. The `Y` prefix says the same thing.

### What was changed and then unchanged

`ZVH_EINV_STATUS` selects `StatusCode` alone, with a redundant
`GROUP BY` over the key of its own source, and drops `StatusText`. That
is a real observation, and a pointless one: with the table empty the F4
returns nothing whichever columns the view selects, and the table is
empty by design on both sides.

The fix was written, then reverted on the owner's instruction, and
`ZVH_EINV_STATUS` is byte-identical to the tenant copy again. Recorded
rather than quietly dropped, because the reasoning is the point: a
defect in a path that nothing travels is not a defect to spend an
activation on, and "the code is wrong" does not by itself establish that
the code matters. Section 70 reached the same conclusion about
`ZTEINV_PDF` from the opposite direction - written and never read - and
that one was worth building out because the write side was live.

### If it is ever wanted

Maintaining the table makes the F4 work, and fixing the view makes it
show text rather than bare codes. Both are small. Neither is needed while
the filter accepts typed input, which it does.


## 87. ZTEINV_STATUS: maintained, ignored, retired

### Where it is read, and where that ends

```
ZTEINV_STATUS
  -> ZCL_EINV_CONFIG~get_criticality        (matches LAND1 + BUKRS + STATUS)
    -> ZIF_EINV_COUNTRY~map_criticality     (config wins, SWITCH as fallback)
      -> ZCL_EINV_VE_CRITICALITY            (IF_SADL_EXIT_CALC_ELEMENT_READ)
        -> nothing
```

`ZCL_EINV_VE_CRITICALITY` is a virtual-element exit, and **no CDS view
references it**. The 2026-10-01 activation reported
`@ObjectModel.virtualElement` as not released for ABAP Cloud, so
`StatusCriticality` became a `CASE` in the view instead - and the whole
chain below it was left connected to nothing.

So the dashboard's colour has never come from this table. It comes from

```abap
case upper( coalesce( _Exchange.PaExchangeStatus, ... ) )
  when 'VALID' then 3  when 'ERROR' then 1  ...  else 0
end as StatusCriticality
```

in `ZCDS_INT_EINV_DOC_ENR` and `ZCDS_INT_EINV_LIVE`.

### What that cost in F3Y

Ten rows are maintained for `AE10`, and the `CASE` knew eight statuses:
`VALID`, `COMPLETED`, `COLLECTED`, `ERROR`, `INVALID`, `CANCELLED`,
`SUBMITTED`, `PENDING`. Of the ten configured, only **ERROR** and
**VALID** overlapped. `SUCCESS`, `REJECTED`, `FAILURE`, `Received`,
`DELIVERED TO BUYER` and `DELIVERED TO BUYER NETWORK` all fell through to
`else 0` - neutral grey - including the two the customizing explicitly
marks criticality 3.

A table nothing reads is invisible. A table nothing reads whose values
are *also* absent from the hardcoded substitute is visible, as a
dashboard of grey rows.

### Decision: retire the table, extend the CASE

Taken by the owner. The trade is explicit: a new platform status now
needs a transport rather than a config row, and in exchange there is one
mapping instead of two with only one of them live.

The list is now, in all four places:

| Criticality | Statuses |
|---|---|
| 3 positive | `VALID` `SUCCESS` `COMPLETED` `COLLECTED` `ACCEPTED` `DELIVERED TO BUYER` |
| 2 critical | `SUBMITTED` `PENDING` `RECEIVED` `DELIVERED TO BUYER NETWORK` |
| 1 negative | `ERROR` `FAILURE` `INVALID` `REJECTED` `CANCELLED` |
| 0 neutral | everything else, including blank |

`DELIVERED TO BUYER` is 3 because the customizing says so. The others are
read from the words and **need confirming against the ten rows before
those rows are deleted** - particularly `DELIVERED TO BUYER NETWORK` and
`RECEIVED`, which are judgement calls between "in progress" and "done".

### The rule found two more expressions

Rule 67 was written to keep the four Sales expressions in step and
immediately reported two that were not in the plan at all:
`ZCDS_INT_EDOC_APENR` and `ZCDS_INT_EDOC_SBENR`, with a different
vocabulary - `APPROVED`, `CLEARED`, `SENT`, `IN_PROGRESS`, `FAILED`.

That is not drift. The Sales flow speaks the Clear e-invoice vocabulary
and the AP / self-billed flows speak the eDocument one, and the two AP/SB
expressions agree with each other exactly. The rule was too blunt, not
the code - so it now compares **within a family**, keyed on `einv` or
`edoc` in the view name.

Across families it checks something better: a status listed by both must
carry the same criticality. `ACCEPTED` is 3 and `REJECTED` is 1 on both
sides today, and a future edit that disagreed would be a contradiction
rather than a vocabulary difference. Both halves self-tested - one by
deleting a `when` line, one by changing a `then` value.

This is the third rule in this conversion whose first version was wrong
about the package rather than the package being wrong about itself
(sections 72, 78). The tell each time was the same: a rule that fires on
something demonstrably working.

### What is NOT deleted

The repository still contains `ZTEINV_STATUS`, `ZCDS_INT_EINV_STATUS`,
its consumption view, behaviour and the Status Mapping app, plus
`ZCL_EINV_VE_CRITICALITY` and `ZCL_EINV_CONFIG~get_criticality`. None of
it is read.

Removing it from the repository would not remove it from F3Y - section 44,
a pull does not delete - so deleting the files only risks a half-state
where the tenant keeps objects the repository has forgotten. The honest
record is this section plus `NEXT_STEPS.md`, which lists the objects to
delete by hand in ADT if the app is to go for good.

## 88. ZTEINV_DOCTYP translates the document type for two URLs

Unlike sections 86 and 87, this one is live.

```abap
METHOD get_transaction_type.
  ls_doctyp = mt_doctyp[ land1 = lv_country bukrs = iv_bukrs
                         doc_type_code = iv_doc_type ].
  rv_result = ls_doctyp-transact_type.
  IF iv_b2c = 'X'. rv_result = |{ rv_result }_B2C|. ENDIF.
ENDMETHOD.
```

**In** goes the SAP document type code (`ZTEINV_DOC-DOC_TYPE`, `380` for
`1400000000`); **out** comes the platform's transaction type, with `_B2C`
appended when the document is B2C. Two callers, both in
`ZBP_CDS_INT_EINV_DOC`:

* `refreshstatus` -> `get_status( iv_doc_type )` -> `&2` of the
  `EINV_STATUS` URL
* `requestprintout` -> `get_printout( iv_doc_type )` -> `&2` of the
  `EINV_PRINT` URL

That is the whole of it. `DOC_TYPE_DESCR` is read by nothing - it exists
for the maintenance list, which is a legitimate use for a description.

### Faithful to HANA, including the join direction

`/CLR/ZCL_EINV_BASE~get_status`:

```abap
LEFT OUTER JOIN /clr/einv_doctyp AS dty ON dty~doc_type_code = inv~doc_type
...
lv_trns_type = <lfs_invoice>-transact_type.
IF b2c IS NOT INITIAL. lv_trns_type = |{ ... }_B2C|. ENDIF.
call_get_status( iv_doc_type = lv_trns_type ).
```

Same join, same output column, same `_B2C` suffix. The conversion did not
change this.

### The maintained row disagrees with the working cURL

F3Y has one row: `AE10 / F3Y / AE / AE10 / INV / 380 / Invoice`. So for
document `1400000000`, whose `DOC_TYPE` is `380`, `get_transaction_type`
returns **`INV`** and the status URL becomes

```
.../documents/{id}/status?EInvoiceType=INV
```

The cURL that is known to work for that same document sends

```
.../documents/{id}/status?EInvoiceType=SALES
```

Section 83 listed "`TRANSACT_TYPE = SALES` for AE / doc type 380" as a
thing to confirm; the row now shown says `INV`. One of three things is
true, and only the tenant can say which:

1. the row is wrong and should read `SALES`;
2. the `EINV_STATUS` URL in `ZTEINV_API` does not carry `&2` at all - it
   hardcodes `EInvoiceType=SALES` - in which case the row is unused for
   the status call but still feeds the printout URL;
3. `INV` and `SALES` are both accepted by the platform.

It is worth settling before the next Refresh Status, because the symptom
of (1) is a rejected call, and with section 80 in place a rejected call
now leaves the status alone and reports the platform's text - which will
name the parameter.

### A modelling wrinkle, inherited

`TRANSACT_TYPE` is a **key** field and the lookup's **output**. Two rows
may therefore share `DOC_TYPE_CODE` under different transaction types,
and the table expression picks whichever comes first. HANA had the same
shape - its `LEFT OUTER JOIN` would return both rows and the
`READ TABLE ... WITH KEY` took the first - so this is not a conversion
defect, but it does mean the configuration cannot express "380 is SALES
for the status call and INV for something else". With one row per
document type code it never arises.

`PROJECTID` and `SYSID` are likewise keys that the lookup does not
filter - the same family as sections 77, 83 and 85.

## 89. Five more tabs on ELT Config Details

Country Registration, VAT Registration and API Endpoints all carry
`PROJECTID` as their leading key, which is the key of
`ZCDS_CUN_COMP_DETAILS`. So they fit the page that already shows Company
Details, ELT Config and Instrumentation Config.

### The pattern was already here

`ZCDS_CUN_COMP_DETAILS` is **not** a projection. It is its own managed BO
over `ZTCOMP_DETAILS`, and its children are separate consumption views
that wrap an existing interface view and add a parent association:

```abap
define view entity ZCDS_CUN_ELT_CONFIG as select from ZCDS_INT_ELT_CONFIG
  association to parent ZCDS_CUN_COMP_DETAILS as _COMPANY_DETAILS
    on $projection.Projectid = _COMPANY_DETAILS.Projectid
```

while `ZCDS_INT_ELT_CONFIG` stays a standalone root BO with its own
`lock master`. Two managed BOs over one table, which is what lets the
same rows be a tab here and an app elsewhere.

Three new views follow it exactly: `ZCDS_CUN_COMP_CNTRY`,
`ZCDS_CUN_COMP_VAT`, `ZCDS_CUN_COMP_API`, over `ZCDS_INT_EINV_CNTRY`,
`ZCDS_INT_EINV_VAT` and `ZCDS_INT_EINV_API`. The standalone apps are
untouched - they keep their own consumption views and services.

### What was added

| | |
|---|---|
| 3 consumption views | parent association on `ProjectId`, `[0..*]` |
| 3 metadata extensions | facet + line items, mirroring `ZCDS_MET_INS_CONFIG_DETAILS` |
| `ZCDS_CUN_COMP_DETAILS` | 3 compositions, 3 exposures |
| its behaviour definition | 3 `association ... { create; }` plus 3 child blocks with `update`, `delete` and a full mapping |
| `ZSD_ELT_CONFIG` | 3 `expose` lines - section 82's lesson, applied without being re-taught |
| `ZCDS_MET_COMP_DETAILS` | facets at 40, 50, 60 |

Editing matches the existing two: create through the root's association,
update and delete on the child, locked and authorized through the root.

Tab order is registration, VAT, endpoints - a company code has to be
registered for a country before an endpoint for it means anything, and
the VAT number sits between because both the registration row and the API
headers carry it.

### Two lock masters per table, now five times over

`ZTEINV_CNTRY`, `ZTEINV_VAT` and `ZTEINV_API` are now each written by two
managed BOs: the standalone app's root and this composite child. RAP
permits it and `ZTELT_CONFIG` has been in that position since the ELT
Config tab was built, but the two lock masters do not see each other - a
row edited in both apps at the same time is last-writer-wins rather than
"locked by another user".

Accepted on the owner's decision to keep both entry points. Worth knowing
rather than discovering: it is a property of the shape, not a defect in
the new views, and retiring the standalone apps is what removes it.

### The checker earned its keep twice

`@EndUserText.label` is `STRING(40)`, and two of the generated labels -
`'Country Registration (ELT Config Details tab)'` at 45 characters and the
VAT one at 41 - were rejected before activation rather than after.

A scripted mapping check then confirmed all 25 columns across the three
tables are mapped, none missing and none invented. Worth running on any
hand-written `mapping for` block; a column silently absent from one is
exactly the sort of thing that activates cleanly and loses data.


## 90. Relevance Mapping and Document Types, the last two tabs

Same pattern as section 89, applied twice more:

| | |
|---|---|
| `ZCDS_CUN_COMP_INVMAP` | over `ZCDS_INT_EINV_INVMAP` / `ZTEINV_INVMAP`, 13 columns |
| `ZCDS_CUN_COMP_DOCTYP` | over `ZCDS_INT_EINV_DOCTYP` / `ZTEINV_DOCTYP`, 7 columns |

plus their metadata extensions, two compositions, two child behaviour
blocks, two `expose` lines and two facets at 70 and 80.

**ELT Config Details now has eight tabs**: Company Details, ELT Config,
Instrumentation Config, Country Registration, VAT Registration, API
Endpoints, Relevance Mapping, Document Types - the whole of the
e-invoice customizing behind one Project ID.

Tab order follows the question each one answers. The first six say who we
are and how to reach the platform; these two say which SAP documents to
send and what the platform should call them. `ZTEINV_INVMAP` decides
relevance (section 66's candidate views read it), and `ZTEINV_DOCTYP`
translates the document type for the status and printout URLs (section
88), so relevance comes before translation.

### The audit, run over all five

```
ZCDS_CUN_COMP_CNTRY    OK  table=10 mapped=10
ZCDS_CUN_COMP_VAT      OK  table=6  mapped=6
ZCDS_CUN_COMP_API      OK  table=9  mapped=9
ZCDS_CUN_COMP_INVMAP   OK  table=13 mapped=13
ZCDS_CUN_COMP_DOCTYP   OK  table=7  mapped=7
```

45 columns, none missing, none invented. Worth keeping as a habit for any
hand-written `mapping for`: a column absent from one activates cleanly
and then silently fails to save. `@EndUserText.label` was kept under 40
characters this time without the checker having to say so.

### What this does not change

`ZTEINV_INVMAP` and `ZTEINV_DOCTYP` are read by `ZCL_EINV_CONFIG` exactly
as before - `get_invmap`, `get_transaction_type`. The tabs are another way
in, not a change to how the configuration is consumed, and the standalone
apps still work. The two-lock-masters-per-table note of section 89 now
applies to five tables rather than three.
