# ZZCLR_GEINV — Clear Global e-Invoice for SAP S/4HANA Public Cloud

One ABAP Cloud package covering everything the three on-premise packages did:

| On-premise | Here |
|---|---|
`/CLR/ELT` | the command/pull engine, `ZCL_ELT`, the configuration table |
`/CLR/INSTRUMENTATION` | the event log and its API classes |
`/CLR/EINVOICE_ELT` | the ten configuration business objects, the Sales/AR e-invoice cockpit, the AP inbound cockpit and the self-billed cockpit |

One package means one repository, one transport and one import. **Do not also
install `ZZCLR_ELT`** — everything it contains is in here, and installing both
would create duplicate objects.

Read in this order:

1. **CONVERSION_DESIGN.md** — every mapping decision, the object inventory and
   activation order, and what still needs verifying in ADT.
2. **CODE_REVIEW.md** — the review of this package: what was wrong, what was
   fixed, what is deliberately left open. Section 13 of CONVERSION_DESIGN.md
   covers the normalised e-document model that replaced the flat AP and
   self-billed tables.
3. **MERGE_REPORT.md** — why merging the three packages was safe, and the 201
   files dropped on the way.

## Import

abapGit repository, flat `src/`, `FOLDER_LOGIC=FULL`, master language E.

1. Create package `ZZCLR_GEINV` in the software component of your ABAP Cloud
   tenant.
2. Link it to this repository in abapGit (in ADT: *Repositories* → *Link*) and
   pull.
3. Activate in the order given in §10 of CONVERSION_DESIGN.md.

4. Recreate each of the six `ZSB_EDOC_*` / `ZSB_EINV_*` service bindings in
   ADT over its `ZSD_*` service definition, binding type **OData V2 - UI**,
   publish, and push. V2 because every business object here is managed
   without draft, which is the case SAP's own wizard says to expose as V2
   (§27).
   A publishable binding is four objects and the repository carries one of
   them; pushing after the first install fixes that for every install after
   it (§26).

There is no dependency on any other custom package.

## Not in the repository

Anything carrying a platform-generated identifier. The OData V4 endpoints are
created by *Local Publish* on each service binding (§24); the business catalog
for the four jobs is created in ADT, because of its generated CHIP_ID (§23.2);
the launchpad app descriptor items, the launchpad page templates and the Fiori
Elements apps are all generated when the apps are deployed from BAS (§7, §25).

The launchpad descriptors and page templates used to be in here and were
removed - a generated hash cannot be kept correct by hand across two systems,
and the one in `ZLPP_ELT_CONFIG` had already gone stale (§21.2, §25).

## gen/

The generator scripts that produced the DDIC layer, the ten configuration
business objects and the AP / self-billed RAP stack, plus the static
consistency checkers.

    python3 gen/extract_ap.py      # read the /CLR/EINV_ELT_AP drop + its workbook
    python3 gen/gen_ddic.py        # domains, data elements, tables, structures
    python3 gen/gen_config_rap.py  # the ten configuration business objects
    python3 gen/gen_apx.py         # the normalised AP + self-billed e-document stack
    python3 gen/gen_wrappers.py    # abapGit wrappers, services, messages, jobs
    python3 gen/merge.py           # rebuild this package from the two sources
    python3 gen/check.py           # static consistency check (e-invoice objects)
    python3 gen/check_merged.py    # the same, over the merged package

Run them in that order: `extract_ap.py` writes `ap_spec.json`, which `gen_apx.py`
reads.

Keep them. Regenerating is how you add a configuration table without
hand-editing 22 files, and the checkers carry 57 rules — forty-six of them added
after reviewing generated code that looked right and was not, and after seven
activation rounds in the tenant — that catch the
specific defect classes this conversion is prone to. Fixes to generated objects
belong in the generator, not in `src/`.

`extract_ap.py` reads the HANA export and the mapping workbook directly, so
pointing its `HANA` and `XLSX` constants at a newer drop and re-running the
chain is how you pick up further changes to the e-document model.

## Before you activate

Seven activation rounds (§14-§20) cleared the "verify in ADT" list down to two
items: `I_BillingDocument-BillingDocumentType` in `ZCDS_INT_EINV_RELEVANT`, and
the released state of `/ui2/cl_json`. Both are flagged in a comment at the place
they matter.

Three tables warn that their key wants the Inverted Individual type on HANA
(§15.3). They activate as they are; set it in the table's technical settings in
ADT when convenient.

Within the APJ objects the order is classes, then `ZAJC_*` catalog entries,
then `ZAJT_*` templates - a template references its catalog entry and a
catalog entry its class (§21.1).

The four `ZAJT_EINV_*` templates import with an empty Job Catalog Entry field.
Their job catalog entries had no IAM app registration, which this package now
supplies (§23). The order is classes, `ZAJC_*`, `ZAJC_*_SAJC`, `ZAJT_*`. If a
template is still empty after the pull, type the entry into the field in ADT
and activate - abapGit re-imports a file only when its content changes, so an
empty reference stored on an earlier pull survives later ones.

One thing still has to be created in ADT: a **business catalog** for the four
e-invoice jobs, with the four `ZAJC_*_SAJC` IAM apps assigned to it. It cannot
ship in the repository because its CHIP_ID is generated. Until it exists the
jobs activate but cannot be scheduled from the launchpad (§23.2).

Two behaviour changes you may need to act on.

The Seller Action's VAT split is now four flat rate/amount pairs instead of an
unbounded table — the deep action parameter does not survive into `%param`.
§19.4 of CONVERSION_DESIGN.md explains the cap and how to lift it properly.

And the `updsysid` determination on
`ZCDS_INT_ELT_CONFIG`, which defaulted `Sysid` to `'CXS'`, is removed. It could
never have run — `Sysid` is a key field and RAP does not let a determination
change one — but if anything relied on that default, it now has to come from
the create payload. §17.4 of CONVERSION_DESIGN.md has the detail.
