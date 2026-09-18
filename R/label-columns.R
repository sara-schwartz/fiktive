# Attaches schema labels as a column attribute, the same convention as
# haven/labelled use for SPSS/Stata imports (RStudio's Data Viewer and
# str() both pick up a "label" attribute automatically). Deliberately an
# attribute, not a rename: fiktive's whole point is rehearsing analysis
# code against the real register's own column names, and renaming them
# would mean code written against fiktive's data can't run unmodified
# against the real delivery. This adds readability without touching a
# single column name.

#' Attach human-readable labels to a generated table's columns
#'
#' Danish register columns have real names like `civst`, `hfaudd`, or KKH's
#' `g03011` — the second kind meaningless without a codebook. [codebook()]
#' already surfaces registers-guide's/fiktive's own label metadata as a
#' lookup table; `label_columns()` attaches that same text as a `"label"`
#' attribute directly on each matching column of an already-generated
#' table, so it travels with the data (RStudio's Data Viewer and `str()`
#' show it automatically) instead of living in a separate lookup.
#'
#' Column names are never changed. A column fiktive already understands
#' well enough to explain isn't necessarily one you should rename it to —
#' rehearsed analysis code has to run unmodified against the real
#' register's own names later, so renaming stays something you do
#' yourself, consistently, on both fake and real data, if you do it at
#' all. This only adds metadata.
#'
#' @param data A table from [generate_register()], [generate_registers()],
#'   or [generate_custom_register()].
#' @param schema Schema from [load_registers_schema()].
#' @param register The schema register id `data` came from, e.g. `"bef"`
#'   or `"kkh_journal"`.
#' @param lang `"en"` (default) or `"da"` -- which label to prefer. Falls
#'   back to the other language for a column that only has one.
#'
#' @return `data`, unchanged apart from a `"label"` attribute set on each
#'   column the schema documents a label for.
#' @export
label_columns <- function(data, schema, register, lang = c("en", "da")) {
  lang <- match.arg(lang)
  cb <- codebook(schema, register)
  primary <- if (identical(lang, "en")) cb$label_en else cb$label_da
  fallback <- if (identical(lang, "en")) cb$label_da else cb$label_en
  label <- ifelse(!is.na(primary), primary, fallback)
  for (i in seq_len(nrow(cb))) {
    name <- cb$name[[i]]
    if (is.na(label[[i]]) || !name %in% names(data)) {
      next
    }
    attr(data[[name]], "label") <- label[[i]]
  }
  data
}
