*&---------------------------------------------------------------------*
*& Report z_sysp_sap_adapter2
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT z_sysp_sap_adapter2.

TABLES tadiv.

SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE tblock1.

  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT 1(10) tpack.
    SELECT-OPTIONS sopack FOR tadiv-devclass DEFAULT 'Z*' OPTION CP.
  SELECTION-SCREEN END OF LINE.

  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT 1(10) tppath.
    PARAMETERS pfolder LIKE rlgrap-filename DEFAULT 'c:/temp'.
  SELECTION-SCREEN END OF LINE.

SELECTION-SCREEN END OF BLOCK b1.

SELECTION-SCREEN BEGIN OF BLOCK bsysp WITH FRAME TITLE tblocksy.
  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT 5(40) tsysjobs.
    PARAMETERS psysjobs AS CHECKBOX DEFAULT 'X'.
  SELECTION-SCREEN END OF LINE.
  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT 5(40) tsysprog.
    PARAMETERS psysprog AS CHECKBOX DEFAULT 'X'.
  SELECTION-SCREEN END OF LINE.
  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT 5(40) tsystnap.
    PARAMETERS psystnap AS CHECKBOX.
  SELECTION-SCREEN END OF LINE.
  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT 5(40) tsysvers.
    PARAMETERS psysvers AS CHECKBOX DEFAULT 'X'.
  SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN END OF BLOCK bsysp.

INITIALIZATION.
  sy-title = 'Sysparency Adapter using abapGit'.
  tblock1 = 'Package Download'.
  tpack  = 'Package'.
  tppath = 'Folder'.
  tblocksy = 'Sysparency Data'.
  tsysjobs = 'Jobs'.
  tsysprog = 'Program structure'.
  tsystnap = 'TNAPR (Processing programs for output)'.
  tsysvers = 'System Version'.

START-OF-SELECTION.

  DATA:
    lx_error           TYPE REF TO zcx_abapgit_exception,
    lv_text            TYPE c LENGTH 200,
    ls_local_settings  TYPE zif_abapgit_persistence=>ty_repo-local_settings,
    lo_dot_abapgit     TYPE REF TO zcl_abapgit_dot_abapgit,
    lv_zip_xstring     TYPE xstring,
    lo_frontend_serv   TYPE REF TO zif_abapgit_frontend_services,
    lv_default         TYPE string,
    lv_package_escaped TYPE string,
    lv_zipfile_path    TYPE string,
    lv_target_path     TYPE string,
    iv_package         TYPE devclass,
    li_run_log         TYPE REF TO zif_abapgit_log,
    lt_messages        TYPE zif_abapgit_log=>ty_log_outs,
    ls_message         TYPE zif_abapgit_log=>ty_log_out,
    lv_log_line        TYPE string,
    lv_log_content     TYPE string,
    lv_log_xstring     TYPE xstring,
    lv_log_path        TYPE string,
    lv_pkg_msg_before  TYPE i,
    lv_pkg_msg_after   TYPE i,
    lv_pkg_status      TYPE string,
    lv_safe_text       TYPE string.

  " this will initialize ZABAPGIT in dictionary
  zcl_abapgit_migrations=>run( ).

  CONCATENATE pfolder '/SysparencyExport_' sy-datlo '_' sy-timlo INTO lv_target_path.

  " Always collect a run-wide log so we can persist it as a file at the
  " end of the run. This is the audit artifact that lets us reconstruct
  " skipped or failed packages later.
  CREATE OBJECT li_run_log TYPE zcl_abapgit_log.
  li_run_log->set_title( |Sysparency Adapter Run { sy-datlo } { sy-timlo }| ).
  li_run_log->add_info( |Run started { sy-datlo } { sy-timlo } by { sy-uname } on { sy-sysid }/{ sy-mandt }| ).
  li_run_log->add_info( |Package selection: { sopack-low }..{ sopack-high } (sign={ sopack-sign }, option={ sopack-option })| ).

* load all matching packages
  DATA it_pks TYPE TABLE OF tadir-devclass.

  SELECT DISTINCT t~devclass
    FROM tadir AS t INNER JOIN tdevc AS d
    ON t~devclass = d~devclass
    INTO TABLE it_pks
  WHERE t~devclass IN sopack
  AND ( d~parentcl IS NULL OR d~parentcl = ' ' OR d~parentcl = '' )
  ORDER BY t~devclass.

  li_run_log->add_info( |Packages selected: { lines( it_pks ) }| ).

  LOOP AT it_pks INTO iv_package.

    WRITE / iv_package.

    lo_frontend_serv = zcl_abapgit_ui_factory=>get_frontend_services( ).

    lv_package_escaped = iv_package.
    REPLACE ALL OCCURRENCES OF '/' IN lv_package_escaped WITH '#'.
    lv_default = |{ lv_package_escaped }_{ sy-datlo }_{ sy-timlo }|.

    lv_pkg_msg_before = li_run_log->count( ).
    li_run_log->add_info( |--- Package { iv_package } : export start ---| ).

    TRY.

        lo_dot_abapgit = zcl_abapgit_dot_abapgit=>build_default( ).
        lo_dot_abapgit->set_folder_logic( 'FULL' ).

        lv_zip_xstring = zcl_abapgit_zip=>export(
         is_local_settings = ls_local_settings
         iv_package        = iv_package
         iv_show_log       = abap_false
         io_dot_abapgit    = lo_dot_abapgit
         ii_log            = li_run_log ).

        CONCATENATE lv_target_path '/' lv_default '.zip' INTO lv_zipfile_path.

        lo_frontend_serv->file_download(
            iv_path = lv_zipfile_path
            iv_xstr = lv_zip_xstring ).

        lv_pkg_msg_after = li_run_log->count( ).
        lv_pkg_status = |Package { iv_package }: export OK, { lv_pkg_msg_after - lv_pkg_msg_before - 1 } message(s), zip written to { lv_zipfile_path }|.
        li_run_log->add_info( lv_pkg_status ).
        WRITE / lv_pkg_status.

      CATCH zcx_abapgit_exception INTO lx_error.
        lv_text = lx_error->get_text( ).
        li_run_log->add_exception( ix_exc = lx_error ).
        li_run_log->add_error( |Package { iv_package }: export ABORTED - { lv_text }| ).
        WRITE: / 'ERROR:', lv_text.
        " Continue with next package instead of terminating the whole run,
        " so the run log still gets written and the user can see which
        " packages succeeded and which failed.
    ENDTRY.

  ENDLOOP.

  PERFORM downloadsysparencydump USING lv_target_path.

  " Persist the full run log as a CSV file next to the exported ZIPs.
  li_run_log->add_info( |Run finished { sy-datlo } { sy-timlo }| ).

  lv_log_content = |type;obj_type;obj_name;text| && cl_abap_char_utilities=>cr_lf.
  lt_messages = li_run_log->get_messages( ).
  LOOP AT lt_messages INTO ls_message.
    " Quote text to keep CSV safe (escape embedded quotes and newlines).
    lv_safe_text = ls_message-text.
    REPLACE ALL OCCURRENCES OF '"' IN lv_safe_text WITH '""'.
    REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>cr_lf IN lv_safe_text WITH ' '.
    REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>newline IN lv_safe_text WITH ' '.
    lv_log_line = |{ ls_message-type };{ ls_message-obj_type };{ ls_message-obj_name };"{ lv_safe_text }"|.
    lv_log_content = lv_log_content && lv_log_line && cl_abap_char_utilities=>cr_lf.
  ENDLOOP.

  TRY.
      lv_log_xstring = zcl_abapgit_convert=>string_to_xstring_utf8( lv_log_content ).
      lv_log_path = |{ lv_target_path }/SysparencyExport_{ sy-datlo }_{ sy-timlo }_run.log.csv|.
      lo_frontend_serv = zcl_abapgit_ui_factory=>get_frontend_services( ).
      lo_frontend_serv->file_download(
        iv_path = lv_log_path
        iv_xstr = lv_log_xstring ).
      WRITE: / 'Run log written to', lv_log_path.
    CATCH zcx_abapgit_exception INTO lx_error.
      WRITE: / 'WARNING: could not write run log:', lx_error->get_text( ).
  ENDTRY.

  WRITE / 'Finished downloading'.

END-OF-SELECTION.

FORM downloadsysparencydump USING iv_target_path TYPE string.
  IF psysjobs = 'X'.
    TYPES: BEGIN OF t_datatab,
             jobcount   TYPE tbtco-jobcount,
             jobname    TYPE tbtco-jobname,
             jobgroup   TYPE tbtco-jobgroup,
             stepcount  TYPE tbtcp-stepcount,
             progname   TYPE tbtcp-progname,
             lastchname TYPE tbtco-lastchname,
             periodic   TYPE tbtco-periodic,
             sdlstrtdt  TYPE tbtco-sdlstrtdt,
             sdlstrttm  TYPE tbtco-sdlstrttm,
             strtdate   TYPE tbtco-strtdate,
             strttime   TYPE tbtco-strttime,
             prdmonths  TYPE tbtco-prdmonths,
             prdweeks   TYPE tbtco-prdweeks,
             prddays    TYPE tbtco-prddays,
             prdhours   TYPE tbtco-prdhours,
             prdmins    TYPE tbtco-prdmins,
             btcsystem  TYPE tbtco-btcsystem,
             status     TYPE tbtco-status,
             succnum    TYPE tbtco-succnum,
             prednum    TYPE tbtco-prednum,
             jobclass   TYPE tbtco-jobclass,
             priority   TYPE tbtco-priority,
             eventid    TYPE btcevtjob-eventid,
           END OF t_datatab.

    DATA it_datatab TYPE STANDARD TABLE OF t_datatab INITIAL SIZE 0.

    SELECT j~jobcount
           j~jobname
           j~jobgroup
           s~stepcount
           s~progname
           j~lastchname
           j~periodic
           j~sdlstrtdt
           j~sdlstrttm
           j~strtdate
           j~strttime
           j~prdmonths
           j~prdweeks
           j~prddays
           j~prdhours
           j~prdmins
           j~btcsystem
           j~status
           j~succnum
           j~prednum
           j~jobclass
           j~priority
           e~eventid
      FROM tbtco AS j
        INNER JOIN tbtcp AS s
          ON j~jobname = s~jobname AND j~jobcount = s~jobcount
        LEFT JOIN btcevtjob AS e ON j~jobname = e~jobname AND j~jobcount = e~jobcount
        INTO CORRESPONDING FIELDS OF TABLE it_datatab
        WHERE j~status = 'S' OR j~status = 'Y' OR j~status = 'Z' OR j~status = 'R'
      ORDER BY j~jobname DESCENDING.

    DATA: e_text      TYPE REF TO cx_root,
          jobfilename TYPE string,
          text        TYPE string.

    TRY.
        CONCATENATE iv_target_path '/SysparencyJobExport.sysp' INTO jobfilename.

        cl_gui_frontend_services=>gui_download(
          EXPORTING
            filename = jobfilename
            filetype = 'DAT'
            codepage = '4110'
          CHANGING
            data_tab = it_datatab ).

      CATCH cx_root INTO e_text.
        text = e_text->get_text( ).
        MESSAGE text TYPE 'I' DISPLAY LIKE 'E'.
    ENDTRY.

  ENDIF.

  IF psysprog = 'X'.
    DATA: e_text2     TYPE REF TO cx_root,
          it_progdir  TYPE TABLE OF progdir,
          text2       TYPE string.

    TRY.
        SELECT *
          INTO TABLE it_progdir
          FROM progdir
          WHERE name LIKE 'Z%' OR name LIKE 'Y%'
          ORDER BY NAME STATE.

        DATA progdirfilename TYPE string.
        CONCATENATE iv_target_path '/SysparencyProgdirExport.sysp' INTO progdirfilename.

        cl_gui_frontend_services=>gui_download(
          EXPORTING
            filename = progdirfilename
            filetype = 'DAT'
            codepage = '4110'
          CHANGING
            data_tab = it_progdir ).

      CATCH cx_root INTO e_text2.
        text2 = e_text2->get_text( ).
        MESSAGE text2 TYPE 'I' DISPLAY LIKE 'E'.
    ENDTRY.
  ENDIF.

  IF psystnap = 'X'.
    DATA: e_text3       TYPE REF TO cx_root,
          it_tnapr_dyn  TYPE REF TO data,
          text3         TYPE string,
          tnaprfilename TYPE string.
    FIELD-SYMBOLS: <it_tnapr> TYPE STANDARD TABLE.

    TRY.
        " Use dynamic SQL to avoid compilation error if TNAPR table doesn't exist
        CREATE DATA it_tnapr_dyn TYPE STANDARD TABLE OF ('TNAPR').
        ASSIGN it_tnapr_dyn->* TO <it_tnapr>.

        SELECT *
          INTO TABLE <it_tnapr>
          FROM ('TNAPR').

        CONCATENATE iv_target_path '/SysparencyTNAPRExport.sysp' INTO tnaprfilename.

        cl_gui_frontend_services=>gui_download(
          EXPORTING
            filename = tnaprfilename
            filetype = 'DAT'
            codepage = '4110'
          CHANGING
            data_tab = <it_tnapr> ).

      CATCH cx_root INTO e_text3.
        text3 = e_text3->get_text( ).
        MESSAGE text3 TYPE 'I' DISPLAY LIKE 'E'.
    ENDTRY.
  ENDIF.

  IF psysvers = 'X'.
    DATA: e_text4   TYPE REF TO cx_root,
          it_cvers  TYPE TABLE OF cvers,
          text4     TYPE string.

    TRY.
        SELECT *
          INTO TABLE it_cvers
          FROM cvers
          ORDER BY component.

        DATA versfilename TYPE string.
        CONCATENATE iv_target_path '/SysparencyVersionExport.sysp' INTO versfilename.

        cl_gui_frontend_services=>gui_download(
          EXPORTING
            filename = versfilename
            filetype = 'DAT'
            codepage = '4110'
          CHANGING
            data_tab = it_cvers ).

      CATCH cx_root INTO e_text4.
        text4 = e_text4->get_text( ).
        MESSAGE text4 TYPE 'I' DISPLAY LIKE 'E'.
    ENDTRY.
  ENDIF.

ENDFORM.
