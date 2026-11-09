# What this package is

Rebased on the repository pushed from the tenant on 07/10/2026
(second push), with the 22 LOWERCASE domain changes re-applied on top.

The SUP_TYPE removal is already in your base and already activated - that
work is finished. Nothing in this package needs an empty table.

## Pull and activate

Only 22 domains changed. `<LOWERCASE>X</LOWERCASE>` is a DDIC
input-conversion attribute, not a database column attribute, so there is
no table conversion and no activation order to respect. Pull, select the
22 `ZDO_*` domains, activate.

They are: `ZDO_EINV_URL`, `ZDO_EINV_PARAM`, `ZDO_EINV_PARAMVAL`,
`ZDO_EINV_VALUE`, `ZDO_EINV_ERRMSG`, `ZDO_EINV_RESMSG`,
`ZDO_EINV_ERRSRC`, `ZDO_EINV_ERRCODE`, `ZDO_EINV_RESCODE`,
`ZDO_EINV_NAME`, `ZDO_EINV_DOCID`, `ZDO_EINV_IDENT`, `ZDO_EINV_CMDID`,
`ZDO_EINV_REASONTXT`, `ZDO_EINV_ACTDESC`, `ZDO_EINV_DOCTDESC`,
`ZDO_EINV_INVNO`, `ZDO_EINV_STATUS`, `ZDO_EINV_VAT`, `ZDO_ELT_STRING`,
`ZDO_PROJECT_DIS`, and the data elements that use them will revalidate
automatically.

## After activating - two things that need testing

**Re-enter what is already stored.** The flag changes the next save; it
does not repair history. The API Endpoint rows are in capitals today and
have to be re-entered to carry their real case.

**Status Mapping is the risk.** Until now both sides of every status
comparison were upper-cased by the same DDIC default, so they matched by
accident. Now neither is. If the Clear platform returns `Pending` and the
configuration holds `PENDING`, a lookup that worked yesterday fails.
Re-enter the Status Mapping rows with the platform's exact casing and run
one document end to end before trusting it. Same shape of risk on
`ZDO_EINV_INVNO`.

See section 37 of CONVERSION_DESIGN.md.

## Still open, not caused by any of this

Six service bindings claim `PUBLISHED=true` but ship without their inbound
service objects - section 35. Fix is a push, not a code change.


# Live AR worklist (added 07/10/2026)

Five new CDS objects make the sales cockpit read candidates live instead
of from ZTEINV_DOC - see section 39 of CONVERSION_DESIGN.md.

## Activate, in this order

1. `ZCDS_INT_EINV_REL_BILL`
2. `ZCDS_INT_EINV_CAND`
3. `ZCDS_INT_EINV_LIVE`
4. `ZCDS_CUN_EINV_WORKLIST`
5. `ZCDS_MET_EINV_WORKLIST`
6. `ZSD_EINV_DOC` (service definition - now also exposes
   `EInvoiceWorklist`)
7. Re-publish `ZSB_EINV_DOC`

`ZCDS_INT_EINV_REL_BILL` reads `I_BillingDocument`. Its element names
were verified against F3Y on 07/10/2026 - `BillingDocument`,
`BillingDocumentType`, `BillingDocumentDate`, `CreationDate` and
`CompanyCode` all exist under those names, so no surprises are expected
here. The same check retires the long-standing verification note on
`ZCDS_INT_EINV_RELEVANT`.

## Then build the app

In BAS, generate a List Report on the same service (`ZSB_EINV_DOC`) with
**`EInvoiceWorklist`** as the main entity, no object page. Deploy, create
its IAM app, assign it to `ZBC_EINV_PROCESS`, and put the tile on
`ZLPP_EINV_PROCESS`.

Keep the existing cockpit app. The worklist is the "what is out there"
list; the cockpit is where a materialised document is worked on.

## What you will see - CONFIRMED 09/10/2026

Open it with Company Code `AE10` and a posting date range covering
02.10.2026. Both journal entries appear immediately - no pickup needed -
with **Status empty** and **Processed** blank. That blank status is the
"to be processed" state, exactly as the ALV showed it.

This is now verified in F3Y/100: `DZ 1400000000` and `DR 1800000000`
both render, neither has a staging row. See section 45.

**Mind the date format.** Posting Date is a `#INTERVAL` filter, so a
single value becomes an equality filter silently, and the field renders
in the *user's* format - MM/DD/YYYY for this user. 02.10.2026 has to be
typed `10/02/2026`. Use the picker's range option and the problem goes
away.

To act on one, run `PickUpDocuments` as before; the row then shows
Processed = X and its status follows the document.

## Open: metadata extension not applied

The list shows every field of the view in alphabetical order, which means
Fiori Elements found no `@UI.lineItem` annotations and
`ZCDS_MET_EINV_WORKLIST` is not reaching the service. Confirm it is
activated and that its `annotate entity` target names
`ZCDS_CUN_EINV_WORKLIST` exactly. Cosmetic only - the data is correct.


# Service bindings - settled (28/10/2026)

**All eight bindings are published in F3Y. There is nothing left to do in
the tenant.** The tenant push of 28/10 shows `PUBLISHED=true` on all five
of `ZSB_EDOC_AP`, `ZSB_EDOC_APFLAT`, `ZSB_EDOC_SB`, `ZSB_EDOC_SBFLAT` and
`ZSB_EINV_CONFIG`, alongside the three that were already published.

Earlier revisions of this file told you to delete twelve - later ten -
authorization-defaults shells (`*ht.sush.xml`) in ADT before publishing.
**Do not do that.** It is not possible (a developer gets *"No change
authorization for ABAP language version"*) and it is not necessary: every
one of those shells is still in F3Y and every binding published with it in
place. Section 43 diagnosed the shells as the blocker and was wrong;
section 74 sets it out, including how that wrong sentence survived three
repetitions of this file.

What is still true, and is the only open item here:

**abapGit does not serialise the inbound service for five of the eight
bindings.** `ZSB_EINV_DOC`, `ZSB_ELT_CONFIG` and `ZSB_EVENT_LOG` have
their `_iwsg.sco2.xml`; the other five do not, and repeated pushes have
not produced them. The consequence is limited and worth stating exactly:

* **F3Y is fine.** The endpoints exist and serve.
* **A fresh system built from this repository is not.** It gets the
  `PUBLISHED=true` flag and the authorization shells without the inbound
  service objects, and whoever sets it up has to open each of the five
  bindings and **Publish Locally** once.

That is what the five standing checker problems report. They are
repository fidelity, not a defect in the package, and they will keep
reporting until abapGit serialises those objects or the five are
recreated.

# Worklist action buttons (added 09/10/2026)

Six buttons on the live worklist: Pick Up, Submit e-Invoice, Refresh
Status, Request Printout, Seller Action, Cancel e-Invoice. See section 46.

## Objects to pull

    ZCDS_CUN_EINV_WORKLIST     CDS view entity       (changed - now `root`)
    ZCDS_CUN_EINV_WORKLIST     behaviour definition  (NEW)
    ZBP_CDS_CUN_EINV_WORKLIST  behaviour pool class  (NEW)
    ZCDS_MET_EINV_WORKLIST     metadata extension    (changed - buttons)

The view and the behaviour definition have the same name and different
types - pull the DDLS as well as the BDEF. Section 48: a behaviour can
only be written for a root entity, and the first version of this view was
not one.

## Activate, in this order

1. `ZCDS_CUN_EINV_WORKLIST` **view** (DDLS) - it must be root before the
   behaviour will activate
2. `ZBP_CDS_CUN_EINV_WORKLIST` (the class, so the bdef finds it)
3. `ZCDS_CUN_EINV_WORKLIST` behaviour definition
4. `ZCDS_MET_EINV_WORKLIST`
5. `ZSD_EINV_DOC` - re-activate so the service picks up the behaviour
6. Re-publish the service binding

The behaviour definition now carries `lock master` and `field ( readonly )`
on all eight keys, and the handler has an empty LOCK method. Both were
demanded by the F3Y activation - strict ( 2 ) exempts nothing, even a
behaviour with no create, update or delete. Section 48a.

## The metadata extension was never activated

That is why the list renders every field alphabetically: the extension
exists in the repository but Fiori Elements is finding no `@UI.lineItem`
annotations, so it falls back to showing everything. Activating it in
step 3 fixes the columns AND brings in the buttons - they are declared in
the same object.

## What to expect

On the two AE10 rows, which have never been picked up:

    Pick Up           enabled    (IsProcessed is blank)
    Submit e-Invoice  enabled    (no Clear document id yet)
    Refresh Status    greyed out
    Request Printout  greyed out
    Seller Action     greyed out
    Cancel e-Invoice  greyed out

Submit creates the ZTEINV_DOC row and submits in one step. After it
returns, press Go again - the actions declare no result, so the list does
not refresh itself.

## Multi-select (added 09/10/2026)

Checkbox column and mass submit. See section 47.

1. **ABAP**: pull `ZCDS_MET_EINV_WORKLIST` again - the four parameterless
   actions now carry `invocationGrouping: #CHANGE_SET`, which turns a
   multi-row press into one request and one LUW. Activate it.
2. **BAS**: add `"multiSelect": true` to the list report page's component
   settings in `webapp/manifest.json`. That is the checkbox column.
3. **BAS, optional**: Select All / Deselect All toolbar buttons - copy
   `ui/worklist/ext/controller/ListReportExt.controller.js` into the app
   and register it as described in `ui/worklist/README.md`. The header
   checkbox already does this; the buttons are parity with the HANA ALV.

No behaviour definition or handler change: SubmitEInvoice already accepts
a table of keys.

# Telemetry inside a RAP LUW (added 09/10/2026)

The first end-to-end Submit dumped with BEHAVIOR_ILLEGAL_STATEMENT: the
ELT instrumentation does `INSERT ztevent_log` and `COMMIT WORK AND WAIT`,
both forbidden while a behaviour implementation is active. Section 50.

Not a worklist defect - Submit from the cockpit app dumps the same way.

## Pull and activate

    ZCL_INSTRU_EVENT_CLASS       class  (gv_defer, flush, discard)
    ZBP_CDS_INT_EINV_DOC         class  (sets gv_defer; flush in the saver)

Activate the instrumentation class first, then the behaviour pool.

## Then

Tick a row and press Submit again. Expect the action to run through to
the platform call. The event-log rows now appear only once the LUW
commits, which is after the action returns - not during it.

## Known consequence

A rolled-back LUW loses its event-log rows; the HANA version committed
them immediately and kept the diagnostics of a failed call. See the end
of section 50.

## Five bindings: superseded (28/10/2026)

This section told you to Publish Locally on `ZSB_EDOC_AP`,
`ZSB_EDOC_APFLAT`, `ZSB_EDOC_SB`, `ZSB_EDOC_SBFLAT` and
`ZSB_EINV_CONFIG`. **Done** - all five show `PUBLISHED=true` in the
28/10 push.

It also said the checker's fifteen problems were correct. Ten of them
were not; see section 74. Five remain and are accurate: abapGit still
does not serialise those five inbound services, so a system rebuilt from
this repository needs one Publish Locally per binding. F3Y itself is
complete. The top of this file has the detail.

## e-Invoice command endpoint (added 10/10/2026)

The submit path was calling `ZCL_ELT~get_command`, which polls for any
queued command and cannot name a document. The HANA trigger called
`get_command_einvoice`, which posts the document to a different endpoint.
That method never reached ZZCLR_ELT. Sections 52 and 53.

### Pull and activate

    ZCL_EINV_ELT_COMMAND   class  (NEW - reimplements get_command_einvoice)
    ZCL_EINV_SUBMIT        class  (now calls it)

ZCL_EINV_ELT_COMMAND first.

### Configure before testing

Two rows in ZTELT_CONFIG, for this SYSID:

    LABELTYPE = GET_COMMAND_EINV    LOW = <e-invoice command path>
    LABELTYPE = PRESIGN_URL_EINV    LOW = <e-invoice upload target>

Take both values from the HANA system's /CLR/ZTELT_CONFIG. Without
GET_COMMAND_EINV the submit fails with
`API to get command not maintained in custom table`.

### What to expect

Submit now posts the document and should come back with a command whose
`command` is DATA_EXTRACTION. If it does, the command half is proven.

The ingestion that follows still uses the generic ELT endpoint. When
PRESIGN_URL_EINV is maintained the result message says so explicitly -
that message is expected, not a defect, and marks the remaining gap.

## Submit now reaches the platform (10/10/2026)

`get_command_einvoice` works: the platform returns a DATA_EXTRACTION
command for the submitted document, carrying an I_BILLINGDOCUMENT /
I_BILLINGDOCUMENTITEM schema.

The run then dumps with `OBJECTS_TABLES_NOT_COMPATIBLE` in
`ZCL_ELT~STORE_TABLE_DATA` - inherited ZZCLR_ELT code, not this package.
The ELT conversion dropped `/CLR/ZCL_ALV_TABLE_CREATE_RTTC` and replaced
it with inline `cl_abap_structdescr=>create`, so two dynamic tables that
used to be built by one helper are now built independently and are no
longer compatible. Section 54 has the analysis and a candidate fix.

**This needs the owners of ZZCLR_ELT.** Send them section 54 and the
dump. Nothing in ZZCLR_GEINV will fix it.

# ELT execute command: Sequence and Einvoice (28/10/2026)

`ZCL_ELT_EXEC_COMMAND_JOB~get_parameters` was empty, so the cloud job had
no selection fields at all. Both of the HANA report's are now declared,
and one of them turned out to be covering a real defect. Sections 76, 77.

## Objects to pull

    ZCL_ELT                        class           (changed - iv_seq)
    ZCL_ELT_EXEC_COMMAND_JOB       class           (changed)
    ZCL_EINV_ELT_EXEC_JOB          class           (changed)
    ZCL_EINV_ELT_POSTING           class           (changed - iv_einvoice)
    ZCL_EINV_SUBMIT                class           (changed - iv_seq)
    ZAJC_ELT_EXECUTE_COMMAND       job catalog     (changed - declares the
                                                   four parameters)
    ZAJT_ELT_EXECUTE_COMMAND       job template    (changed)
    ZAJT_ELT_EXECUTE_COMMAND_1     job template    (changed - P_EINV = 'X')

Order matters twice over: activate `ZCL_ELT` first because the other
classes reference its new constructor parameter, and activate the **job
catalog entry before the two templates**. A template that sets a parameter
its catalog entry has not yet declared is rejected with *"Hidden parameter
'P_EINV' should not be used in template"* - section 78.

## The job's parameters

    e-Invoice Posting       P_EINV    skip the generic insert_table( );
                                      in practice, "this is the posting run"
    Sequence                P_SEQ     which ZTELT_CONFIG profile to read
    Max Runtime, e-Inv (s)  P_MAXSEC  900
    Get Command Retries     P_RETRY   3

Schedule from **ZAJT_ELT_EXECUTE_COMMAND_1** for e-invoice posting
(`P_EINV = 'X'` preset) and from **ZAJT_ELT_EXECUTE_COMMAND** for
extraction. **Do not let the two overlap** - both poll the same command
queue, and the extraction path discards a `DATA_POSTING` command it picks
up. HANA guarded this with `BP_FIND_JOBS_WITH_PROGRAM`, which has no
released equivalent, so the guard is operational here.

## Check this before the first run

`ZCL_ELT~get_erp_config` was reading `ZTELT_CONFIG` without the
`SEQUENCE` key, so it returned every profile for the system and used
whichever row came back first. The filter is restored but applied only
when a sequence is supplied, so nothing changes until you set the field.

**Look at what is actually maintained:**

    SELECT projectid, sysid, labeltype, sequence, low FROM ztelt_config

If every row carries one sequence value, set `P_SEQ` on both templates to
that value, confirm a run, and then make the filter unconditional (drop
the `IF gv_seq IS INITIAL` branch in `get_erp_config`). If rows exist
under more than one sequence, the current jobs have been reading an
arbitrary one - which is worth knowing regardless.

## Still open for the ZZCLR_ELT owners

- `ZCL_ELT~elt_exec_command` calls `elt_ingestion` for every command with
  an id, whatever the verb.
- `ZCL_ELT~trigger_posting` calls `insert_table( )` unconditionally - the
  `IF iv_einvoice IS INITIAL` guard was dropped, so an e-invoice command
  reaching it writes every row twice.
- No `PARALLEL_RUN` guard.


# Government status on the AR dashboard (28/10/2026)

`PA_EXCHG_STAT` / `PA_EXCHG_RESCODE` / `PA_EXCHG_RESMSG` of
`ZTEINV_SALES_ST` as their own dashboard columns, instead of only folded
into `EffectiveStatus`. Section 79.

## Objects to pull

    ZCDS_INT_EINV_LIVE         CDS view entity        (changed)
    ZCDS_CUN_EINV_WORKLIST     CDS view entity        (changed)
    ZCDS_MET_EINV_WORKLIST     metadata extension     (changed)

Activate in that order - each builds on the one above. No behaviour
definition, no table, no service change: the association to
`ZTEINV_SALES_ST` was already there, the fields were simply not exposed.

## What you will see

Three new columns after Message: **Government Status** (coloured),
**Government Message**, **Gov. Resp. Code**. Government Status is also a
filter, so "everything the authority rejected" becomes a selection.

They will be **blank on every row** until a `DATA_POSTING` command is
processed - `ZTEINV_SALES_ST` has no rows in client 100 today. Blank is
shown neutral, not red: the authority has not reported, which is not a
rejection. Schedule the e-invoice posting job (sections 76-78) and the
columns fill themselves.

# Refresh Status no longer erases the status (28/10/2026)

`ZCL_EINV_API_CLIENT~get_status` returns an empty status on a transport
error, an empty body or a non-200 response, and `refreshstatus` wrote it
unconditionally - so one failed call blanked the Status column for every
selected row. HANA guarded the same write three times over. Section 80.

## Objects to pull

    ZBP_CDS_INT_EINV_DOC       behaviour pool class   (locals_imp changed)

One object. No view, no table, no behaviour definition.

## How to confirm

Select `1400000000`, press **Refresh Status**.

* Platform reachable: Status updates as before.
* Platform unreachable or erroring: Status is **left alone** and a warning
  appears - *"Status not refreshed: <reason>"* - carrying the platform's
  own text or the HTTP code.

Before this fix the second case silently blanked the column, which is
what the 28/10 screenshot shows for `1400000000`.

Its stored status is already blank, so it stays blank until a refresh
succeeds or the posting job writes `ZTEINV_SALES_ST`.

# Government reporting history (28/10/2026)

The new HANA `call_get_status` + `save_ppf_details` + `/CLR/ZT_EINV_PPF`,
ported. Section 81.

## Objects to pull - DDIC first, in this order

    ZDO_EINV_PPF_TRANS         domain            NEW
    ZDO_EINV_PPF_ACT           domain            NEW
    ZDO_EINV_PPF_RSNTXT        domain            NEW
    ZDE_EINV_PPF_TRANS         data element      NEW
    ZDE_EINV_PPF_ACT           data element      NEW
    ZDE_EINV_PPF_ACTTYP        data element      NEW
    ZDE_EINV_PPF_RSNTXT        data element      NEW
    ZTEINV_PPF                 table             NEW
    ZTEINV_DOC                 table             (+3 fields)

    ZCDS_INT_EINV_PPF          CDS view entity   NEW
    ZCDS_INT_EINV_DOC          CDS view entity   (composition + 3 fields)
    ZCDS_INT_EINV_DOC          behaviour def     (child behaviour + mapping)
    ZCDS_INT_EINV_LIVE         CDS view entity
    ZCDS_CUN_EINV_PPF          CDS view entity   NEW
    ZCDS_CUN_EINV_DOC          CDS view entity   (redirect + 3 fields)
    ZCDS_CUN_EINV_DOC          behaviour def     (use association + behaviour)
    ZCDS_CUN_EINV_WORKLIST     CDS view entity
    ZCDS_MET_EINV_PPF          metadata ext      NEW
    ZCDS_MET_EINV_DOC          metadata ext      (Government Reporting tab)
    ZCDS_MET_EINV_WORKLIST     metadata ext

    ZCL_EINV_API_CLIENT        class             (2nd parse, iso_ts_split)
    ZBP_CDS_INT_EINV_DOC       behaviour pool    (locals_imp)

The DDIC block must activate before the CDS block, and
`ZCDS_INT_EINV_DOC`'s behaviour definition before the projection's -
section 72, which is the same ordering that bit `ZCDS_INT_EINV_ZIP`.

Remember the behaviour definition is a separate abapGit object from the
CDS view of the same name. Pull both.

## What you will see

* Object page: a **Government Reporting** tab, newest entry first, with
  status, action, action type, reason code and reason text. Government
  Status, PPF Status and PPF Action join the header fields.
* Dashboard: **Government Status** now shows the PPF status when there is
  one and falls back to `PA_EXCHG_STAT`. **Government Action** is a new
  column.

Both fill the next time Refresh Status is pressed on a document whose
response carries a `GovtReportingDetails` block. Nothing is backfilled.

## Worth checking on the first run

Open the Government Reporting tab after a refresh and compare the row
count against the response: one row per reason, plus one row per entry
that had no reasons. If an entry is missing entirely, the `RSNNO = 000`
branch is the place to look.

# After pulling sections 79-81 (29/10/2026)

## One more ABAP object

    ZSD_EINV_DOC               service definition   expose ZCDS_CUN_EINV_PPF

Missed in the section 81 drop. Without it the Government Reporting tab
has no entity behind it, even though everything else activates. Activate
the service definition; `ZSB_EINV_DOC` picks the entity up from it. If
the entity set still does not appear in the metadata, Publish Locally on
the binding once. Section 82.

## In BAS: nothing structural

`ZSB_EINV_DOC` is OData V2, and a V2 Fiori Elements app builds its
columns and facets from the service metadata at runtime. The new
dashboard columns and the Government Reporting tab appear on their own.

If they do not appear:

1. **Refresh the metadata cache.** `/IWFND/CACHE_CLEANUP` is not
   available in Public Cloud - use the app's own cache-buster: hard
   reload (Ctrl+Shift+R), or append `?sap-ui-xx-componentPreload=off` once
   to rule the browser cache out.
2. **Check the saved variant.** A variant saved before the change keeps
   the old column set. Open the view settings and add the columns, or
   switch to Standard.
3. **Check the entity is in the metadata.** Open
   `<service-url>/$metadata` and search for `EInvoicePpf`. Absent means
   step 1 of the previous section was not done.

## Still outstanding in BAS, unrelated

`multiSelect` and the Select All / Deselect All controller extension -
see `ui/worklist/README.md`. Those are real UI concerns and still need
doing.

# Auth header corrected (29/10/2026)

`ZCL_EINV_API_CLIENT` was sending `x-clear-auth-token` to the e-invoice
API, which wants `x-cleartax-auth-token`. Every call this class makes was
affected: status, printout, seller action, cancel, and the AP calls.
Section 83.

## Objects to pull

    ZCL_EINV_API_CLIENT        class

One object.

## Config to confirm before testing Refresh Status

Checked against the working cURL for
`/einvoice/v1/documents/{id}/status?EInvoiceType=SALES`:

1. **ZTELT_CONFIG** - `AUTH` row for `AE10` / `F3Y`. Present in your
   screenshot. The token is read by `PROJECTID` + `SYSID`, not by
   sequence, so keep one `AUTH` row per project/system (see the end of
   section 83).
2. **e-Invoice API Endpoints** (`ZTEINV_API`) - a row with
   `FUNCTIONALITY = EINV_STATUS` whose URL carries both placeholders:
   `.../einvoice/v1/documents/&1/status?EInvoiceType=&2`. `&1` is the
   Clear document id, `&2` the transaction type.
3. **API_PARAMETER rows** - `x-clear-country-code` and `x-clear-trn` for
   `AE` / `AE10`. Your screenshot shows four `API_PARAMETER` rows; those
   two must be among them with the TRN `100375173000003`.
4. **ZTEINV_DOCTYP** - `TRANSACT_TYPE = SALES` for country `AE`, doc type
   `380`. This is what becomes `EInvoiceType=SALES` in the URL. If it is
   blank the query parameter goes out empty and the platform rejects the
   call.

## Then

Select `1400000000` and press **Refresh Status**. With section 80 in
place, a failure now leaves the stored status alone and reports the
platform's own text, so a wrong header or a missing config row says so
instead of silently blanking the column.

# Seller Action error rows restored (29/10/2026)

`call_seller_action` writes `/CLR/ZT_EINV_ERR` on rejection and deletes it
on success. The conversion kept only the delete, so a rejected seller
action left the API Errors tab empty. Section 84.

## Objects to pull

    ZBP_CDS_INT_EINV_DOC       behaviour pool    (locals_imp)

Same object as section 80 - pull it again if you already have that one.

## Where the three tabs get their data

    Exchange Status        ZTEINV_SALES_ST    DATA_POSTING background job
    API Errors             ZTEINV_ERR         Refresh Status; Seller Action on rejection
    Government Reporting   ZTEINV_PPF         Refresh Status

Exchange Status is the one no button fills. It needs
`ZAJT_ELT_EXECUTE_COMMAND_1` scheduled and a `DATA_POSTING` command to
arrive for the document.

# Status F4: nothing to pull (02/11/2026)

An earlier entry here said to pull `ZVH_EINV_STATUS` for a text-element
fix. **Withdrawn** - the change was reverted and the view is identical to
your tenant copy again.

`ZTEINV_STATTX` corresponds to `/CLR/YT_STATUS`, which is dead in HANA:
maintenance function group only, and the transaction call that would open
it is commented out. The public cloud copy stays empty and unread to
match. The Status filter still accepts typed input; it just offers no F4
list. Section 86.

# Status criticality: the CASE is now the configuration (02/11/2026)

`ZTEINV_STATUS` was maintained with 10 rows and read by nobody - its
reader chain ends at a virtual-element class no view references. The
dashboard colour comes from a CASE in the views, which knew only 8
statuses, so 7 of your 10 showed neutral grey. Section 87.

## Objects to pull

    ZCDS_INT_EINV_DOC_ENR      CDS view entity
    ZCDS_INT_EINV_LIVE         CDS view entity
    ZCDS_INT_EINV_PPF          CDS view entity

Three views, one unified status list in four expressions.

## Confirm before deleting the 10 rows

The new list:

    3  VALID  SUCCESS  COMPLETED  COLLECTED  ACCEPTED  DELIVERED TO BUYER
    2  SUBMITTED  PENDING  RECEIVED  DELIVERED TO BUYER NETWORK
    1  ERROR  FAILURE  INVALID  REJECTED  CANCELLED
    0  anything else, including blank

`DELIVERED TO BUYER = 3` is taken from your Status Mapping detail screen.
The rest are read from the words. **Open the 10 rows and compare the
Criticality column against this list before deleting them** - especially
`DELIVERED TO BUYER NETWORK` and `Received`, where "in progress" versus
"done" is a judgement call, and the two rows not visible in the list
screenshot.

Adding a status later is now a change to three views plus a transport,
not a config row. That is the cost of the decision, and checker rule 67
fails if the four expressions fall out of step.

## If the Status Mapping app is to go for good

A pull does not delete (section 44), so these have to be deleted by hand
in ADT, in this order:

    ZIAM_EINV_STATUS*          IAM app / business catalog assignment
    ZSB_EINV_CONFIG            remove the ZCDS_CUN_EINV_STATUS expose line,
    ZSD_EINV_CONFIG            then Publish Locally again
    ZBP_CDS_CUN_EINV_STATUS    behaviour pool
    ZCDS_CUN_EINV_STATUS       projection + behaviour definition
    ZCDS_INT_EINV_STATUS       interface view + behaviour definition
    ZTEINV_STATUS              table
    ZCL_EINV_VE_CRITICALITY    virtual element class (dead)

`ZCL_EINV_CONFIG~get_criticality` and `ZIF_EINV_COUNTRY~map_criticality`
can stay - they are harmless and the interface method is part of the
country-handler contract - but nothing calls them.

Not urgent. An unread table costs nothing but the confusion of being
maintainable, which this section now answers.

# Five config tables as tabs on ELT Config Details (02/11/2026)

Three more tabs on the ELT Config Details object page, following the
pattern ELT Config and Instrumentation Config already use. Section 89.

## Objects to pull - new

    ZCDS_CUN_COMP_CNTRY        CDS view entity        NEW
    ZCDS_CUN_COMP_VAT          CDS view entity        NEW
    ZCDS_CUN_COMP_API          CDS view entity        NEW
    ZCDS_CUN_COMP_INVMAP       CDS view entity        NEW
    ZCDS_CUN_COMP_DOCTYP       CDS view entity        NEW
    ZCDS_MET_COMP_CNTRY        metadata extension     NEW
    ZCDS_MET_COMP_VAT          metadata extension     NEW
    ZCDS_MET_COMP_API          metadata extension     NEW
    ZCDS_MET_COMP_INVMAP       metadata extension     NEW
    ZCDS_MET_COMP_DOCTYP       metadata extension     NEW

## Objects to pull - changed

    ZCDS_CUN_COMP_DETAILS      CDS view entity        (5 compositions)
    ZCDS_CUN_COMP_DETAILS      behaviour definition   (5 children)
    ZCDS_MET_COMP_DETAILS      metadata extension     (5 facets)
    ZSD_ELT_CONFIG             service definition     (5 expose lines)

## Activation order

1. The five `ZCDS_CUN_COMP_*` views.
2. `ZCDS_CUN_COMP_DETAILS` the view, then its behaviour definition -
   the composition has to exist before the behaviour that declares the
   children.
3. The six metadata extensions.
4. `ZSD_ELT_CONFIG`. If the new entity sets do not show in `$metadata`,
   Publish Locally on `ZSB_ELT_CONFIG` once - section 82.

Remember the behaviour definition is a separate abapGit object from the
CDS view of the same name.

## What you get

Eight tabs: Company Details, ELT Config, Instrumentation Config, Country
Registration, VAT Registration, API Endpoints, Relevance Mapping,
Document Types - the whole of the e-invoice customizing behind one
Project ID. Rows are creatable, editable and deletable from the page,
same as the existing two tabs.

The five standalone apps stay exactly as they are - they use their own
consumption views and were not touched.

## One thing to know

Each of the five tables now has two managed BOs writing it - the
standalone app's and this tab's. Their lock masters do not see each
other, so the same row edited in both apps at once is last-writer-wins
instead of "locked by another user". `ZTELT_CONFIG` has been in that
position since the ELT Config tab was built. Retiring the standalone apps
is what removes it, if it ever matters.
