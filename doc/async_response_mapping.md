# Async status response → ZTEINV_SALES_ST

The flat status document the platform pushes after validation and
government reporting, and where each field lands.

Companion to `sync_response_mapping.md`. This is the **third** response
shape in this integration:

| | shape | carries a SAP key? |
|---|---|---|
| **A** posting file | `{ idempotencyKey, postingType, insertTable[{name,data}] }` | yes — `VBELN`/`BELNR`/`BUKRS`/`GJAHR` as named fields |
| **B** sync envelope | `{ Success, ErrorDetails, DocumentResponses[] }` | no — the caller still has them in scope |
| **C** async status | this one — flat, no envelope | **no, and the caller is gone** |

---

## Finding the document: `customFields` first, `documentId` second

`customFields` carries `VBELN`, `BELNR`, `BUKRS` and `GJAHR`, echoed back
from what the extract sent. **When they are populated they are the key** —
read them and write the row directly, no lookup.

It is `null` in the sample above, and that is the case that has to work
too. A status document arrives out of band, long after the submission
returned, so nothing in the receiving process already knows which document
it is. With no `customFields` the only usable join is `documentId` →
`ZTEINV_DOC-INVID`:

```abap
SELECT SINGLE vbeln, belnr, bukrs, gjahr
  FROM zteinv_doc
  WHERE invid = @lv_document_id
  INTO @DATA(ls_key).
```

`INVID` is not a key of `ZTEINV_DOC` and has no index, so that fallback is
a full scan per status document. How much that matters depends on how
reliably `customFields` is filled: if it always is, the lookup is a rare
path and an index is not urgent; if it is usually null, the index is the
difference between a status job that keeps up and one that does not.
**Confirm with the platform team whether `customFields` is guaranteed**
before deciding — the sample says null and that is the only evidence so
far.

If neither route identifies a document, the status belongs to a submission
this system did not make (another client, another tenant, a reset test
system). Skip it and log it. Do not create a row: without the SAP key
there is nothing to create.

When both are available, compare them. `customFields` disagreeing with the
`INVID` lookup means one of the two is about a different document, and
neither should be trusted until that is understood.

---

## `flow` picks the table

`"flow": "SALES/PURCHASE"` is the discriminator, not a column.

* `SALES` → `ZTEINV_SALES_ST`, this mapping.
* `PURCHASE` → the AP side (`ZTEDOC_AP*`), a different structure and not
  covered here.

The sample value is the literal string `"SALES/PURCHASE"`, which is the
*documentation* of the field rather than a value. Confirm which of the two
words the live payload actually sends before coding a comparison, and fail
loudly on an unrecognised value rather than defaulting to sales.

---

## The mapping

### Keys — from `customFields`, or the `INVID` lookup

| column | source |
|---|---|
| `VBELN` `BELNR` `BUKRS` `GJAHR` | `customFields.VBELN` / `.BELNR` / `.BUKRS` / `.GJAHR` when populated; otherwise the `ZTEINV_DOC` row found by `documentId` |
| `GJAHR` | the top-level `year` should **agree** with whichever source was used; a disagreement is a defect to report, not a value to write. |

### Mapped fields

| response field | column | len | note |
|---|---|---|---|
| `documentId` | `INVID` | 60 | the join key; also stored |
| `invoiceNumber` | `INVOICE_NUM` | 40 | `"mea-qa-36"` |
| `invoiceTypeCode` | `DOC_TYPE` | 15 | `"389"` — the UBL document type code, same vocabulary as the `"380"` in the section 60 payload. **Not** `INVOICE_TYPE`, which is the platform's own invoice classification and is left empty by that payload too. |
| `documentStatus` | `PA_EXCHG_STAT` | 40 | `"VALIDATED"` — the platform's own validation verdict, which is what the PA exchange column carries (`"SUBMITTED"` in the section 60 sample). |
| `documentStatusErrorReason` | `PA_EXCHG_RESMSG` | **250** | `null` here. Truncates — see below. |
| `governmentReportingStatus` | `PPF_INVSUB_STAT` | 40 | `"ACCEPTED"` — reporting to the authority is the invoice-submission leg of the PPF pipeline (`"PROCESSING"` in the section 60 sample). |
| `governmentReportingStatusErrorReason` | `PPF_INVSUB_RESMSG` | **250** | `null` here. |

### Not in this response — leave untouched

`ZSIGNED_QRCODE`, `ZSIGNED_INV`, `UUID`, `INVOICE_TYPE`,
`EINV_IDENTIFIER`, `EINV_TYPE`, `PA_EXCHG_RESCODE`, `PPF_INVSUB_RESCODE`,
and the whole `PPF_LCSUB_*` / `PPF_LCREJ_*` / `PPF_LCREF_*` /
`PPF_LCPMNT_*` lifecycle block.

Write the mapped columns only. A blanket `MODIFY` from a structure filled
from this document alone would blank every column above — including the
signed invoice and the QR code, which nothing else will put back.

### Fields with no column

| response field | value | note |
|---|---|---|
| `uniqueId` | `"1005020990_mea-qa-36_389_2026"` | no column in `ZTEINV_SALES_ST` or `ZTEINV_DOC`. The same gap as shape B's `UniqueId` and HANA's `UNIQID`/`UNIQUE_IDENTIFIER` — discarded at every end. Useful for support correlation; needs a column if that matters. |
| `sellerElectronicAddress` | `"0235:1005020990"` | scheme-qualified Peppol-style address. No column. |
| `buyerElectronicAddress` | `"0235:1000216372"` | likewise. |
| `invoiceIssueDate` | `"2026-07-04"` | no column here. `ZTEINV_DOC-INVDT` is the equivalent — if it is worth storing, store it there, and convert `YYYY-MM-DD` to an ABAP `DATS`. |
| `invoiceIssueTime` | `"00:00:00"` | no column anywhere. |
| `updateTimestamp` | `"1788241519374"` | epoch **milliseconds as a string**. No column — and see *Ordering* below, because this is the field that decides whether an arriving status is newer than the stored one. |
| `customFields` | `null` | **carries the four SAP keys in practice** — see *Finding the document* above. In shape B it also carried `einvoice_identifier` and `einvoice-type`; if a live payload fills those, they map to `EINV_IDENTIFIER` and `EINV_TYPE`. |

---

## Four things to get right

### Status values are stored raw

`VALIDATED` and `ACCEPTED` go into `PA_EXCHG_STAT` and `PPF_INVSUB_STAT`
exactly as the platform sends them. No translation on write: whatever
transformation is wanted belongs on the read side, where the original is
still available and a changed vocabulary is a view change rather than a
data fix.

Both columns are `ZDE_EINV_STATUS`, `CHAR 40` with no fixed value list, so
any platform vocabulary fits and none of it is validated. That cuts both
ways — nothing rejects a value, and nothing warns when the platform starts
sending a word the UI has never seen.

### Ordering — `updateTimestamp` is not decoration

Status documents can arrive out of order. The one that was generated last
is the truth, not the one that arrived last. There is no column for
`updateTimestamp`, so right now there is no way to tell — a stale
`PROCESSING` arriving after `ACCEPTED` would overwrite it and the invoice
would look stuck forever.

Options, in order of preference:

1. a column on `ZTEINV_SALES_ST` for the timestamp, compared before write;
2. refuse a write that would move a status backwards through a known
   sequence — which needs that sequence written down somewhere first;
3. accept last-writer-wins and know that it is a known hole.

This deserves a decision rather than a default.

### The error reasons are CHAR 250

Both `*ErrorReason` fields are `null` in this sample, which is exactly how
a length problem stays invisible until production. `ZDO_EINV_RESMSG` is
`CHAR 250`; the section 61 sample's error text ran to roughly 700
characters. Truncate deliberately, and put the full text in
`ZTEINV_ERR` where each message gets its own row.

### Write through the business object

`ZTEINV_SALES_ST` is `ZCDS_INT_EINV_DOC_STAT`, a composition child of
`ZCDS_INT_EINV_DOC` exposed as `EInvoiceExchange`. So the write is

```abap
MODIFY ENTITIES OF zcds_int_einv_doc IN LOCAL MODE
  ENTITY einvoice BY \_Exchange
    UPDATE FIELDS ( ... ) WITH lt_status
```

from inside `ZBP_CDS_INT_EINV_DOC` — never an `INSERT`/`MODIFY
ZTEINV_SALES_ST`. Sections 50 and 62 are the long version of why; the
short version is that a direct table write in the interaction phase dumps,
and `IN LOCAL MODE` is only legal inside the BO's own behaviour pool.

A status document for a document with no `_Exchange` child yet needs a
`CREATE BY \_Exchange` rather than an update. Both cases will occur — the
first status for a document creates, the rest update.

---

## Summary

| what | where it goes |
|---|---|
| 7 fields | `ZTEINV_SALES_ST` columns above |
| 4 keys | `customFields` when populated, else looked up via `documentId` → `ZTEINV_DOC-INVID` |
| `flow` | picks sales vs purchase, not stored |
| 6 fields | nowhere — `uniqueId`, both electronic addresses, issue date/time, `updateTimestamp` |
| `customFields` | null here; `EINV_IDENTIFIER` / `EINV_TYPE` if filled |

Three decisions needed before this is built: whether `customFields` is
guaranteed (and so whether the `INVID` index is urgent), what to do about
out-of-order `updateTimestamp`, and whether `uniqueId` earns a column.
