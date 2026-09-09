# Notes: missing variable types in registers-guide schema

**For Ole, to fill `registers-guide`.** This file is notes only. It is **not** schema and **not** DGP. Do not copy it into `schema/registers/*.yaml` as-is; if any row had needed a fill, Ole would write that fill into the guide after checking the source.

## Schema SHA read

- Repo (read-only): [`steno-aarhus/registers-guide`](https://github.com/steno-aarhus/registers-guide)
- Path: `schema/registers/*.yaml` (24 files)
- SHA: `8a014cf80d2682699141150f58a2330040177422`
- That SHA **was HEAD of `main`** when this audit ran (2026-09-01, Europe/Berlin).
- Commit: [8a014cf](https://github.com/steno-aarhus/registers-guide/commit/8a014cf80d2682699141150f58a2330040177422) — *build-schema-tables: drop the Years column per table, not per register (bef's key table showed an empty one)*

Allowed types (from `schema/R/validate_schema.R` `ALLOWED_TYPES`): `character` | `factor` | `date` | `datetime` | `integer` | `numeric`.

## Result

**0 columns** have `type` missing, null, empty, or the string `unknown`.

All **443** columns across all **24** register YAML files have a non-empty type in the allowed set (except `factor`, which is allowed but unused).

DST forskningsvariabellister were **not** queried for proposed fills, because the missing-type set is empty. No type was invented.

Counts: **proposed = 0**, **STILL UNKNOWN = 0**, **missing-type columns = 0**.

## Missing-type table

A column was counted as missing-type if its `type` field was any of: key absent, YAML `null`, empty string, or the string `unknown` (any case). Parsed with PyYAML `safe_load` on every `columns:` item; cross-checked by grepping raw `type:` lines and by splitting each `- id:` block.

| register | column | proposed type | DST wording | source URL | confidence |
|---|---|---|---|---|---|
| — | — | — | No missing-type columns at SHA `8a014cf80d2682699141150f58a2330040177422`. Nothing for Ole to fill. | — | — |

*(0 data rows.)*

## Inventory (every register, so the empty table is auditable)

| register | n columns | types present |
|---|---:|---|
| akm | 10 | character:3, integer:7 |
| bef | 40 | character:22, date:8, integer:10 |
| dod | 5 | character:3, date:1, integer:1 |
| dodsaars | 18 | character:14, date:1, integer:3 |
| dodsaarsager | 10 | character:9, date:1 |
| dodsaasg | 9 | character:7, date:1, integer:1 |
| faik | 87 | character:9, integer:1, numeric:77 |
| lmdb | 15 | character:9, date:1, integer:2, numeric:3 |
| lpr_a_diagnose | 12 | character:11, integer:1 |
| lpr_a_kontakt | 54 | character:43, date:2, datetime:5, integer:4 |
| lpr_a_procregistrering | 20 | character:17, datetime:3 |
| lpr_adm | 19 | character:13, date:2, integer:2, numeric:2 |
| lpr_diag | 6 | character:5, integer:1 |
| lpr_sksopr | 7 | character:5, date:1, integer:1 |
| lpr_sksube | 7 | character:5, date:1, integer:1 |
| sssy | 16 | character:12, integer:3, numeric:1 |
| sysi | 16 | character:13, integer:2, numeric:1 |
| t_psyk_adm | 14 | character:9, date:2, integer:3 |
| t_psyk_diag | 4 | character:4 |
| udda | 18 | character:13, date:4, integer:1 |
| vnds | 6 | character:5, date:1 |
| vnds_hist | 6 | character:5, date:1 |
| vnds_ind | 22 | character:16, date:3, integer:3 |
| vnds_ud | 22 | character:16, date:3, integer:3 |
| **total** | **443** | character:268, numeric:84, integer:50, date:33, datetime:8, factor:0 |

Observed `type:` values in the raw YAML (443 lines, no other values):

- `character` 268
- `numeric` 84
- `integer` 50
- `date` 33
- `datetime` 8
- `factor` 0
- missing / null / empty / `unknown` 0

## What this is not

- Not a claim that every assigned type is *correct* against DST — only that none are *blank*. Checking correctness of already-filled types is a separate job.
- Not schema. Not DGP. Not R package code. Not generation specs.
- `steno-aarhus/registers-guide` was not modified.
