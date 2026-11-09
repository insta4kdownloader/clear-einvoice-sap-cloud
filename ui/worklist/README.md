# Worklist UI: checkbox column and Select All / Deselect All

Two things the backend cannot provide, because they are not backend
concerns:

* **the checkbox column** is the table's selection mode,
* **Select All / Deselect All** change what the user has ticked and send
  nothing to the server.

Neither can be a CDS annotation or a RAP action. Both are settings and
code in the BAS project for the worklist app (`zsdeinvwork`).

---

## 1. Checkbox column

One line in `webapp/manifest.json`, under the list report page's
component settings:

```json
"sap.ui.generic.app": {
  "pages": [
    {
      "entitySet": "EInvoiceWorklist",
      "component": {
        "name": "sap.suite.ui.generic.template.ListReport",
        "list": true,
        "settings": {
          "multiSelect": true
        }
      }
    }
  ]
}
```

`multiSelect: true` puts a checkbox in the first column of every row and
a select-all checkbox in the column header. It is the OData V2 flag - the
V4 equivalent is `tableSettings.selectionMode`, which does not apply
here; the service is V2 (`/sap/opu/odata/sap/...`, dates arriving as
`/Date(...)/`).

With it on, pressing **Submit e-Invoice** acts on every ticked row.
`invocationGrouping: #CHANGE_SET` in `ZCDS_MET_EINV_WORKLIST` makes that
one request and one RAP LUW, so twenty invoices are twenty rows in a
single save rather than twenty round trips - and a failure does not leave
the batch half committed.

**Check before you add it.** If the generator already wrote
`"multiSelect": true`, the checkboxes are there and nothing is needed. A
list report that shows no checkboxes despite having action buttons is
usually in single-select mode because this flag is missing or `false`.

---

## 2. Select All / Deselect All buttons

The header checkbox already selects everything. These buttons exist for
parity with the HANA ALV, which had its own `&SELALL` / `&DESELALL`
function codes in the toolbar next to the submit button.

### Place the controller

Copy `ext/controller/ListReportExt.controller.js` from this folder to:

```
webapp/ext/controller/ListReportExt.controller.js
```

### Register it

In `webapp/manifest.json`, under `sap.ui5`:

```json
"extends": {
  "extensions": {
    "sap.ui.controllerExtensions": {
      "sap.suite.ui.generic.template.ListReport.view.ListReport": {
        "controllerName": "zsdeinvwork.ext.controller.ListReportExt",
        "sap.ui.generic.app": {
          "EInvoiceWorklist": {
            "EntitySet": "EInvoiceWorklist",
            "Actions": {
              "SelectAll": {
                "id": "btnEinvSelectAll",
                "text": "Select All",
                "press": "onSelectAll"
              },
              "DeselectAll": {
                "id": "btnEinvDeselectAll",
                "text": "Deselect All",
                "press": "onDeselectAll"
              }
            }
          }
        }
      }
    }
  }
}
```

Replace `zsdeinvwork` with the app's real namespace if the module was
generated under a different name - it is the `sap.app.id` value in the
same manifest, and the `controllerName` must match it exactly or the
buttons render and do nothing.

If `extends` already exists in the manifest, merge into it rather than
adding a second one; a duplicate key is silently dropped by the JSON
parser and the extension never loads.

### Then

Rebuild and redeploy the app. The two buttons appear in the table
toolbar, to the left of the action buttons that come from the CDS
annotations.

---

## What stays in ABAP

Nothing here changes the behaviour definition. `SubmitEInvoice` already
accepts a table of keys and already materialises the ones that have no
`ZTEINV_DOC` row, so selecting twenty candidates and pressing Submit once
is a path the backend supports without modification. See section 46 of
`CONVERSION_DESIGN.md`.
