# ZZCLR_GEINV — merge report

`/CLR/ELT`, `/CLR/INSTRUMENTATION` and `/CLR/EINVOICE_ELT` combined into one
ABAP package for single-unit deployment of the global e-invoice solution.

    ZZCLR_ELT          217 files  (the converted /CLR/ELT + /CLR/INSTRUMENTATION)
  + ZZCLR_EINVOICE_ELT 548 files  (the converted /CLR/EINVOICE_ELT)
  + package descriptor   1 file
  ---------------------------------
    ZZCLR_GEINV        766 files

One abapGit repository, one pull, one transport, no cross-package contract.

## Why this was safe

Three facts checked before merging, not assumed:

1. **Zero object-name collisions.** The 296 objects of `ZZCLR_ELT` and the
   320 of `ZZCLR_EINVOICE_ELT` share no name. Nothing had to be renamed.
2. **No reverse dependency.** Nothing in the cloud `ZZCLR_ELT` references an
   e-invoice object. The HANA original *is* circular — `/CLR/ZCL_ELT` does
   `MODIFY /clr/zt_einv` on its error branches — but that was already broken
   in the cloud conversion.
3. **Nothing surviving references anything dropped.** The merge script fails
   rather than emitting a package that would not activate; it caught two IAM
   objects on the first run (see below).

## What was dropped — 201 files

### The ZGSTELT_* generation (168 files)

`ZZCLR_ELT` carries two parallel builds of the same application. `ZGSTELT_*`
is the older one: configuration screens only, with no event log, no APJ jobs,
no BAL logging, no business catalogs and no launchpad pages. The short `Z*`
generation superseded all of it and is what the e-invoice package consumes.

Two of these were *not* caught by an obvious `zgstelt*` filter and are worth
naming, because they would have been missed by hand:

- the four behaviour classes are named **`ZBP_GSTELT_*`**, not `ZGSTELT_*`
- two IAM authorization objects generated for `ZGSTELT_SB_CONFIG` have
  opaque hash filenames (`809734a5…ht.sush.xml`, `8d643d47…ht.sush.xml`)

The reference check found the second pair; the first was found by matching on
object name rather than filename prefix.

### Development scratch shipped in the delivered package (9 files)

| Object | Why |
|---|---|
`ZCL_SELECT_TESTING` | body entirely commented out |
`ZCDS_ADDRESS_TEST1` | duplicate of `ZCDS_ADDRESS_2` — and C1-released |
`ZCDS_V` | `@EndUserText.label: 'cds'` |
`ZTELT_CONFIG_DR` | draft table nothing references |

### C1 release contracts (24 files)

Every `.apis.xml`. With one package there is nothing to release across a
package boundary, and a released object is a frozen API you cannot change.
Re-adding them is a one-file-per-object job if the package is ever split.

## What was rewritten

`PACKAGE_NAME` and `DEVCLASS` in 14 IAM and job objects. The source named
three different packages internally — `ZCLRELT` (6), `ZGSTELT` (1) and
`ZZCLR_ELT` (2) — an inconsistency in the original. All now read
`ZZCLR_GEINV`.

## Verification

`gen/check.py` runs the full consistency check against the merged tree with
`ZCL_ELT`, `ZTELT_CONFIG` and the instrumentation classes removed from the
externals list — so a missing one would now be an error rather than an
assumed import. Result: **no inconsistencies**.

The only externals left are released SAP views: `I_JournalEntry`,
`I_JournalEntryItem`, `I_BillingDocument`, `I_Address`.

## 35 advisory findings in inherited code

These are in files copied verbatim from `ZZCLR_ELT` — they activate in your
tenant today, so they are listed for visibility, not as merge defects:

| File | n | What |
|---|---:|---|
`zcl_elt.clas.abap` | 8 | `WAIT UP TO` in retry loops (blocks a work process), two `COMMIT WORK`, `sy-sysid` |
`zcl_instru_exec.clas.abap` | 7 | `sy-datum` / `sy-uzeit` |
`zcl_instru_event_class.clas.abap` | 4 | `COMMIT WORK AND WAIT` inside a logging method, `sy-batch` |
`zcl_instru_api_class.clas.abap` | 3 | `sy-sysid` |
`zcds_int_event_log.bdef.asbdef` | 12 | aliased CDS elements with no `mapping for` block |
`zbp_cds_cun_comp_details` | 1 | `sy-sysid` |

The last one is worth a look: it is the same defect class the checker found in
the e-invoice configuration BOs, where elements aliased away from their column
(`event_counter` → `EventCounter`) have no mapping entry. Those were fixed on
the e-invoice side. Whether it is a genuine activation error or RAP tolerates
it is worth confirming in ADT — `ZZCLR_ELT` is deployed, which suggests the
latter, but the two cases are identical and only one has a mapping block.

## Deployment

Replaces both repositories. In the target tenant:

1. **Do not install `ZZCLR_ELT` alongside this.** `ZCL_ELT`, `ZTELT_CONFIG`
   and the rest exist here under their original names; two copies cannot
   coexist in one tenant whatever package they sit in.
2. Create package `ZZCLR_GEINV` in your software component.
3. Link it to this repository in abapGit and pull.
4. Activate in the order in CONVERSION_DESIGN.md §10, with the ELT engine and
   instrumentation first — they have no dependency on the e-invoice objects.
5. Everything else in CONVERSION_DESIGN.md still applies, except §0, whose
   package-boundary table is now internal to this package.

If the ELT engine is ever needed by a second product, split it back out: the
objects are unchanged and unrenamed, so it is a package reassignment in ADT
plus re-adding the `.apis.xml` release contracts.

## Inherited objects modified after the merge (07/10/2026)

Two domains inherited verbatim from ZZCLR_ELT were changed on the
customer's instruction, so the package no longer matches ZZCLR_ELT for
these objects:

* `ZDO_ELT_STRING`  - `<LOWERCASE>X</LOWERCASE>` set
* `ZDO_PROJECT_DIS` - `<LOWERCASE>X</LOWERCASE>` set

Both held free text that the DDIC input conversion was upper-casing. See
section 37 of CONVERSION_DESIGN.md.
