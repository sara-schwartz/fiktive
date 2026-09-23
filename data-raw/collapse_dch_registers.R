# Collapses the 27 separate KKH/KKHNG register YAMLs (one per real SAS
# dataset in the source catalogues) into two combined registers, "dch" and
# "dchng", one row per person each -- so a user calls
# generate_register("dch", ...) once instead of 8 (or 19) separate calls.
#
# Safe to merge: every one of the 27 registers is one_row_per: person with
# join_keys: [pnr] (confirmed no grain mismatch), and there are zero
# duplicate non-pnr column ids within the 8 KKH registers or within the 19
# KKHNG registers (confirmed by direct check before this script was
# written) -- so nothing gets silently overwritten by the merge.
#
# Each column keeps a new `dataset` field recording which real SAS
# dataset it came from (the old register's own id, minus the kkh_/kkhng_
# prefix -- e.g. "journal", "ffq_gpd", "afledte") -- so collapsing the
# registers doesn't lose the real per-dataset structure, just the need to
# call generate_register() once per dataset. codebook() surfaces this
# field so `codebook(schema, "dch")` still shows which real table each
# column is from.
#
# Only reads/writes the already-bundled inst/extdata/dch-schema YAML files
# (variable name, type, label, per the approved KKH/DCH data-sharing
# scope) -- does not touch the original source .xlsx catalogues, which
# aren't part of this repo.
#
# One-time migration, already run: the 27 per-dataset YAMLs this script
# reads no longer exist (this script deleted them as it wrote dch.yaml/
# dchng.yaml). Kept as a record of how the two bundled registers were
# derived, not meant to be re-run as-is -- there's nothing left to
# collapse. If the underlying data ever needs rebuilding from scratch, the
# starting point is the KKH/KKHNG variable catalogues (see the deleted
# data-raw/build_kkh_schema.R in git history for how those were first
# turned into per-dataset YAMLs), not this script.

library(yaml)

in_dir <- "inst/extdata/dch-schema/registers"
out_dir <- in_dir

collapse <- function(prefix, out_id, out_name) {
  files <- list.files(in_dir, pattern = paste0("^", prefix, "_.*\\.ya?ml$"), full.names = TRUE)
  pnr_col <- NULL
  columns <- list()
  for (f in files) {
    spec <- yaml::read_yaml(f)
    stopifnot(identical(spec$one_row_per, "person"), identical(as.character(spec$join_keys), "pnr"))
    dataset <- sub(paste0("^", prefix, "_"), "", spec$id)
    for (col in spec$columns) {
      if (identical(col$id, "pnr")) {
        pnr_col <- col
        next
      }
      col$dataset <- dataset
      columns[[length(columns) + 1L]] <- col
    }
  }
  spec <- list(
    id = out_id,
    name = out_name,
    one_row_per = "person",
    join_keys = list("pnr"),
    columns = c(list(pnr_col), columns)
  )
  yaml::write_yaml(spec, file.path(out_dir, paste0(out_id, ".yaml")), column.major = FALSE)
  file.remove(files)
  cat(out_id, ":", length(columns), "columns from", length(files), "real datasets ->",
      file.path(out_dir, paste0(out_id, ".yaml")), "\n")
}

collapse("kkh", "dch", "Diet, Cancer and Health (DCH)")
collapse("kkhng", "dchng", "Diet, Cancer and Health - Next Generations (DCH-NG)")
