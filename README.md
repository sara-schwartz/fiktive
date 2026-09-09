# fiktive

Fictitious Danish Register Data

Generate structurally valid fictitious Danish register data, for writing and checking analysis code outside Statistics Denmark.

Code is MIT. Generated datasets are CC-BY-4.0. This package creates data; it does not extract rows from real registers.

## Licenses

- Package code: MIT
- Generated datasets: [CC-BY-4.0](https://creativecommons.org/licenses/by/4.0/)

This package **creates** fictitious tables. It does not extract from real Danish registers.

## Schema

Structure comes from the live [`steno-aarhus/registers-guide`](https://github.com/steno-aarhus/registers-guide) schema directory (`schema/registers/`, `schema/code-systems/`, `schema/families/`). Each call to `load_registers_schema()` stamps the git commit used as `schema_commit`. The YAML is consumed at runtime and is not vendored into this package as the source of truth. Pass a local schema root (a directory that contains `registers/`) for offline use.

## Prior art

[fakeregs](https://github.com/steno-aarhus/fakeregs) by Anders Aasted Isaksen is prior art for fictitious Danish register data. fiktive is **not** a fakeregs clone: people are a stable spine (not a yearly random pool), columns are driven from the live schema, and this package does not copy fakeregs architecture.

## Usage

Pick the registers you need (nothing is dumped by default), generate, write CSV, then join.

```r
library(fiktive)

schema <- load_registers_schema()
schema$schema_commit

pop <- generate_background_population(n = 100, seed = 1, schema = schema)

# Opt-in batch: registers= is required (never a silent dump of all schema ids)
tables <- generate_registers(
  registers = c("bef", "lmdb"),
  population = pop,
  schema = schema,
  from = as.Date("2008-01-01"),
  to = as.Date("2009-12-31"),
  seed = 1
)

# Default on-disk format is CSV; parquet / hive year= are opt-in
write_register(tables$bef, "out/bef")
write_registers(tables, "out/registers")

# Join on shared population keys
dplyr::inner_join(tables$bef, tables$lmdb, by = "pnr")
```

### LPR parent then child

LPR diagnoses/procedures expand from the **same** contact table that was written. Generate the parent contact register first (or include it in `registers=`), then the child.

```r
lpr <- generate_registers(
  registers = c("lpr_adm", "lpr_diag"),
  population = pop,
  schema = schema,
  from = as.Date("2010-01-01"),
  to = as.Date("2010-12-31"),
  seed = 1
)
# lpr$lpr_diag joins to lpr$lpr_adm on recnum (schema join_keys)
```

### Custom / external register (structure only)

For a table that is not in the guide YAML, describe columns with a CSV (or tibble) of `name`, `type`, and optional `min` / `max` / `values`. No raw rows; no coefficients in the column CSV.

```r
# columns.csv:
# name,type,min,max,values
# score,integer,0,10,
# grp,character,,,A|B|C

ext <- generate_custom_register(
  id = "ext_score",
  one_row_per = "person_reference_date",
  join_keys = "pnr",
  columns = "columns.csv",
  population = pop,
  schema = schema,
  from = as.Date("2008-01-01"),
  to = as.Date("2009-12-31"),
  seed = 1,
  cadence = "annual"
)
write_register(ext, "out/ext_score")
dplyr::inner_join(tables$bef, ext, by = "pnr")
```

Household-year customs must pass household-side `join_keys` (e.g. `familie_id`), never a silent `pnr` default. Expand-from-parent customs need an already-generated `parent` table.
