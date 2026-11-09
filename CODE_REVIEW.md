# Code review of ZZCLR_GEINV — findings and fixes

Three independent review passes over `src/`: one on the RAP behaviour
definitions and handlers, one on the CDS layer, one on the hand-written ABAP
for syntax and ABAP-Cloud compliance. A fourth pass verified the fixes for
regressions.

Every finding below was confirmed against the actual file before anything was
changed. Findings that turned out not to be real are recorded at the end, so
the same ground is not re-covered later.

Fixes to generated objects were made in the **generator scripts** under `gen/`
and regenerated — not hand-edited in `src/`. Nine new rules were added to
`gen/check.py` so each defect class is caught mechanically from now on; every
rule was self-tested by deliberately re-introducing the defect.

---

## 1. Would not have activated

### 1.1 Every amount on the item tables pointed at a non-currency field

`ZTEINV_APITEM` and `ZTEINV_ARITEM` had all 22 `CURR` columns referencing
`INV_CURR` as their currency field. `INV_CURR` is typed `BP_CURR` in the HANA
original — an **amount**, despite the name. DDIC requires the reference field
of a `CURR` column to be `CUKY`, so neither table would have been created.

The same mistake reached the CDS layer as 44 `@Semantics.amount.currencyCode:
'InvoiceCurrency'` annotations, one of which annotated the field against
itself.

**Fixed.** The only real `CUKY` on the item tables is `PRICE_CURR`; all item
amounts now reference it. Amounts that have a currency of their own
(`INV_VAT_AMOUNT`, `PAY_TERMS_AMOUNT`, `PREPAID_PAID_AMT`,
`ALLOW_CHRG_BASE_AMT_F/T`) reference that instead, and `PRICE_BASE_QUANTITY`
now references `PRICE_BASE_UNITCODE` rather than `ITEM_UNIT_CODE`. The CDS
element for `INV_CURR` is renamed `InvoiceCurrencyAmount` so the name can no
longer invite the same error.

`gen_edoc.py` now asserts that a currency reference is `CUKY` and a unit
reference is `UNIT` before writing the table; `gen_edoc_rap.py` asserts that no
`@Semantics` annotation is a self-reference. Checker rules 12 and 13.

### 1.2 Six calculated elements on the root view of a managed business object

`ZCDS_INT_EINV_DOC` carried `EffectiveStatus`, `EffectiveMessage`,
`TransactionCurrency`, `IsReversed`, `IsReversal` and
`BillingCancellationStatus` — a `coalesce` over the exchange/async status and
four fields read through associations to `I_JournalEntry` and
`I_BillingDocument`.

A managed business object maps every element of its root view onto a column of
its persistent table; elements not named in the `mapping for` block are mapped
implicitly by name. None of these six has a column in `ZTEINV_DOC`.

**Fixed by layering, not by annotation.** The calculation moved to a new
read-only view `ZCDS_INT_EINV_DOC_ENR`, reached from the root view through a
`[1..1]` association `_Enrich`. The root view is now 1:1 with `ZTEINV_DOC`. The
consumption view exposes the six as path expressions (`_Enrich.EffectiveStatus
as EffectiveStatus`), which keeps them filterable and sortable —
`EffectiveStatus` is a `@UI.selectionField`, so a virtual element would not
have worked. The behaviour implementation reads them with a new helper,
`read_enrichment( )`.

### 1.3 A method with both RETURNING and EXPORTING

`ZCL_EINV_API_CLIENT~get_document_list` was declared with
`RETURNING VALUE(rs_result)` **and** `EXPORTING VALUE(et_docs)`. ABAP permits
`RETURNING` only when a method has no `EXPORTING` and no `CHANGING` parameters,
so the class would not activate — and with it the four job classes,
`ZCL_EINV_EDOC_ACTION` and `ZCL_EINV_EDOC_FETCH`.

**Fixed.** The document list is now a `docs` component of the result
structure; the single call site in `ZCL_EINV_EDOC_FETCH` was rewritten to match.

### 1.4 The additional-save class was in a file abapGit ignores

`zbp_cds_int_einv_doc.clas.locals_saver_imp.abap`. abapGit's class serializer
reads exactly four local includes: `locals_def`, `locals_imp`, `macros`,
`testclasses`. Anything else is silently skipped on pull, so `LSC_ZCDS_INT_EINV_DOC`
would never arrive in the tenant and `with additional save` would fail
activation with no clue as to why.

**Fixed.** The saver class now lives at the end of `locals_imp.abap` and the
separate file is gone. Checker rule 18.

### 1.5 Ten configuration views missing the transactional contract

`ZCDS_CUN_EINV_ACTION`, `_API`, `_CNTRY`, `_CONST`, `_DOCTYP`, `_INVMAP`,
`_REASON`, `_STATTX`, `_STATUS`, `_VAT` each had a projection behaviour
definition but no `provider contract transactional_query`. The BDEF cannot bind
to the view without it.

**Fixed** in `gen_config_rap.py`. Checker rule 14.

---

## 2. Would have activated, then not worked

### 2.1 Three business objects denied every operation

`get_instance_authorizations` was an empty stub in the handlers for
`ZCDS_INT_EINV_APHEAD`, `ZCDS_INT_EINV_SELFHEAD` and all ten configuration BOs,
while their behaviour definitions declared `authorization master ( instance )`.
An instance-authorization handler that returns an empty `RESULT` denies every
operation on every row. The AP cockpit, the self-billed cockpit and the whole
configuration app would have activated and then refused all access.

**Fixed.** Every handler now fills `RESULT`, with a comment naming where a
company-code restriction belongs once an IAM restriction field exists.
Checker rule 15.

Related: `authorization master ( instance )` alone does not cover `create` or a
static action, neither of which has an instance. Every business object that
declares `create;` — the ten configuration BOs and the sales e-invoice BO —
now declares `authorization master ( instance, global )` and implements
`get_global_authorizations`.

### 2.2 The background jobs could not write back, and would have resubmitted forever

`ZCL_EINV_SUBMIT_JOB`, `ZCL_EINV_STATUS_JOB`, `ZCL_EINV_PICKUP_JOB` and
`ZCL_EINV_AUTO_TRIGGER` each called the platform directly and then wrote the
outcome back with `MODIFY ENTITIES` **without** `IN LOCAL MODE`. An external EML
write is subject to the static field control of the behaviour definition, and
`SyncStatus`, `ErrorText`, `CommandId` and `IsSent` are all
`field ( readonly )` there. The writes would have been rejected.

Worse, none of the four read `FAILED`, so the rejection was silent. Because
`select_pending` selects on `invid = '' OR error <> ''`, the same documents
would have been picked up and submitted to the platform again on every run.

**Fixed.** All four now execute the business object's own action
(`EXECUTE SubmitEInvoice` / `EXECUTE RefreshStatus`) instead of re-implementing
it. The handler already does the work in local mode, so field control is not in
the way, the eligibility rules are applied once rather than twice, and the error
detail rows of `RefreshStatus` are written — which the jobs previously skipped
entirely. All four now read `FAILED` and `REPORTED`, roll back the document on
failure and record the message in the job log.

### 2.3 `PickUpDocuments` returned unaddressable rows

The static action built its `RESULT` with `%cid`. A `TABLE FOR ACTION RESULT`
has no `%cid` component — it has `%cid_ref`, `%key`/`%tky` and `%param` — and
the rows were filled from the pre-save snapshot rather than from the created
instances.

**Fixed.** The action keeps a map from each created instance's `%cid` back to
the action row's `%cid`, reads the created rows back after the `CREATE`, and
returns `%cid_ref` + the persisted `%param`. The same map translates the
`FAILED`/`REPORTED` rows of the inner `CREATE`, so a failure is reported under
a `%cid` the caller actually sent.

### 2.4 `RefreshStatus` hit a duplicate key on the second refresh

`ERRORNO` is part of the key of `ZTEINV_ERR`, and the action numbered each
refresh's error details 1..n without removing the previous refresh's rows. The
second refresh of any document with errors would have failed on a duplicate key.

**Fixed.** The existing `_Error` children are deleted first, then the new ones
are numbered from scratch. The content id also carries the company code and
fiscal year so it cannot collide across documents in one request.

### 2.5 Fan-out from the relevance join reached the worklist

`ZCDS_INT_EINV_REL_JRNL` joins `ZTEINV_INVMAP` on `BLART + BUKRS` only, while
the table's key is eight fields. One journal entry therefore matches every
mapping row configured for that company code and document type. The view
declared a three-field key it does not have, and the duplicates propagated into
`ZCDS_INT_EINV_RELEVANT` and the pick-up — where `ZTEINV_DOC`, keyed on
`(VBELN, BELNR, BUKRS, GJAHR)`, would have taken a duplicate key.

The HANA original had `SELECT DISTINCT` for the same reason.

**Fixed.** Both views now declare the mapping columns as part of their key, so
the cardinality is honest. `select_relevant` uses `SELECT DISTINCT` and then
collapses to one row per document, which is what `consolidate_data`'s
`READ TABLE gt_invmap ... WITH KEY` did. `filter_existing` guards against
duplicates within a batch as well as against rows already on the database.

### 2.6 The pick-up selection could never match a fiscal year

`@iv_gjahr = ''` in `ZCL_EINV_WORKLIST~select_relevant` and
`ZCL_EINV_AUTO_TRIGGER`. `ZDE_EINV_GJAHR` is `NUMC(4)`, whose initial value is
`'0000'`, not blank — so the "no fiscal year supplied" escape hatch was always
false and the filter collapsed to `FiscalYear = '0000'`, which matches nothing.

`ZCL_EINV_PICKUP_JOB` does not pass a fiscal year at all, so the background
pick-up would have found zero documents on every run. The same applied to any
interactive pick-up that left the field empty, and to the auto-trigger's
billing-document-only path.

**Fixed** in both places. The two date guards in the same statement were already
written against the real initial value (`'00000000'`); fiscal year was the one
that was not.

### 2.7 The printout could never be retrieved

`execute( )` is shared by all six endpoints and read the response body as text
before reading it as binary. `get_text( )` character-converts using the response
content type; on the `application/pdf` bytes that `get_printout` receives it
raises `cx_web_message_error`, which the `CATCH` turned into a call failure.
`body_raw` was never filled.

**Fixed.** The binary is read first, and the text only when the content type is
JSON, text or XML.

### 2.8 A retired ICF pseudo-header was being sent on the wire

`build_headers` still emitted `~request_method`. That was a `cl_http_client`
convention; `cl_web_http_client` puts whatever `set_header_fields( )` is given
on the wire verbatim, so every request to the platform carried a literal
`~request_method:` header. The verb is already set by the argument of
`execute( )`.

**Fixed** — the entry and the now-unused parameter are gone.

### 2.9 The configurable cancellation window was unreachable

`zif_einv_country~check_cancel_allowed` took no company code, so the
implementation looked `CANCEL_WINDOW_H` up with a blank one. `get_constants`
derives the country from the company code, so a blank one resolves to a blank
country and matches no `ZTEINV_CONST` row: the hard-coded 72 hours always won.
Separately, `CO ' 0123456789'` accepted an all-blank value, and `CONV i( '  ' )`
is 0 — a zero-hour window that would block every cancellation.

**Fixed.** `iv_bukrs` was added to the interface method (every other hook on
that interface already had it) and to the caller, and the value test now
rejects blank and zero.

### 2.10 Each cockpit offered the other one's action types

`ZVH_EINV_ACTIONTYPE` groups `EINV_TYPE` away. That key field exists in
`/CLR/YT_ACTION` precisely so that the AP cockpit and the self-billed cockpit
have different action lists — the HANA code selected
`WHERE einv_type = 'PURCHASE'` and `= 'SELF_BILLED'` respectively.

**Fixed.** Two filtered value helps, `ZVH_EINV_ACTTYPE_AP` and
`ZVH_EINV_ACTTYPE_SELF`, and one action-parameter entity per variant
(`ZCDS_ABS_EINV_APACT`, `ZCDS_ABS_EINV_SELFACT`) replacing the shared
`ZCDS_ABS_EINV_EDOCACT`. Each service definition exposes its own.

### 2.11 The cancellation dialog offered action types as reason codes

`ZCDS_ABS_EINV_CANCEL.ReasonCode` carried
`ZVH_EINV_ACTIONTYPE / element: 'ActionType'` — wrong value help and an element
the entity does not have. Copy-paste from the seller-action entity.

**Fixed** to `ZVH_EINV_REASONCODE / ReasonCode`, which is now also exposed by
`ZSD_EINV_DOC`.

### 2.12 The seller action offered the whole configuration table

The sales cockpit never read `/CLR/YT_ACTION`. Dynpro 0200 hard-coded two
values in `MODULE status_0200` via `VRM_SET_VALUES`: `COMPLETE` and
`CONFIRM_PAYMENT`.

**Fixed** with a new fixed-value domain `ZDO_EINV_SELLER_ACT` carrying exactly
those two, which Fiori renders as the same two-entry dropdown with no
customizing dependency.

### 2.13 The item table on the object page was empty

The header's `#LINEITEM_REFERENCE` facet targets `_Item`, and a line-item facet
renders whatever the **target** entity annotates as `@UI.lineItem`. There was no
metadata extension for the item consumption views, so the table had no columns.

**Fixed.** `ZCDS_MET_EINV_APITEM` and `ZCDS_MET_EINV_SELFITEM` are generated.

### 2.14 Inner EML results were declared and discarded

About ten sites captured `REPORTED DATA(ls_rep)` from a nested `MODIFY ENTITIES`
and never merged it into the handler's own `reported`/`failed`. A rejected write
looked to the caller like a successful action.

**Fixed** everywhere, in the hand-written handler and in the generated ones.

### 2.15 Dead operations and unguarded reads

- `delete;` was declared on the sales BO and then hard-denied in
  `get_instance_authorizations`, and `create;`/`delete;` were exposed on the
  projection. Removed: rows are materialised by `PickUpDocuments` and reversed
  documents are marked, never deleted — that is the audit trail the HANA
  cockpit lost when it dropped cancelled rows from the ALV.
- `get_instance_authorizations` set `%action-…` components. Those exist only
  for actions declared `( authorization : instance )`, and none is. Removed.
  Checker rule 19.
- `use association _Document` on the two child projections, with no matching
  declaration in the base. Removed. Checker rule 17.
- `SellerAction` and `CancelEInvoice` used the result of an `OPTIONAL` table
  read without checking it was found; a key the read did not return would have
  been sent to the platform as an all-initial document. Both now check and
  report. So does `SendAction` on the AP and self-billed BOs.
- `SubmitImmediately` on `ZCDS_ABS_EINV_PICKUP` was never read — the same dead
  parameter `P_SUBM` was on the HANA selection screen. It now does what its
  label says: the freshly created rows go straight into `SubmitEInvoice`.
- Key fields appeared in unconditional `field ( readonly )` lists. That also
  blocks them on `CREATE`, so `PickUpDocuments` would have inserted rows with
  empty keys. Keys are read-only for update in RAP by definition and are no
  longer listed. Checker rule 16.
- The `PDF` staging buffer is `CLASS-DATA` and was cleared only on a successful
  save, so a rolled-back printout kept the bytes in the session and the next
  save would have written them under the wrong document. `cleanup_finalize` now
  discards it.
- `ZCL_EINV_CONFIG~invalidate( )` existed but had no caller. The submission and
  status jobs now call it at the start of every run.
- `get_endpoint` applied no company-code filter to the `API_PARAMETER` header
  rows, so every row for the country was sent regardless of which company code
  it was maintained for. It now uses the same company-code-then-country
  fallback as the URL lookup beside it.

---

## 3. Reported but not defects

- **`ZCL_EINV_PDF_STORE`'s `CLASS-DATA` buffer** is the right design for a
  save-phase flush; only the missing cleanup was a bug (2.15).
- **`coalesce` over a to-one association** is legal CDS, and the operand types
  do match (all `CHAR 40` / `CHAR 250`). The problem with those six elements was
  where they sat, not how they were written (1.2).
- **`association _Item { create; }` on a parent whose child declares only
  `update;`** is the standard RAP pattern — the `create` inside the association
  block is what enables creation through the parent.
- **`/ui2/cl_json`** is used 12 times. The already-deployed `ZCL_ELT` in
  `ZZCLR_ELT` uses it identically, so if it activates there it activates here.
  Worth one ATC run with the cloud-readiness variant all the same.

---

## 4. Left open deliberately

- **`ct_calculated_data = CORRESPONDING #( … )`** in the two virtual-element
  classes, against the generically typed `CHANGING` parameter of
  `if_sadl_exit_calc_element_read~calculate`. This is SAP's own published
  pattern, but it is the one construct in the package that a syntax check would
  settle faster than reading can. Check it first in ADT.
- **The reversal guard is skipped on the straight-through path.**
  `SubmitEInvoice` reads `IsReversed` / `BillingCancellationStatus` from
  `ZCDS_INT_EINV_DOC_ENR`, which reads the database. When `PickUpDocuments`
  submits immediately, the row it just created is still in the transactional
  buffer, so the guard finds nothing and passes. The documents were selected as
  relevant moments earlier, so the window is small, but it is a window.
- Everything in §11.6 of `CONVERSION_DESIGN.md` is unchanged: the UBL detail
  mapping, the `ZZCLR_ELT` country parameter, the three dead fields on
  `ZTEINV_SALES_ST`, and the self-billed ↔ sales-status link.

---

## 5. Checker rules added

`gen/check.py` and `gen/check_merged.py` grew nine rules, each self-tested by
re-introducing the defect it is meant to catch:

| # | Catches |
|---|---|
| 12 | a `CURR` column whose reference field is not `CUKY`, or a `QUAN` whose reference is not `UNIT` |
| 13 | a `@Semantics` annotation naming itself, or an element the view does not have |
| 14 | a projection behaviour definition over a view with no `provider contract transactional_query` |
| 15 | `get_instance_authorizations` that never fills `RESULT` |
| 16 | a key field in an unconditional `field ( readonly )` list |
| 17 | `use create` / `use delete` / `use association` with nothing matching in the base behaviour |
| 18 | a class local include abapGit will ignore on pull |
| 19 | `%action-…` in an authorization handler for an action without `( authorization : instance )` |
| 20 | a message number used in ABAP that does not exist in `ZEINV_MSG` |

The merged checker routes findings in files inherited verbatim from `ZZCLR_ELT`
into an advisory list rather than failing the build. There are currently 53 of
them, in code that activates in the customer tenant today — the largest groups
are empty `get_instance_authorizations` handlers and readonly key fields, the
same two defects as 2.1 and 2.15. They are listed for visibility; fixing them
is a separate decision about someone else's package.
