# Guide advice: empty code systems (for Ole)

**Not a registers-guide PR.** Schema notes live in fiktive. Ole decides any further guide YAML change.

Schema tip context: `steno-aarhus/registers-guide` @ `34230a4` (post-`8a014cf8`; includes cancer / mfr / lab_dm_forsker, `one_row_per`, `values_from`, `lpr2_psychiatric`).

---

## Empty-on-purpose catalogues

These stay empty in the guide YAML on purpose (do **not** paste WHO / WHOCC / sksr into YAML):

| id | Why empty |
|---|---|
| `icd10` | Full WHO ICD-10 is huge; fiktive samples WHO ICD-10 2019 then applies Danish `D` prefix for LPR |
| `atc` | Full WHOCC ATC/DDD is huge; fiktive samples WHOCC Oslo (`atcddd.fhi.no`) — **not** `decoder::atc` |
| `sks` | Full SKS is huge; fiktive samples `sksr::SKS_labels` |
| `hfaudd` | Large education classification; link out |
| `kom` | Linked out to DST amt-kom CSV (see below) |
| `kont_type` | SKS admin codes; sample via sksr / published SKS, not a stub list as SoT |

Keep `enumerated: false` and `lookup: null` (or absent) for the clinical ones.

### Machine-readable shape (already in guide tip)

Tip `34230a4` already exposes this on the empty systems — **use it; do not invent a parallel `external_source` field**:

```yaml
enumerated: false
values_complete: false
labels_complete: false
values_from:
  kind: package   # or csv | none
  candidates: [...]   # packages; verified: false until checked
  # or for kom:
  # kind: csv
  # url: "https://www.dst.dk/...amt-kom..."
  # code_column / label_column / level: 2
lookup: null
```

fiktive should honour `values_from`:
- `kind: package` → use only **product-locked** or `verified: true` catalogues (WHO ICD-10 + D, WHOCC ATC, sksr). Ignore unverified `decoder` candidates.
- `kind: csv` → load that CSV (`kom`).
- `kind: none` → SCHEMA GAP or documented noise exception.

Optional prose `why_empty` / `reader_note` is fine; it is not a second machine API.

SCHEMA GAP remains for **undocumented structure**, not for “we refused to copy WHO into YAML.”

---

## `kom` exception

Guide already points `values_from` at DST’s amt-kom CSV (level 2 municipalities; includes pre/post-2007 codes). fiktive should load that CSV at runtime while `lookup` stays empty. Do **not** hand-write a 98-code stub as SoT.

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

Structure only — no prevalences, no DGP. `plausible: true` ≠ DST source.

---

## Still missing from YAML (registers)

Present now: **cancer**, **mfr**, **lab_dm_forsker** (lab id is `lab_dm_forsker`, not `lab`).

Still absent (do not invent): **IND** (person income), **DREAM**, **BFL**.

See also [`notes/PLAN.md`](PLAN.md) (catch-up 2026-09-06).
