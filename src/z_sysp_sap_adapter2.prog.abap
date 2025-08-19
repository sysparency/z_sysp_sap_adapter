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
    SELECTION-SCREEN COMMENT 5(18) tsysjobs.
    PARAMETERS psysjobs AS CHECKBOX DEFAULT 'X'.
  SELECTION-SCREEN END OF LINE.
  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT 5(18) tsysprog.
    PARAMETERS psysprog AS CHECKBOX DEFAULT 'X'.
  SELECTION-SCREEN END OF LINE.
  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT 5(18) tsyslog.
    PARAMETERS psyslog AS CHECKBOX.
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
  tsyslog = 'Verbose Log'.

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
    iv_show_log        TYPE abap_bool.

  " this will initialize ZABAPGIT in dictionary
  zcl_abapgit_migrations=>run( ).

  CONCATENATE pfolder '/SysparencyExport_' sy-datlo '_' sy-timlo INTO lv_target_path.
  IF ( psyslog = 'X' ).
    iv_show_log = abap_true.
  ELSE.
    iv_show_log = abap_false.
  ENDIF.

* load all matching packages
  DATA it_pks TYPE TABLE OF tadir-devclass.

  SELECT DISTINCT t~devclass
    FROM tadir AS t INNER JOIN tdevc AS d
    ON t~devclass = d~devclass
    INTO TABLE it_pks
  WHERE t~devclass IN sopack
  AND ( d~parentcl IS NULL OR d~parentcl = ' ' OR d~parentcl = '' )
  ORDER BY t~devclass.

  LOOP AT it_pks INTO iv_package.

    WRITE / iv_package.

    lo_frontend_serv = zcl_abapgit_ui_factory=>get_frontend_services( ).

    lv_package_escaped = iv_package.
    REPLACE ALL OCCURRENCES OF '/' IN lv_package_escaped WITH '#'.
    lv_default = |{ lv_package_escaped }_{ sy-datlo }_{ sy-timlo }|.

    TRY.

        lo_dot_abapgit = zcl_abapgit_dot_abapgit=>build_default( ).
        lo_dot_abapgit->set_folder_logic( 'FULL' ).

        lv_zip_xstring = zcl_abapgit_zip=>export(
         is_local_settings = ls_local_settings
         iv_package        = iv_package
         iv_show_log       = iv_show_log
         io_dot_abapgit    = lo_dot_abapgit ).

        CONCATENATE lv_target_path '/' lv_default '.zip' INTO lv_zipfile_path.

        lo_frontend_serv->file_download(
            iv_path = lv_zipfile_path
            iv_xstr = lv_zip_xstring ).

      CATCH zcx_abapgit_exception INTO lx_error.
        lv_text = lx_error->get_text( ).
        MESSAGE s000(oo) RAISING error WITH
          lv_text+0(50)
          lv_text+50(50)
          lv_text+100(50)
          lv_text+150(50).
    ENDTRY.

  ENDLOOP.

  PERFORM downloadsysparencydump.

  WRITE / 'Finished downloading'.

END-OF-SELECTION.

FORM downloadsysparencydump.
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
        CONCATENATE lv_target_path '/SysparencyJobExport.sysp' INTO jobfilename.
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
    DATA: e_text2    TYPE REF TO cx_root,
          it_progdir TYPE TABLE OF progdir,
          text2      TYPE string.
    TRY.
        SELECT *
          INTO TABLE it_progdir
          FROM progdir
          WHERE name LIKE 'Z%' OR name LIKE 'Y%'
          ORDER BY NAME STATE.
        DATA progdirfilename    TYPE string.
        CONCATENATE lv_target_path '/SysparencyProgdirExport.sysp' INTO progdirfilename.
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
ENDFORM.
