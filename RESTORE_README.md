# RESTORE package - put the Relevance Mapping app back on its feet

## Why this exists

The SUP_TYPE removal left the system half-activated:

* `ZTEINV_INVMAP` could NOT activate - "ALTER TABLE is not possible /
  Object contains data". The table on the database still has its eight
  key fields, SUP_TYPE among them.
* The six CDS / BDEF / metadata objects DID activate, without SupplyType.

A managed RAP business object whose `mapping for` does not cover a
NOT NULL key column of its persistent table is not a buildable runtime
model, which is what the service compile reports as
`CX_SADL_ASSERT` on `$AE_UIX#SRVD#ZSD_EINV_CONFIG`.

That creates a deadlock: the table needs an empty table to activate, and
emptying it needs the Fiori app, and the Fiori app needs consistent
objects.

## What this package is

The seven objects put back exactly as they were BEFORE the SUP_TYPE
removal, so they match the table that is actually on the database.
Nothing else in the repository differs from the current version.

## Steps

1. Push this folder, pull in ADT, activate all seven objects. They are
   consistent with the live table, so they activate cleanly and the
   Relevance Mapping app works again.
2. In EVERY client that holds rows - 100 and 080 - open the app and use
   the list report's **Export to Spreadsheet** to keep what is there.
3. Delete every row, in every client. ZTEINV_INVMAP is one physical
   table; MANDT is just a column, so the DDIC conversion is blocked by
   rows in any client, not only the one you are activating in.
4. Push the SUP_TYPE-removal version again and pull it.
5. Activate `ZTEINV_INVMAP` FIRST, on its own. With no rows it drops and
   recreates without a conversion.
6. Activate the other six.
7. Re-enter the configuration in 100 from the export, minus Supply Type.

## If step 3 turns out to be impossible

If rows in some client cannot be removed, do not fight the conversion.
Keep SUP_TYPE in the table and hide it from the UI instead: that costs a
dead column in the data model and nothing else. Say so and the change
can be cut that way - no table change, no reload, no deadlock.
