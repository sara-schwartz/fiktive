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

```r
library(fiktive)

schema <- load_registers_schema()
schema$schema_commit

pop <- generate_background_population(n = 100, seed = 1, schema = schema)

bef <- generate_register(
  "bef",
  population = pop,
  schema = schema,
  from = as.Date("2008-01-01"),
  to = as.Date("2009-12-31"),
  seed = 1
)
```
