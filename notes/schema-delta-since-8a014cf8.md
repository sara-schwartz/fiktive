# Schema delta since `8a014cf8` — fiktive impact

**Date:** 2026-09-06 (Europe/Berlin)  
**Guide (read-only):** [steno-aarhus/registers-guide](https://github.com/steno-aarhus/registers-guide)  
**Baseline:** `8a014cf80d2682699141150f58a2330040177422` (2026-09-01)  
**Tip (rebase pin):** `34230a4aaeb37a5919876777e576f7032b5cdc95` (2026-09-06)  
**Last schema-contract commit under that tip:** `b1135b1b5da84e65bfcf4081baa664e8216e72e3` (`one_row_per`, `values_from`, `lpr2_psychiatric`)  
**Fiktive assessed against:** `main` @ `ff588593` and PR [#9](https://github.com/sara-schwartz/fiktive/pull/9) @ `f65e77c`  
**Constraint:** notes only under `notes/` on fiktive. Guide untouched. Package owns PR #9 catalogue wire.

---

## Catalogue locks (correct — do not blur)

| Domain | fiktive samples | Not |
|---|---|---|
| ICD-10 (LPR diagnoses) | **WHO ICD-10 2019**, then Danish **`D` prefix** (`E11` → `DE11`) | `decoder`, `sksr`, D+random, unprefixed WHO in LPR |
| ATC (LMDB) | **WHOCC Oslo** (`atcddd.fhi.no`) only | `decoder::atc`, sprintf pattern noise |
| SKS procedures | `sksr::SKS_labels` (`K` / Prefix `opr` for surgery) | ICD-10, invented SKS |
| NPU (lab) | LabTerm when generating `lab_dm_forsker` | Homemade lists |

Soft conflict: schema `icd10` / `atc` `values_from.candidates` may list `decoder` / `codeCollection` with `verified: false`. That is advisory only — **locked catalogues above win**.

---

## Compact impact table

| area | change | fiktive needs update? | notes |
|---|---|---|---|
| Tip / pin | Tip `34230a4` (not `6fba68b`). Schema contract at `b1135b1`. | **Yes** | Docs/pins → `34230a4` (or stamp live HEAD). Do not freeze to `8a014cf8` / `6fba68bd`. |
| `one_row_per` | Required grain field. Vocab: `person` \| `person_reference_date` \| `event_from_person` \| `expand_from_parent` \| `household_year` \| `unknown`. | **Yes** | Prefer reading YAML `one_row_per` over inventing grains. Examples: `bef`=`person_reference_date`, `lmdb`/`lpr_adm`/`cancer`/`lab_dm_forsker`=`event_from_person`, `lpr_diag`=`expand_from_parent`, `faik` still `unknown` (`household_year` unused). |
| `values_from` | Required when `enumerated: false`. Kinds: `csv` \| `package` \| `none`. | **Yes (loader/policy)** | Empty clinical systems stay empty on purpose. |
| `kom` | Still not inline-enumerated. `values_from.kind: csv` → DST amt-kom URL (level 2). | **Yes (runtime)** | Load CSV via schema URL; do not invent 98 codes in fiktive YAML. |
| Families | +`lpr2_psychiatric` for `t_psyk_*`. | **Yes (map)** | Closes earlier no-family gap; psych still its own pair / not STEP 4. |
| Register inventory | 24 → **27** (+`cancer`, `mfr`, `lab_dm_forsker`). | **Yes (dispatch)** | Not-implemented until grain exists. |
| `cancer` | SDS; tumour-level; join `k_cprnr`; `one_row_per: event_from_person`. | **Yes — not implemented** | ICD via WHO→D lock when generated. |
| `mfr` | Birth; key `cpr_barn`; mother+child on one row. | **Yes — SCHEMA GAP (grain nuance)** | YAML may say event; child key is not plain person-event. Do not invent. |
| `lab_dm_forsker` | SDS; `patient_cpr` / `samplingdate` / `analysiscode`. | **Yes — not implemented** | NPU external (LabTerm). Not `pnr`/`npu`. |
| `koen` +`9` | Lookup 1/2/**9**. | **Yes** | Fixtures/tests still {1,2}. |
| `socio13` / `herkomst` | Enumerated DST lookups; herkomst on BEF. | **Yes** | Refresh fixtures. |
| `pattype` | **4** codes `0–3` (not 0–5). | **Yes — Package / PR #9** | |
| `diagtype` | **6** codes A,B,C,G,H,M. | **Yes — Package / PR #9** | |
| `borger_koen` | No published value set. | **Yes — SCHEMA GAP** | Do **not** invent; do **not** map from pop `koen`. |
| Provenance | `server_verified` removed → `unverified`. | **Yes (policy)** | Must not rely on `server_verified`. |
| IND / DREAM / BFL | Still absent from YAML. | **No invent** | Still missing. |

---

## Material schema commits after baseline

| SHA | Summary |
|---|---|
| `b7e3f443` | Full columns for 24 + cancer/mfr/lab_dm_forsker |
| `70813289` | pattype/diagtype Kodeark; +indm/oprart/sex_lpr |
| `707cfcdd` | Cancer coverage; psych coverage; sysi/sssy notes |
| `9ac9d006` / `6fba68bd` | borger_koen undocumented / settled |
| `de15fb21` | Label/period repairs; ICD/ATC chains |
| `032514c6` | socio13/herkomst; kom amt-kom; koen +9 |
| `0b744309` | drop server_verified / guide_prose |
| `b1135b1b` | **`one_row_per`**, **`values_from`**, **`lpr2_psychiatric`** |
| `55b63e8c` / `34230a4` | Regenerated tables; tip content pass |

---

## Recommended follow-ups (fiktive only)

1. Re-pin docs/default stamp to tip **`34230a4`** (or live HEAD); never `8a014cf8` / `6fba68bd` as “current”.  
2. Prefer `one_row_per` + `values_from` from live YAML when generating.  
3. Package owns PR #9 WHO ICD-10→D + WHOCC ATC + sksr SKS wire — Schema does not push that branch.  
4. Leave cancer/mfr/lab_dm_forsker not-implemented until Package/Methods design grains + catalogues.  
5. Fixtures: koen+9, socio13, herkomst, pattype 0–3, diagtype 6; borger_koen SCHEMA GAP.  
6. Never vendor mega ICD/ATC/SKS/NPU lists into guide YAML.

## Out of scope

No writes to registers-guide. No catalogue commits on `feat/step-4-lpr2-lpr3` from Schema.
