"! <p class="shorttext synchronized">e-Invoice country handler: Jordan</p>
"!
"! Registers Jordan as a supported country. See ZCL_EINV_COUNTRY_DE for the
"! full explanation - `/CLR/ZCL_EINV_JO` is likewise an empty 15-line stub
"! in the HANA package and overrides nothing.
"!
"! One thing that IS Jordan-shaped in the 2026-09-25 drop: `/CLR/ZT_EINV`
"! and `/CLR/ZT_SALES_ST` gained ZSIGNED_QRCODE, ZSIGNED_INV and UUID in
"! the same delivery. A signed invoice plus a QR code is the JoFotara
"! pattern. Nothing in the export writes those three fields, so the
"! producer is on the platform side; if signing ever has to happen in SAP,
"! this class is where it belongs.
CLASS zcl_einv_country_jo DEFINITION
  PUBLIC
  INHERITING FROM zcl_einv_country_default
  CREATE PUBLIC.

  PUBLIC SECTION.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_einv_country_jo IMPLEMENTATION.
ENDCLASS.
