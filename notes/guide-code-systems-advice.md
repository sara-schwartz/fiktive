# Guide advice: empty code systems (for Ole)

**Not a registers-guide PR.** Schema notes live in fiktive. Ole decides any guide YAML change.

Schema HEAD context: live `steno-aarhus/registers-guide` (post-`8a014cf8`; includes cancer / mfr / lab_dm_forsker).

---

## Empty-on-purpose catalogues

These six stay empty in the guide YAML on purpose (do **not** paste WHO / WHOCC / sksr into YAML):

| id | Why empty |
|---|---|
| `icd10` | Full WHO ICD-10 is huge; fiktive samples WHO ICD-10 2019 then applies Danish `D` prefix for LPR |
| `atc` | Full WHOCC ATC/DDD is huge; fiktive samples WHOCC Oslo (`atcddd.fhi.no`) |
| `sks` | Full SKS is huge; fiktive samples `sksr::SKS_labels` |
| `hfaudd` | Large education classification; link out |
| `kom` | **Exception below** — prefer enum from DST amt-kom CSV |
| `kont_type` | SKS admin codes; sample via sksr / published SKS, not a stub list as SoT |

Keep `enumerated: false` and `lookup: null` (or absent) for the clinical ones.

### Machine-readable reason (proposed guide fields)

fiktive (and the guide renderer) should be able to read **why** a code system is empty without prose archaeology. Proposed optional fields on `code-systems/*.yaml`:

```yaml
enumerated: false
lookup: null
external_source:
  kind: who_icd10 | whocc_atc | sksr | dst_csv | other
  url: "https://..."          # canonical published catalogue
  note: "fiktive samples full catalogue at runtime; YAML is not SoT"
why_empty: "catalogue too large to vendor; see external_source"
```

SCHEMA GAP remains for **undocumented structure**, not for “we refused to copy WHO into YAML.”

---

## `kom` exception

Enumerate the **98** post-2007 municipalities from DST’s published amt-kom / KOMMUNE classification CSV (not NUTS, not a handwritten subset). Put the full lookup in `kom.yaml` when Ole fills it. Until then fiktive may load the same CSV itself if the schema still has `enumerated: false`.

---

## Optional `sample_values` (guide aids only)

20–50 **real** published codes may appear as `sample_values` for guide examples.

- They are **not** the source of truth for generation.
- fiktive still samples the full WHO ICD-10 / WHOCC ATC / sksr catalogues for clinical columns.
- Never treat the stub list as the emission universe.

---

## Optional `value_domain` on numeric / date keys

Welcome on columns where generation needs a range without inventing epidemiology, e.g.:

```yaml
value_domain:
  min: 0
  max: 120
  # or for dates:
  # from: 1900-01-01
  # to: 2026-12-31
```

Structure only — no prevalences, no DGP.

---

## Still missing from YAML (registers)

Present now: **cancer**, **mfr**, **lab_dm_forsker** (lab id is `lab_dm_forsker`, not `lab`).

Still absent (do not invent): **IND** (person income), **DREAM**, **BFL**.

See also [`notes/PLAN.md`](PLAN.md) (catch-up 2026-09-06).
