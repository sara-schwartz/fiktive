# Schema delta since `8a014cf8` — fiktive impact

**Date:** 2026-09-06 (Europe/Berlin)  
**Guide (read-only):** [steno-aarhus/registers-guide](https://github.com/steno-aarhus/registers-guide)  
**Baseline (evaluation pin):** `8a014cf80d2682699141150f58a2330040177422` (2026-09-01)  
**Last schema-touching commit:** `6fba68bded00af92fa8488929e59baad18765b5c` (2026-09-04) — *confirmed*  
**Repo `main` HEAD when read:** `926b939a2645af60c50ad8a2ffcfed581c40fb62` (2026-09-05) — content/guide commits only after schema HEAD; `schema/` unchanged since `6fba68bd`  
**Fiktive assessed against:** `main` @ `ff58859318f5cc40d2725689849043a3d87eef8c` and open PR [#9](https://github.com/sara-schwartz/fiktive/pull/9) `feat/step-4-lpr2-lpr3` @ `f65e77c26917759cb52cf61c1edd828eacb1aee2`  
**Constraint:** notes only under `notes/` on fiktive. Guide untouched.

## Compact impact table

| area | change | fiktive needs update? | notes |
|---|---|---|---|
| Loader SHA pin | Live loader still resolves guide `HEAD`; PLAN says pin by SHA. Evaluation baseline was `8a014cf8`. Schema contract now lands at `6fba68bd` (repo HEAD `926b939` is content-only after that). | **Yes** | Add/keep explicit pin (option or documented default) at **`6fba68bd`**, not `8a014cf8`. Stamping `schema_commit` remains required. |
| Register inventory | 24 → **27** YAML files (`+cancer`, `+mfr`, `+lab_dm_forsker`). **835** columns total. | **Yes (dispatch)** | Unknown ids already SCHEMA GAP; known-but-unimplemented must stay `"not implemented yet"` until a grain exists. |
| `cancer` | New SDS register; tumour-level (`k_tumornr`); 35 cols; ICD-10/kom/reg; per-column coverage (2004 stage split). | **Yes — SCHEMA GAP (grain)** | Not person-event or expand-from-parent. Do **not** invent tumour grain. Catalogue: real ICD-10 external (Ole lock). |
| `mfr` | New DST birth register; one row per birth; key `cpr_barn`; 91 cols; mother+child on one row. | **Yes — SCHEMA GAP (grain)** | Birth/child key is a new grain. Not on main or PR #9. |
| `lab_dm_forsker` | New SDS lab table; keys `patient_cpr`, `samplingdate`, `analysiscode`, `value`, `unit`; coverage **2008–2025**. | **Yes — SCHEMA GAP (grain + NPU)** | Column names are `patient_cpr` / `samplingdate` / `analysiscode` (not `pnr`/`samplingdato`/`npu`). Narrower SDS table uses `cprnummer` — do not confuse. Analysis codes → external NPU catalogue; do **not** dump NPU into guide YAML. |
| Expanded columns (existing) | Large expansions post-`b7e3f443` + repairs in `de15fb21`: e.g. `akm` 10→47, `lmdb` 15→65, `lpr_adm` 19→52, `t_psyk_adm` 14→38, death-cause registers grow, `sssy`/`sysi` grow. Several LPR3 YAMLs unchanged in count. | **Partial** | Generator already walks `spec$columns`, so new non-key cols become typed noise / lookup draws automatically once schema is loaded. Grain dispatch and clinical catalogues still gate real usefulness. Fixtures on main/PR #9 are thin vs live. |
| `koen` + code `9` | Lookup `1`,`2`,`9` from DST KOEN_V1_1980 (`032514c6`). | **Yes** | Live load will sample `9`. Fixture `koen.yaml` and `test-population.R` still assert `{1,2}` only — update fixtures/tests; do not hardcode. |
| `socio13` | Now enumerated complete lookup (31 codes) from DST (`032514c6`). | **Yes** | Main AKM test double has `lookup: null` → typed noise. Live schema will sample real codes via `lookup_keys`. Refresh fixture; keep Ole lock (no giant lists invented in fiktive). |
| `herkomst` | New code system `1/2/3/9` (`032514c6`); used on BEF. | **Yes** | Was missing entirely. Fixture needed if tests cover BEF `herkomst`; otherwise live load just starts sampling. |
| `kom` | Source URL fixed **NUTS → amt-kom** (`032514c6`). Still `lookup: null` (linked-out). | **No (runtime)** | Docs/provenance only. Generator already treats empty lookup as noise / non-enumerated. |
| `pattype` | **6→4** codes (`0–3`); codes `4`/`5` removed; Kodeark source (`70813289`). | **Yes — esp. PR #9** | PR #9 fixture still has `0–5`; test expects `c_pattype %in% as.character(0:5)`. Must become `0:3` and track validity eras / `c_indm` for post-2013 ER. |
| `diagtype` | **3→6** codes (`A,B,C,G,H,M`); period caveats on G/M/C (`70813289`). | **Yes — esp. PR #9** | PR #9 fixture still A/B/G only. Update fixture; sampling from live lookup is otherwise fine. |
| `indm` / `oprart` / `sex_lpr` | New Kodeark systems; wired on `lpr_adm` (`c_indm`, `c_sex`) and procedure `c_oprart`. | **Yes — PR #9** | Will auto-draw from lookups when live schema loads. Fixtures missing; `c_sex` must **not** be conflated with BEF `koen` (coding flip 2005: `1/2` → `M/K`). |
| `borger_koen` | No published value set (`9ac9d006` / `6fba68bd`). Live: `type: character`, **no** `code_system`. | **Yes — SCHEMA GAP — PR #9 wrong** | PR #9 derives integer `borger_koen` from pop `koen` and fixture attaches `code_system: koen`. Guide forbids assuming BEF/`koen`/`sex_lpr` coding. Prefer SCHEMA GAP or opaque character noise; study sex from BEF `koen`. |
| Cause-of-death + ATC chains | `de15fb21` attaches `icd10` / `atc` on death-cause and ATC-related columns; label/period repairs (54 labels, 200 periods). | **Yes (catalogue path)** | When those registers are generated: real ICD-10 / ATC from **external** catalogues (Ole lock). Do not enlarge guide YAML. Main `dod` remains tiny (no causes); death-cause registers still unimplemented. |
| Provenance | `server_verified` and `guide_prose` removed; allowed `source_type` includes `unverified` (`0b744309`). | **Yes (policy)** | Fiktive must **not** rely on `server_verified`. No current R references found; keep it that way. Treat `unverified` as non-authoritative for generation decisions. |
| `sysi` / `sssy` | Reader notes: DST vs SDS naming systems differ (`707cfcdd`). | **No (now)** | Still unimplemented. When built, use DST column names from YAML, not esundhed aliases. |
| Psych coverage | `t_psyk_*` coverage from order list (`707cfcdd`); column growth. | **No (now)** | PR #9 correctly leaves `t_psyk_*` as not-implemented (not SCHEMA GAP). |
| Laboratory prose vs YAML | Guide pages (`43fa24d`) align names with `lab_dm_forsker` YAML. | **Docs only** | Confirms YAML column names above. |
| Ole lock (catalogues) | Real ATC / ICD-10 / SKS / NPU from external catalogues; no large lookups added to guide YAML. | **Keep** | Schema correctly leaves ATC/ICD/SKS/NPU/`kom` linked-out or non-enumerated. Fiktive must fetch catalogues at runtime (as PR #9 aims for `sksr`), never vendor giant lists into guide or package YAML. |

## Material guide commits verified (schema path after baseline)

| SHA | Summary |
|---|---|
| `b7e3f443` | Every DST-documented column for 24 registers + **cancer**, **mfr**, **lab_dm_forsker** |
| `70813289` | `pattype`/`diagtype` from Kodeark; **+indm/oprart/sex_lpr** |
| `707cfcdd` | Cancer per-column coverage; psych coverage; sysi/sssy naming note |
| `9ac9d006` | `borger_koen` undocumented |
| `6fba68bd` | `borger_koen` value set not published (settled) — **schema HEAD** |
| `de15fb21` | 54 labels + 200 periods repaired; ICD/ATC on cause-of-death & ATC chains |
| `032514c6` | socio13/herkomst from DST; kom NUTS→amt-kom; koen +`9` |
| `0b744309` | drop `server_verified` / `guide_prose` → `unverified` |
| `43fa24d` | Laboratory column naming/coverage in guide prose (not schema YAML) |
| `aa900057` / `72abe4dd` / `70f52e9` / `677e8f64` | Tooling/README/loader wording; no register-contract surprises for fiktive |

## Column-count delta (baseline → schema HEAD)

| register | baseline | head | Δ |
|---|---:|---:|---:|
| akm | 10 | 47 | +37 |
| bef | 40 | 41 | +1 |
| cancer | — | 35 | +35 |
| dod | 5 | 5 | 0 |
| dodsaars | 18 | 35 | +17 |
| dodsaarsager | 10 | 39 | +29 |
| dodsaasg | 9 | 41 | +32 |
| faik | 87 | 87 | 0 |
| lab_dm_forsker | — | 14 | +14 |
| lmdb | 15 | 65 | +50 |
| lpr_a_diagnose | 12 | 12 | 0 |
| lpr_a_kontakt | 54 | 54 | 0 |
| lpr_a_procregistrering | 20 | 20 | 0 |
| lpr_adm | 19 | 52 | +33 |
| lpr_diag | 6 | 8 | +2 |
| lpr_sksopr | 7 | 12 | +5 |
| lpr_sksube | 7 | 12 | +5 |
| mfr | — | 91 | +91 |
| sssy | 16 | 25 | +9 |
| sysi | 16 | 22 | +6 |
| t_psyk_adm | 14 | 38 | +24 |
| t_psyk_diag | 4 | 6 | +2 |
| udda | 18 | 18 | 0 |
| vnds / hist / ind / ud | 6/6/22/22 | same | 0 |

## Fiktive surface area (current)

**main implements:** snapshot `bef` / `udda` / `akm`; event-from-person `dod` / `lmdb` / `vnds`.  
**PR #9 adds:** expand-from-parent LPR2 (`lpr_adm` → diag/sksopr/sksube) and LPR3 (`lpr_a_kontakt` → diagnose/procregistrering); SKS via `sksr`; ICD-10 still SCHEMA GAP.

**Not implemented (and now in schema):** `cancer`, `mfr`, `lab_dm_forsker`, `faik`, `sssy`/`sysi`, psych LPR, VNDS successors, death-cause registers, etc.

## Recommended follow-ups (fiktive only; priority)

1. **Pin schema** default/docs to `6fba68bd` (reproducible runs); keep live-HEAD as opt-in if desired.  
2. **PR #9 fixups** before merge against live schema: `pattype` 0–3; `diagtype` A/B/C/G/H/M; stop mapping `borger_koen`←`koen`; add `indm`/`oprart`/`sex_lpr` fixtures; align `borger_koen` type to character / SCHEMA GAP.  
3. **Population/fixtures:** `koen` include `9`; `socio13`/`herkomst` lookups when testing against live-shaped doubles.  
4. **New registers:** leave `cancer` / `mfr` / `lab_dm_forsker` as not-implemented **or** explicit SCHEMA GAP until tumour / birth / lab-result grains + NPU/ICD catalogues are designed.  
5. **Never** reintroduce dependence on `server_verified`; never vendor ATC/ICD/SKS/NPU mega-lists into guide YAML.

## Out of scope this note

No code changes on `feat/step-4-lpr2-lpr3` or `feat/step-1`. No writes to registers-guide.
