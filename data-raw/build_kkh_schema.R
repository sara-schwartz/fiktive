# Builds inst/extdata/kkh-schema/registers/*.yaml from the two KKH/KKHNG
# variable catalogues. Not run automatically -- source it by hand whenever
# the source .xlsx files change. The .xlsx files themselves are NOT part of
# the package and are not committed; only the derived YAML is.
#
# Scope, per Lisbeth Schade Hansen (KKH/DCH data coordinator,
# dchdata@cancer.dk) email approval: "udelukkende metadata: variabelnavnene,
# type, samt de tilhorende danske og engelske labels" -- variable name, type,
# and the Danish/English labels only. Nothing else from the source files
# (Include, Vars requested, Note, real data) goes into fiktive. This is
# fiktive-only: none of it is fetched by or written to
# steno-aarhus/registers-guide, whose live schema stays DST-only.
#
# Grain: every register here is one_row_per = "person" -- these are baseline
# cohort tables (participants measured once, not repeated snapshots), which
# is why generate_snapshot()'s person-grain fix (see R/generate.R) exists.
#
# Two judgment calls, documented here so they're correctable later rather
# than buried in generated output:
#   1. KKHNG's raw `dataset` column has 27 near-empty groups
#      (`_70_kkhng_sca_v1`..`v27`, 1 row each) whose content is unrelated
#      (questionnaire items, SECA device readings, blood biomarkers) -- no
#      SAS files were available to check whether these are really 27
#      distinct tables or just catalogue-revision tags. Collapsed into one
#      combined register, kkhng_sca, as the defensible default absent
#      better information.
#   2. Two placeholder dataset values, "??" (1 row: time_origin) and
#      "done_all" (6 rows: KKHNGID + 5 date columns), don't name a real
#      table. Bundled into a new kkhng_admin register (visit-tracking /
#      administrative fields), rather than silently attached to an
#      unrelated real table.

library(readxl)
library(dplyr)
library(yaml)

kkh_path   <- "/Users/saraschwartz/Desktop/DST_help/_ignore/kkh/10_KKH_BSL_VarCatalogue_2024_ss (1).xlsx"
kkhng_path <- "/Users/saraschwartz/Desktop/DST_help/_ignore/kkh/20_KKHNG_BSL_VarCatalogue_2026_ss (1).xlsx"
out_dir    <- "inst/extdata/kkh-schema/registers"

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# `dataset` and `Registry` swap column position between the two files --
# always read by header name (both already do, via read_excel + $dataset).
kkh   <- read_excel(kkh_path,   sheet = "KKH_datasets")
kkhng <- read_excel(kkhng_path, sheet = "KKH_datasets")

na_if_blank <- function(x) {
  x <- trimws(as.character(x))
  ifelse(is.na(x) | !nzchar(x), NA_character_, x)
}

# Regroup KKHNG's placeholder/fragment dataset values into the two
# documented judgment calls above. Applied before any other processing so
# everything downstream just sees clean, real dataset names.
regroup_kkhng_dataset <- function(dataset) {
  dataset <- ifelse(grepl("^_70_kkhng_sca_v[0-9]+$", dataset), "sca", dataset)
  dataset <- ifelse(dataset %in% c("??", "done_all"), "admin", dataset)
  # Strip a leading "_70_" (an internal batch/version prefix, not part of
  # the table's real name) from any dataset name that still has one.
  sub("^_?70_", "", dataset)
}

prepare <- function(df, prefix, regroup = identity) {
  df %>%
    transmute(
      dataset = regroup(dataset),
      id = tolower(trimws(Variable)),
      type_raw = trimws(Type),
      label_da = na_if_blank(Label_dk),
      label_en = na_if_blank(Label_eng)
    ) %>%
    mutate(
      # SAS stores dates as numeric -- these specific columns are known
      # (by name pattern + catalogued Num type) to actually be dates, not
      # plain numbers. See header comment: rule is name ends in DATE/DATO
      # (case-insensitive) AND catalogued type is Num. FSDATO_C is Char and
      # explicitly labelled "(Character variable)", so it's correctly left
      # as character by this rule, not reclassified.
      is_date = type_raw == "Num" & grepl("(date|dato)$", id, ignore.case = TRUE),
      type = case_when(
        is_date ~ "date",
        type_raw == "Num" ~ "numeric",
        type_raw == "Char" ~ "character",
        TRUE ~ NA_character_
      ),
      register_id = paste0(prefix, "_", tolower(dataset))
    )
}

kkh_cols   <- prepare(kkh,   "kkh")
kkhng_cols <- prepare(kkhng, "kkhng", regroup = regroup_kkhng_dataset)

all_cols <- bind_rows(kkh_cols, kkhng_cols)

bad_type <- all_cols %>% filter(is.na(type))
if (nrow(bad_type)) {
  stop("Unrecognised Type value(s) -- fix before building YAML:\n",
       paste(capture.output(print(bad_type)), collapse = "\n"))
}

# One YAML per register_id, matching registers-guide's own column shape
# (id/name/type/label) so codebook() and the generic column-fill machinery
# work on these with no extra code.
register_ids <- sort(unique(all_cols$register_id))
for (rid in register_ids) {
  cols <- all_cols %>% filter(register_id == rid)
  # pnr is fiktive's own join key (inherited from the shared population),
  # not one of the approved KKH/KKHNG variables -- unlike
  # generate_custom_register()'s build_custom_spec(), the schema-driven
  # emit_schema_table() only ever emits columns actually listed here, so
  # join_keys alone would silently produce a table with no pnr at all.
  # Every real DST register's own YAML lists pnr as a column for the same
  # reason; matching that convention explicitly rather than relying on it
  # being implied by join_keys.
  pnr_col <- list(id = "pnr", name = "pnr", type = "character", role = "join_key")
  spec <- list(
    id = rid,
    name = unique(cols$dataset)[[1]],
    one_row_per = "person",
    join_keys = list("pnr"),
    columns = c(list(pnr_col), lapply(seq_len(nrow(cols)), function(i) {
      col <- list(id = cols$id[[i]], name = cols$id[[i]], type = cols$type[[i]])
      if (!is.na(cols$label_da[[i]]) || !is.na(cols$label_en[[i]])) {
        col$label <- list(
          da = if (is.na(cols$label_da[[i]])) NULL else cols$label_da[[i]],
          en = if (is.na(cols$label_en[[i]])) NULL else cols$label_en[[i]]
        )
      }
      col
    }))
  )
  write_yaml(spec, file.path(out_dir, paste0(rid, ".yaml")), column.major = FALSE)
}

cat(length(register_ids), "register YAML files written to", out_dir, "\n")
cat(paste(register_ids, collapse = "\n"), "\n")
