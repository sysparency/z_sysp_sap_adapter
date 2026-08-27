# Standalone build

The standalone program in the release assets is merged with [abapmerge](https://github.com/larshp/abapmerge)
from a clean abapGit checkout. This is a manual step; the CI workflow only runs abaplint.

1. Check out [abapGit](https://github.com/abapGit/abapGit) at the latest release tag.
2. Apply the local patches from this repo: `git apply patches/abapgit/*.patch`
   (see [patches/abapgit/README.md](patches/abapgit/README.md) for what they do and their upstream status).
3. Copy `src/z_sysp_sap_adapter2.prog.abap` from this repo into the abapGit `src/` folder.
4. Delete `src/zabapgit.prog.abap`, `src/zabapgit_forms.prog.abap` and
   `src/zabapgit_password_dialog.prog.abap` (keep all XML files).
5. Run `npx abapmerge -f src/z_sysp_sap_adapter2.prog.abap -c z_sysp_sap_adapter2_standalone -o z_sysp_sap_adapter2.abap`.
6. Zip the result together with `LICENSE-abapGit.txt` (MIT notice of the bundled abapGit code) and
   publish it as a new GitHub release (`build-<date>`). The download link in the [README](README.md)
   always points to the latest release.
