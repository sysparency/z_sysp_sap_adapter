# Local abapGit patches for the standalone build

Apply these onto the clean abapGit release-tag checkout **before** running
abapmerge (`git apply patches/abapgit/*.patch`). They are lost whenever the
abapGit working copy is switched to another tag — always re-apply.

Verified against abapGit v1.134.0.

## 01-xml-output-pnumc-values.patch

`zcl_abapgit_xml_output~add`: NUMC/packed values with leading blanks
(e.g. ' 00000') raise CX_SY_CONVERSION_NO_NUMBER inside CALL TRANSFORMATION id.
The patch converts P/NUMC values to a blank-free string beforehand, so the
object stays in the export.

Upstream status: issue abapGit#7715, fixed by PR #7812 (merged 2026-08-09,
first release will be > v1.134.0). The upstream fix only *catches* the error —
the affected object still fails to serialize. Our patch *keeps* the object,
so it stays preferable for analysis exports even after v1.135.

## 02-form-tdspras-fallback.patch

`zcl_abapgit_object_form`: SAPScript text headers whose language has no ISO
mapping (not maintained in T002) yield an empty language suffix. Upstream
(issue #7714, fixed in v1.134.0) refuses to serialize such headers — the
language variant is missing from the export. The patch falls back to the raw
tdspras key instead, keeping the variant; the upstream raise remains as
backstop for completely empty values. Deliberate deviation: analysis exports
prefer keeping data over strict consistency.

## 03-objects-files-duplicate-guard.patch

`zcl_abapgit_objects_files->add_string`: duplicate path/filename combinations
(e.g. from orphaned STXH language entries) dump with ITAB_DUPLICATE_KEY on the
unique table key and abort the whole export run. The patch skips the duplicate
(first variant wins) and continues. No upstream equivalent; a mergeable
upstream variant would raise a proper exception instead of dumping.
