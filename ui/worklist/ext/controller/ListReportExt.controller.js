/*
 * Select All / Deselect All for the e-Invoice worklist list report.
 *
 * These two buttons are PURE UI. They change which rows the table has
 * selected and send nothing to the backend, so they cannot be RAP actions
 * - a behaviour definition has no idea what the user has ticked. That is
 * why they live here and not in ZCDS_CUN_EINV_WORKLIST.
 *
 * Note that the standard multi-select table already puts a select-all
 * checkbox in the column header. These buttons are for when you want the
 * action visible in the toolbar next to Submit, which is what the HANA
 * ALV did with its own &SELALL / &DESELALL function codes.
 *
 * Fiori elements for OData V2: the SmartTable in a list report has the
 * stable id "listReport". If a future SAPUI5 version renames it, read the
 * id off the view in the debugger and change the two lookups below - that
 * is the only thing in this file that can rot.
 */
sap.ui.define([], function () {
    "use strict";

    function innerTable(oView) {
        var oSmartTable = oView.byId("listReport");
        return oSmartTable ? oSmartTable.getTable() : null;
    }

    return {

        onSelectAll: function () {
            var oTable = innerTable(this.getView());
            if (!oTable) {
                return;
            }
            // sap.ui.table.Table (Grid) and sap.m.Table (Responsive) both
            // expose selectAll, with the same meaning.
            if (typeof oTable.selectAll === "function") {
                oTable.selectAll();
            }
        },

        onDeselectAll: function () {
            var oTable = innerTable(this.getView());
            if (!oTable) {
                return;
            }
            if (typeof oTable.clearSelection === "function") {
                oTable.clearSelection();            // sap.ui.table.Table
            } else if (typeof oTable.removeSelections === "function") {
                oTable.removeSelections(true);      // sap.m.Table
            }
        }
    };
});
