# z_sysp_sap_adapter2 

Z-Transaction to dump code and data needed for Sysparency analysis using abapGit

It requires SAP BASIS version 702 or higher.
 
latest build: [z_sysp_sap_adapter2.zip](https://github.com/sysparency/z_sysp_sap_adapter/releases/latest/download/z_sysp_sap_adapter2.zip)

Build was generated using [abapmerge](https://github.com/larshp/abapmerge)

## Installation

1. Download the latest build: [z_sysp_sap_adapter2.zip](https://github.com/sysparency/z_sysp_sap_adapter/releases/latest/download/z_sysp_sap_adapter2.zip)
2. In your SAP® system in SE38, create the program Z_SYSP_SAP_ADAPTER2_STANDALONE with the downloaded ABAP® code and start it.
3. Under Package you can select which files you want to download (e.g. Z* for all packages in the Z namespace).
4. Run the report to download your ABAP® programs.
5. "Mask user names (GDPR)" is on by default: the run log and the job export (last changed by)
   then carry `MASKED` instead of SAP user names. abapGit already
   strips user and date fields from the serialized objects. Untick only if your data policy allows names.
   If the error "sy-subrc 15" occurs, check in the SAP GUI options -> Security -> Security Settings whether a rule prevents access to the local directory.

## Standalone build

The standalone in the release assets is merged with [abapmerge](https://github.com/larshp/abapmerge)
from a clean abapGit checkout:

1. Check out [abapGit](https://github.com/abapGit/abapGit) at the latest release tag.
2. Apply the local patches from this repo: `git apply patches/abapgit/*.patch`
   (see [patches/abapgit/README.md](patches/abapgit/README.md) for what they do and their upstream status).
3. Copy `src/z_sysp_sap_adapter2.prog.abap` from this repo into the abapGit `src/` folder.
4. Delete `src/zabapgit.prog.abap`, `src/zabapgit_forms.prog.abap` and
   `src/zabapgit_password_dialog.prog.abap` (keep all XML files).
5. Run `npx abapmerge -f src/z_sysp_sap_adapter2.prog.abap -c z_sysp_sap_adapter2_standalone -o z_sysp_sap_adapter2.abap`.
6. Zip the result together with `LICENSE-abapGit.txt` (MIT notice of the bundled abapGit code) and
   publish it as a new GitHub release (`build-<date>`) — the download links above always point
   to the latest release.

## Credits and References
Adapter is based on [abapGit](https://github.com/abapGit/abapGit), Copyright (c) 2014 abapGit Contributors,
licensed under the [MIT License](LICENSE-abapGit.txt). The standalone build bundles abapGit; the MIT
copyright and permission notice is reproduced in the program header and ships as `LICENSE-abapGit.txt`
in every release zip. The adapter code itself is (c) Sysparency.
