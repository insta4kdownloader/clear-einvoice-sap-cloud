CLASS zcl_elt_ping_test DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES if_oo_adt_classrun.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS ZCL_ELT_PING_TEST IMPLEMENTATION.


  METHOD if_oo_adt_classrun~main.

DATA :objPing_test type REF TO zcl_elt.
 CREATE OBJECT    objPing_test.
objPing_test->ping_test( ).


  ENDMETHOD.
ENDCLASS.
