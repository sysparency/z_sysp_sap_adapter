*&---------------------------------------------------------------------*
*& Report  Z_SYSP_COUNT_ASSESSMENT
*&
*& Sysparency Pre-Assessment
*& Counts SAP custom code objects by namespace and flags those that
*& are potentially billable (user-startable with custom functionality).
*& Run this report and send the result to Sysparency
*& before installing the full adapter.
*&
*& Compatible with SAP BASIS 702+ (including S/4HANA 2023+)
*& No transport required - create as local object ($TMP)
*&---------------------------------------------------------------------*
REPORT z_sysp_count_assessment
  LINE-SIZE 100
  LINE-COUNT 0
  NO STANDARD PAGE HEADING.

*&---------------------------------------------------------------------*
*& TABLE DECLARATIONS (required before SELECT-OPTIONS)
*&---------------------------------------------------------------------*
TABLES: tadir.

*&---------------------------------------------------------------------*
*& SELECTION SCREEN
*&---------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b0 WITH FRAME TITLE txt_hdr.
  SELECTION-SCREEN COMMENT /1(75) txt_l1.
  SELECTION-SCREEN COMMENT /1(75) txt_l2.
SELECTION-SCREEN END OF BLOCK b0.

SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE txt_ns.
  SELECTION-SCREEN COMMENT /1(75) txt_n1.
  SELECTION-SCREEN SKIP.
  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT 1(28) txt_n2 FOR FIELD so_nsp.
    SELECT-OPTIONS so_nsp FOR tadir-obj_name NO INTERVALS.
  SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN END OF BLOCK b1.

*&---------------------------------------------------------------------*
*& INITIALIZATION
*&---------------------------------------------------------------------*
INITIALIZATION.
  txt_hdr = 'Sysparency - Custom Code Pre-Assessment'.
  txt_l1  = 'Counts SAP custom code objects and flags those that are'.
  txt_l2  = 'potentially billable. Send the result to Sysparency.'.

  txt_ns  = 'Namespace Configuration'.
  txt_n1  = 'Default: Z* and Y*. Add custom prefixes e.g. /ABC/*.'.
  txt_n2  = 'Namespace prefix'.

  so_nsp-sign   = 'I'.
  so_nsp-option = 'CP'.
  so_nsp-low    = 'Z*'.
  APPEND so_nsp.
  so_nsp-low    = 'Y*'.
  APPEND so_nsp.
  CLEAR so_nsp.

*&---------------------------------------------------------------------*
*& DATA DECLARATIONS
*&---------------------------------------------------------------------*
TYPES: BEGIN OF ty_result,
         billable TYPE c LENGTH 1,
         category TYPE string,
         count    TYPE i,
       END OF ty_result.

DATA: lt_result TYPE TABLE OF ty_result,
      ls_result TYPE ty_result.

DATA: lv_prog    TYPE i VALUE 0,
      lv_fugr    TYPE i VALUE 0,
      lv_fugr_tx TYPE i VALUE 0,
      lv_badi    TYPE i VALUE 0,
      lv_badi_cl TYPE i VALUE 0,
      lv_exit    TYPE i VALUE 0,
      lv_ui5     TYPE i VALUE 0,
      lv_tran    TYPE i VALUE 0,
      lv_ddls    TYPE i VALUE 0,
      lv_bdef    TYPE i VALUE 0,
      lv_srvd    TYPE i VALUE 0,
      lv_srvb    TYPE i VALUE 0,
      lv_total   TYPE i VALUE 0.

DATA: lt_nsp      TYPE RANGE OF tadir-obj_name,
      ls_nsp      LIKE LINE OF lt_nsp,
      lt_nsp_mod  TYPE RANGE OF modsapa-name,
      ls_nsp_mod  LIKE LINE OF lt_nsp_mod,
      lt_nsp_sapl TYPE RANGE OF tstc-pgmna,
      ls_nsp_sapl LIKE LINE OF lt_nsp_sapl.

DATA: lv_ui5a TYPE i,
      lv_ui5b TYPE i.

*&---------------------------------------------------------------------*
*& MAIN PROCESSING
*&---------------------------------------------------------------------*
START-OF-SELECTION.

  " Build namespace ranges from selection
  LOOP AT so_nsp.
    ls_nsp-sign   = so_nsp-sign.
    ls_nsp-option = so_nsp-option.
    ls_nsp-low    = so_nsp-low.
    ls_nsp-high   = so_nsp-high.
    APPEND ls_nsp TO lt_nsp.

    ls_nsp_mod-sign   = so_nsp-sign.
    ls_nsp_mod-option = so_nsp-option.
    ls_nsp_mod-low    = so_nsp-low.
    ls_nsp_mod-high   = so_nsp-high.
    APPEND ls_nsp_mod TO lt_nsp_mod.

    " For FUGR-to-transaction mapping: TSTC-PGMNA = 'SAPL<fugr>'
    ls_nsp_sapl-sign   = so_nsp-sign.
    ls_nsp_sapl-option = so_nsp-option.
    CONCATENATE 'SAPL' so_nsp-low INTO ls_nsp_sapl-low.
    APPEND ls_nsp_sapl TO lt_nsp_sapl.
  ENDLOOP.

  " 1. Programs - only executable (SUBC=1) and module pools (SUBC=M)
  "    are user-startable; includes, function group mains, subroutine
  "    pools etc. are filtered out.
  SELECT COUNT(*) INTO lv_prog
    FROM tadir AS t
    INNER JOIN trdir AS r ON r~name = t~obj_name
    WHERE t~pgmid    = 'R3TR'
      AND t~object   = 'PROG'
      AND t~obj_name IN lt_nsp
      AND r~subc IN ( '1', 'M' ).
  ls_result-billable = 'X'.
  ls_result-category = 'Programs (executable + module pool)'.
  ls_result-count    = lv_prog.
  APPEND ls_result TO lt_result.

  " 2. Function Groups (total) - reference only
  SELECT COUNT(*) INTO lv_fugr FROM tadir
    WHERE pgmid    = 'R3TR'
      AND object   = 'FUGR'
      AND obj_name IN lt_nsp.
  ls_result-billable = ' '.
  ls_result-category = 'Function Groups (total)'.
  ls_result-count    = lv_fugr.
  APPEND ls_result TO lt_result.

  " 2a. Function Groups referenced by transactions - billable
  SELECT COUNT( DISTINCT pgmna ) INTO lv_fugr_tx FROM tstc
    WHERE pgmna IN lt_nsp_sapl.
  ls_result-billable = 'X'.
  ls_result-category = '  -> referenced by transactions'.
  ls_result-count    = lv_fugr_tx.
  APPEND ls_result TO lt_result.

  " 3. Transactions (reference)
  SELECT COUNT(*) INTO lv_tran FROM tadir
    WHERE pgmid    = 'R3TR'
      AND object   = 'TRAN'
      AND obj_name IN lt_nsp.
  ls_result-billable = ' '.
  ls_result-category = 'Transactions (TRAN)'.
  ls_result-count    = lv_tran.
  APPEND ls_result TO lt_result.

  " 4a. BAdI Implementations - new (Enhancement Framework, ENHO)
  SELECT COUNT(*) INTO lv_badi FROM tadir
    WHERE pgmid    = 'R3TR'
      AND object   = 'ENHO'
      AND obj_name IN lt_nsp.
  ls_result-billable = 'X'.
  ls_result-category = 'BAdI Implementations - new (ENHO)'.
  ls_result-count    = lv_badi.
  APPEND ls_result TO lt_result.

  " 4b. BAdI Implementations - classical (SE18/SE19, SXCI)
  SELECT COUNT(*) INTO lv_badi_cl FROM tadir
    WHERE pgmid    = 'R3TR'
      AND object   = 'SXCI'
      AND obj_name IN lt_nsp.
  ls_result-billable = 'X'.
  ls_result-category = 'BAdI Implementations - classical (SXCI)'.
  ls_result-count    = lv_badi_cl.
  APPEND ls_result TO lt_result.

  " 5. Customer Exits
  SELECT COUNT(*) INTO lv_exit FROM modsapa
    WHERE name IN lt_nsp_mod.
  ls_result-billable = 'X'.
  ls_result-category = 'Customer Exits / CMOD (MODSAPA)'.
  ls_result-count    = lv_exit.
  APPEND ls_result TO lt_result.

  " 6. Fiori / UI5 Apps
  SELECT COUNT(*) INTO lv_ui5a FROM tadir
    WHERE pgmid    = 'R3TR'
      AND object   = 'WAPA'
      AND obj_name IN lt_nsp.
  SELECT COUNT(*) INTO lv_ui5b FROM tadir
    WHERE pgmid    = 'R3TR'
      AND object   = 'UI5C'
      AND obj_name IN lt_nsp.
  lv_ui5 = lv_ui5a + lv_ui5b.
  ls_result-billable = 'X'.
  ls_result-category = 'Fiori / UI5 Apps (WAPA + UI5C)'.
  ls_result-count    = lv_ui5.
  APPEND ls_result TO lt_result.

  " 7. RAP - CDS Views (reference)
  SELECT COUNT(*) INTO lv_ddls FROM tadir
    WHERE pgmid    = 'R3TR'
      AND object   = 'DDLS'
      AND obj_name IN lt_nsp.
  ls_result-billable = ' '.
  ls_result-category = 'CDS Views (DDLS)'.
  ls_result-count    = lv_ddls.
  APPEND ls_result TO lt_result.

  " 8. RAP - Behavior Definitions (reference)
  SELECT COUNT(*) INTO lv_bdef FROM tadir
    WHERE pgmid    = 'R3TR'
      AND object   = 'BDEF'
      AND obj_name IN lt_nsp.
  ls_result-billable = ' '.
  ls_result-category = 'Behavior Definitions (BDEF)'.
  ls_result-count    = lv_bdef.
  APPEND ls_result TO lt_result.

  " 9. RAP - Service Definitions (reference)
  SELECT COUNT(*) INTO lv_srvd FROM tadir
    WHERE pgmid    = 'R3TR'
      AND object   = 'SRVD'
      AND obj_name IN lt_nsp.
  ls_result-billable = ' '.
  ls_result-category = 'Service Definitions (SRVD)'.
  ls_result-count    = lv_srvd.
  APPEND ls_result TO lt_result.

  " 10. RAP - Service Bindings (billable - modern Fiori entry point)
  SELECT COUNT(*) INTO lv_srvb FROM tadir
    WHERE pgmid    = 'R3TR'
      AND object   = 'SRVB'
      AND obj_name IN lt_nsp.
  ls_result-billable = 'X'.
  ls_result-category = 'Service Bindings (SRVB)'.
  ls_result-count    = lv_srvb.
  APPEND ls_result TO lt_result.

  " Total potentially billable
  lv_total = lv_prog + lv_fugr_tx + lv_badi + lv_badi_cl
           + lv_exit + lv_ui5 + lv_srvb.

*&---------------------------------------------------------------------*
*& OUTPUT
*&---------------------------------------------------------------------*
END-OF-SELECTION.

  " Header
  WRITE: / '============================================================'.
  WRITE: / '        SYSPARENCY - Custom Code Pre-Assessment'.
  WRITE: / '        SAP Custom Object Count by Namespace'.
  WRITE: / '============================================================'.
  WRITE: /.

  " System & date info
  WRITE: / 'System  :', sy-sysid.
  WRITE: / 'Client  :', sy-mandt.
  WRITE: / 'Date    :', sy-datum.
  WRITE: / 'User    :', sy-uname.
  WRITE: /.

  " Configured namespaces
  WRITE: / 'Namespaces analyzed:'.
  LOOP AT so_nsp.
    WRITE: /5 so_nsp-low.
  ENDLOOP.
  WRITE: /.

  " Results table
  "  category column  : pos 1 -49   (48 chars)
  "  count column     : pos 50-56   (width 7, right-aligned)
  "  pot. bill. col   : pos 62+
  WRITE: / '-------------------------------------------------------------------'.
  WRITE: /1  'Object Type',
         50  'Count',
         62  'Pot. bill.'.
  WRITE: / '-------------------------------------------------------------------'.

  LOOP AT lt_result INTO ls_result.
    IF ls_result-billable = 'X'.
      WRITE: /1  ls_result-category,
             50(7) ls_result-count,
             62  'yes'.
    ELSE.
      WRITE: /1  ls_result-category,
             50(7) ls_result-count,
             62  '(ref)'.
    ENDIF.
  ENDLOOP.

  WRITE: / '-------------------------------------------------------------------'.
  WRITE: /1  'TOTAL POTENTIALLY BILLABLE',
         50(7) lv_total.
  WRITE: / '==================================================================='.
  WRITE: /.
  WRITE: / 'IMPORTANT NOTE:'.
  WRITE: / 'These numbers are NOT the exact objects that will be billed.'.
  WRITE: / 'They provide an initial indication of the level of customization'.
  WRITE: / 'in this SAP system. The final billing scope is determined after'.
  WRITE: / 'the Sysparency adapter has been installed and a full analysis'.
  WRITE: / 'has been performed.'.
