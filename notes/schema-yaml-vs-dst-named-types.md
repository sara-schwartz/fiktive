# YAML `type` vs named DST storage class

Notes for Ole. **Not schema. Not DGP.** Do not copy this into `steno-aarhus/registers-guide` from this PR; guide fills are Ole's.

Schema SHA (when YAML was quoted): `8a014cf80d2682699141150f58a2330040177422`  
Companion audit: [`notes/schema-missing-types.md`](schema-missing-types.md) (0 missing YAML `type` keys).

Allowed YAML types: `character | factor | date | datetime | integer | numeric`. YAML has **no length** field.

---

## 1. ForskningVariabellister does not document storage class

24 register YAML files, 443 columns, **zero** missing `type`.

Many columns have `verified_on: 2026-09-01` and `source_type: dst_variable_list`. DST ForskningVariabellister pages have **no type column**. Their table is:

`Variabel | TIMES | Højkvalitetsdokumentation | Label | years`

Index: https://www.dst.dk/extranet/forskningvariabellister/

Those YAML `type` values are **not** DST storage-class documentation. They are schema assertions. A `dst_variable_list` provenance on a column does not mean DST published `integer` / `character` / `date` on that page.

---

## 2. Named DST storage classes (public rulebook + LMDB handbook)

Source: [Data fra dataleverandører til grunddatabanken](https://www.dst.dk/da/TilSalg/data-til-forskning/generelt-om-data/data-fra-dataleverandoerer-til-grunddatabanken)

Named there (do not generalise beyond the name DST used):

| DST name | DST wording |
|---|---|
| PNR | CHAR 10 |
| RECNUM | CHAR 16 |
| ADRESSE_ID | CHAR 8 |
| KØN | karakter |
| ALDER | karakter |
| KOM | karakter |
| CIVILSTAND | karakter |
| mængder / summer / beløb | numerisk |
| dates vs timestamp | (rulebook distinguishes the two; no per-column map here) |
| TIMES VERSION | numerisk længde 2 with leading zeros |

LMDB handbook (named column EKSD): Format Num YYMMDD, length 4.

YAML `pnr` / `recnum` / `adresse_id` are `character` with **no length**. That is not a type conflict with CHAR; length is a SCHEMA GAP in the YAML, not a fill from this notes file.

---

## 3. YAML vs named DST — conflicts only

Do not invent types. Only rows where a **named** DST storage class disagrees with the YAML `type` at this SHA.

| register | column | YAML `type` | named DST | DST wording | source | action |
|---|---|---|---|---|---|---|
| `vnds_ind` | `koen` | `integer` | KØN | karakter | [rulebook](https://www.dst.dk/da/TilSalg/data-til-forskning/generelt-om-data/data-fra-dataleverandoerer-til-grunddatabanken); YAML `schema/registers/vnds_ind.yaml` | SCHEMA GAP: YAML integer vs DST karakter. Do not silently change. |
| `vnds_ud` | `koen` | `integer` | KØN | karakter | same rulebook; YAML `schema/registers/vnds_ud.yaml` | same |
| `vnds_ind` | `version` | `character` | TIMES VERSION | numerisk længde 2 with leading zeros | same rulebook; YAML `schema/registers/vnds_ind.yaml` | SCHEMA GAP: YAML character vs DST numerisk. Leading zeros would be lost if stored as integer. |
| `vnds_ud` | `version` | `character` | TIMES VERSION | numerisk længde 2 with leading zeros | same rulebook; YAML `schema/registers/vnds_ud.yaml` | same |
| `lmdb` | `eksd` | `date` | EKSD | Format Num YYMMDD length 4 | LMDB handbook; YAML `schema/registers/lmdb.yaml` | SCHEMA GAP: YAML date vs DST numeric YYMMDD. Semantic date vs storage class. |

No other named-vs-YAML type conflicts are recorded here. Remaining columns: **UNKNOWN from public DST**.

---

## 4. Do not apply ALDER CHAR 3 by name resemblance

DST names **ALDER**. Do **not** apply CHAR 3 (or `character`) to columns that are not named `ALDER`:

- `lmdb.aldr` (YAML `integer`)
- `alder_ult_ink`
- `alder_haend` (YAML `integer` on `vnds_ind` / `vnds_ud`)
- `alder_ult` (YAML `integer` on `vnds_ind` / `vnds_ud`)

Name resemblance is not a source.

---

## 5. What this is not

- Not a patch for `registers-guide`. Ole decides guide changes.
- Not a generator spec. Companion generation, if any, lives in fiktive elsewhere.
- Not a claim that YAML `type` is wrong wherever it is `dst_variable_list`.

**Next option for the UNKNOWN remainder:** SAS `CONTENTS` (or equivalent) on the researcher machine. Not public.
