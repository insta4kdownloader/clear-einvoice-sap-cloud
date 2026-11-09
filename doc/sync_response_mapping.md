# Synchronous upload response → ZTEINV_DOC / ZTEINV_SALES_ST / ZTEINV_ERR

The body returned by the e-invoice upload endpoint (`PRESIGN_URL_EINV`,
`.../one-integration/sync/EINVOICE_GLOBAL`) and what each field becomes in
the Public Cloud tables.

---

## Read this first: it is not the format the code expects

`ZCL_EINV_ELT_INGEST~parse_writeback` (section 62) deserializes the
response into `ZSTR_ELT_POSTING` and looks for `postingType` and
`insertTable`. **This response has neither.** As the code stands it finds
no write-back line, returns `has_wb = abap_false`, and the document is
updated with the submit status only — no IRN, no error detail, silently.

Two different shapes are in play:

| | shape | where it comes from |
|---|---|---|
| **A** — posting file | `{ idempotencyKey, postingType, insertTable[{name,data}] }` | the sample in section 61; self-describing, names its own target table and columns |
| **B** — sync envelope | `{ Success, ErrorDetails, DocumentResponses[] }` | **this** response; a fixed API contract with no table instructions |

Shape A tells the code where to put things. Shape B does not, so the
mapping below has to live in ABAP rather than in a platform schema. The
parser needs to accept both — it cannot be assumed that one replaces the
other across tenants and releases.

---

## The two samples

**Failure** — envelope `Success: "false"`, one error, no `DocumentId`.
**Success** — envelope `Success: "true"`, a `DocumentId`, a `DUP-202`
warning, and a populated `CustomFields`.

---

## ZTEINV_DOC (the document header)

| response path | column | type/len | note |
|---|---|---|---|
| `DocumentResponses[0].Success` | `STATUS` | CHAR 40 | `"true"` → `SUCCESS`, `"false"` → `FAILURE`. See *Status values* below. |
| `DocumentResponses[0].DocumentId` | `INVID` | CHAR 60 | the platform document id. `null` on failure — leave the column untouched rather than writing the literal `null`. |
| `DocumentResponses[0].ErrorDetails[*].ErrorMessage` | `ERROR` | CHAR **250** | joined with `\| `, as HANA does. **Truncates** — see *Truncation*. |
| `CustomFields.einvoice_identifier` | `EINV_IDENTIFIER` | | `"B2B_Sales_Domestic"` |
| `CustomFields["einvoice-type"]` | `EINV_TYPE` | | `"SALES"`. **Hyphenated key** — see *Deserialization*. |
| `CustomFields.doc_type` | `DOC_TYPE` | | `"380"` |
| `CustomFields.VBELN` | `VBELN` | | echoed back from the extract — a **cross-check**, not the source, see below |
| `CustomFields.BELNR` | `BELNR` | | likewise |
| `CustomFields.BUKRS` | `BUKRS` | | likewise |
| `CustomFields.GJAHR` | `GJAHR` | | likewise |
| — | `COMMAND_ID` | | from the submit call. |

### The keys in `CustomFields` are a cross-check

`CustomFields` carries `VBELN`, `BELNR`, `BUKRS` and `GJAHR` — echoed back
from what the extract sent. On this path the submit call still holds them
in scope, so the echo is **not** the source of the key. Compare it:
equality is a free end-to-end check that the answer belongs to the
document just submitted, and a mismatch means the platform replied about
something else and the row must not be written.

Use the submit call's values to write. Use the echo to decide whether to
write at all.
| — | `CRDAT` `CRTIME` `CRUSER` | | set on write; see section 62 on why they are not overwritten on an existing row. |
| — | `UUID` `ZSIGNED_QRCODE` `ZSIGNED_INV` `INVNO` `INVDT` `INVTYPE` `B2C` `B2G` `SENT` `B2C_STATUS` | | **not in this response.** They arrive later through the async `IRN_WRITEBACK` posting file, or not at all for this country variant. |

### Fields with nowhere to go

| response path | why |
|---|---|
| `DocumentResponses[0].UniqueId` | `"100099099000003_400147840_380_2026"` — a composite business key (TRN, invoice, doc type, year). No column in `ZTEINV_DOC` or `ZTEINV_SALES_ST`. HANA has the same problem: its payload carries `UNIQID` and `UNIQUE_IDENTIFIER` and `/CLR/ZT_EINV` has neither, so both are dropped there too (section 61). If it is needed, it needs a column. |
| `DocumentResponses[0].WarningDetails[*]` | `DUP-202` — *"Invoice is already submitted, we are returning the response from the Previously submitted Invoice"*. **Operationally the most important field in the sample** and there is nowhere to put it. A resubmission that silently returns the first submission's answer looks identical to a fresh success. Options: a column, a row in `ZTEINV_ERR` with a `W` marker, or at minimum a message in the action's `reported`. |
| `ErrorDetails[*].Path` | `null` in both samples. No column; `ZTEINV_ERR` has no `PATH`. |
| `CustomFields.MODULE` `TRXID` `TRXNUM` `ORGID` `TRN` `CountryCode` `ACTION` `DeliveryNumber` `UniqueIdentifier` | Oracle EBS fields — `MODULE: "AR"`, `TRXID`, `ORGID`, `TRN`. This envelope is shared with an EBS integration. **Do not map `TRXNUM` to `VBELN`.** It is EBS's transaction number, not an SAP billing document, and the two only coincide by accident. The SAP keys come from the submit call. |

---

## ZTEINV_ERR (one row per error)

`ErrorDetails` appears twice — at envelope level and inside each
`DocumentResponses` entry. In both samples they are identical. Use the
**per-document** copy: it is the one that belongs to a key, and the
envelope copy has no document to attach to when several are submitted.

| response path | column |
|---|---|
| `DocumentResponses[0].ErrorDetails[n].ErrorCode` | `ERRORCODE` (CHAR 40) |
| `DocumentResponses[0].ErrorDetails[n].ErrorMessage` | `ERRORMESSAGE` (CHAR 250) |
| `DocumentResponses[0].ErrorDetails[n].ErrorSource` | `ERRORSOURCE` — `"CLEARTAX"` |
| `DocumentResponses[0].ErrorDetails[n].Path` | *no column* |
| `CustomFields.VBELN` / `BELNR` / `BUKRS` / `GJAHR` | the four keys — same cross-check as above |
| — | `INVNO` from `ZTEINV_DOC-INVNO` if known, else blank |
| — | `ERRORNO` sequence within the document, 1..n |
| — | `ERRORDATE` `ERRORTIME` at write time |

This is the table behind `ZCDS_CUN_EINV_DOC_ERR` and the **API Errors**
facet on the object page, so errors mapped here are visible without a
database query. Writing them is the difference between "FAILURE" and
"FAILURE, and here are the four reasons".

Write them through the BO, same rule as section 62 — `_Error` is a
composition child of `ZCDS_INT_EINV_DOC`, so it is `MODIFY ENTITIES ...
ENTITY einvoice CREATE BY \_Error` from inside the behaviour pool, never
an `INSERT ZTEINV_ERR`.

---

## ZTEINV_SALES_ST (the exchange status)

**Almost nothing in this response belongs here.**

| response path | column | note |
|---|---|---|
| `DocumentResponses[0].DocumentId` | `INVID` | the only unambiguous one |
| `DocumentResponses[0].Success` | `PA_EXCHG_STAT` | *only if* the platform means this as the PA exchange result. In the async payload of section 60 that column carries `SUBMITTED` / `PROCESSING` — a pipeline state, not a boolean. Mapping `"true"` onto it would put a different vocabulary into the same column. **Confirm with the platform team before mapping it.** |
| `CustomFields.einvoice_identifier` | `EINV_IDENTIFIER` | |
| `CustomFields["einvoice-type"]` | `EINV_TYPE` | |
| `CustomFields.doc_type` | `DOC_TYPE` | |
| — | `PPF_*`, `PA_EXCHG_RESCODE/RESMSG`, `INVOICE_NUM`, `INVOICE_TYPE`, `UUID`, `ZSIGNED_*` | **not in this response.** |

The sync response is a *submission acknowledgement*. The exchange-status
pipeline — PA exchange, invoice submission, lifecycle submission,
rejection, refusal, payment — is filled later by the async
`IRN_WRITEBACK` posting file that `/CLR/ZELT_EXEC_COMMAND` fetches
(sections 56 and 60). Writing `ZTEINV_SALES_ST` from here would put a
half-filled row in front of the row that is coming, and the Exchange
Status table would show one line that disagrees with itself.

**Recommendation: do not write `ZTEINV_SALES_ST` from this response.**
Let the batch job own it. If the `INVID` link is wanted immediately, it is
already on `ZTEINV_DOC`.

---

## Four things that will bite

### Deserialization

`/ui2/cl_json=>deserialize( pretty_name = abap_true )` maps `DocumentId` →
`DOCUMENT_ID`, `ErrorDetails` → `ERROR_DETAILS`, `UniqueId` → `UNIQUE_ID`.
That works for everything **except**:

* **`einvoice-type`** — a hyphen cannot appear in an ABAP component name,
  so `pretty_name` cannot produce one. It needs an explicit
  `name_mappings` entry, e.g. `( abap = 'EINVOICE_TYPE' json = 'einvoice-type' )`.
  Without it that field is silently dropped — and `EINV_TYPE` ends up
  empty with nothing in the log.
* **`CustomFields`** is an open map whose keys vary by country variant.
  Deserializing it into a fixed structure drops anything not declared.

### `Success` is a string

`"true"` and `"false"` are JSON **strings**, not booleans. Deserializing
into an `abap_bool` gives `'X'` for both, because both are non-empty. Read
them as `string` and compare, or every failure records as a success.

### Status values

`ZDO_EINV_STATUS` is `CHAR 40` with no fixed value list, so anything fits
and nothing validates. The values already in use across the package are
`SUBMITTED`, `SUCCESS`, `FAILURE`, `ERROR`, `NOT APPLICABLE TRANSACTION`.
Map `"true"` → `SUCCESS` and `"false"` → `FAILURE` to stay inside that set.
The API Status Mapping configuration is the place to make this
configurable rather than literal, if the vocabulary varies by country.

### Truncation

`ERROR` on `ZTEINV_DOC` and `ERRORMESSAGE` on `ZTEINV_ERR` are both
**CHAR 250**. The section 61 sample's joined message was roughly 700
characters — thirteen repetitions of *"Tax exemption reason is required"*
and one real error, in that order, so the **only informative part is the
part that gets cut**. Two consequences:

* the per-error rows in `ZTEINV_ERR` matter more than the joined string on
  the header — each message fits on its own;
* when joining for `ZTEINV_DOC-ERROR`, deduplicate first. Thirteen copies
  of one message compress to one and the real error survives the cut.

---

## Summary of what is needed

1. `parse_writeback` must recognise shape **B** as well as shape **A**, and
   say which it got rather than returning "nothing found" for both an
   unknown shape and an empty response.
2. `ErrorDetails` must be written to `ZTEINV_ERR` through `_Error`, not
   just joined onto the header.
3. `WarningDetails` needs somewhere to go — `DUP-202` is the difference
   between a fresh submission and a replayed one.
4. `UniqueId` needs a column or an explicit decision to drop it.
5. `ZTEINV_SALES_ST` stays with the batch job.
