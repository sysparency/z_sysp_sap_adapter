# z_sysp_sap_adapter2 

Z-Transaction to dump code and data needed for Sysparency analysis using abapGit

It requires SAP BASIS version 702 or higher.
 
latest build: [z_sysp_sap_adapter2.zip](https://github.com/sysparency/z_sysp_sap_adapter/releases/latest/download/z_sysp_sap_adapter2.zip)

Build was generated using [abapmerge](https://github.com/larshp/abapmerge), see [BUILD.md](BUILD.md).

## Installation

1. Download the latest build: [z_sysp_sap_adapter2.zip](https://github.com/sysparency/z_sysp_sap_adapter/releases/latest/download/z_sysp_sap_adapter2.zip)
2. In your SAP® system in SE38, create the program Z_SYSP_SAP_ADAPTER2_STANDALONE with the downloaded ABAP® code.
   Create it as a **local object (package `$TMP`)**. No transport is required, and objects in `$TMP` are not
   matched by the default package selection `Z*`, so the adapter does not end up in its own export.
   If your guidelines require a transportable Z package or a different program name, tell us the program
   name and package so we can exclude the adapter from the analysis.
3. Under Package you can select which files you want to download (e.g. Z* for all packages in the Z namespace).
4. Run the report to download your ABAP® programs.
5. "Mask user names (GDPR)" is on by default: the run log and the job export (last changed by)
   then carry `MASKED` instead of SAP user names. abapGit already
   strips user and date fields from the serialized objects. Untick only if your data policy allows names.
   If the error "sy-subrc 15" occurs, check in the SAP GUI options -> Security -> Security Settings whether a rule prevents access to the local directory.

## Standalone build

How the release zip is built from abapGit and this repo is described in [BUILD.md](BUILD.md).

## Credits and References
Adapter is based on [abapGit](https://github.com/abapGit/abapGit), Copyright (c) 2014 abapGit Contributors,
licensed under the [MIT License](LICENSE-abapGit.txt). The standalone build bundles abapGit; the MIT
copyright and permission notice is reproduced in the program header and ships as `LICENSE-abapGit.txt`
in every release zip. The adapter code itself is (c) Sysparency GmbH.
