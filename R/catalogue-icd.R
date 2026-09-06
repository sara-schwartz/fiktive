# WHO ICD-10 (plain) sampling via codeCollection::ICD10Koodit.
# Danish LPR D-prefixed diagnoses use sksr Prefix dia (icd10_sks), not this module.

.fiktive_icd_stamp <- new.env(parent = emptyenv())

icd10_who_form <- function(codes) {
  codes <- gsub("[[:space:].]+", "", as.character(codes))
  codes <- toupper(codes)
  # Plain WHO: letter + digits (E119). Reject Danish SKS D+letter (DE119).
  codes <- codes[grepl("^[A-Z][0-9]{2}[0-9A-Z]*$", codes)]
  codes[!grepl("^D[A-Z]", codes)]
}

load_icd10koodit_codes <- function() {
  if (isTRUE(getOption("fiktive.icd10koodit_disable"))) {
    return(character())
  }
  if (!requireNamespace("codeCollection", quietly = TRUE)) {
    return(character())
  }
  d <- tryCatch(codeCollection::ICD10Koodit, error = function(e) NULL)
  if (is.null(d) || !nrow(d)) {
    return(character())
  }
  col <- if ("Koodi" %in% names(d)) {
    "Koodi"
  } else if ("ICD10" %in% names(d)) {
    "ICD10"
  } else {
    names(d)[[1]]
  }
  unique(icd10_who_form(d[[col]]))
}

sample_icd10_who_codes <- function(n) {
  n <- as.integer(n)[[1]]
  codes <- load_icd10koodit_codes()
  if (!length(codes)) {
    schema_gap(
      "plain WHO ICD-10 codes without codeCollection::ICD10Koodit",
      "codeCollection::ICD10Koodit (values_from package); never sksr dia / D-prefix for code_system icd10"
    )
  }
  .fiktive_icd_stamp$catalogue <- "codeCollection::ICD10Koodit"
  .fiktive_icd_stamp$version <- as.character(utils::packageVersion("codeCollection"))
  sample(codes, n, replace = TRUE)
}

stamp_icd10_who_catalogue <- function(tbl) {
  if (is.null(tbl) || !nrow(tbl)) {
    return(tbl)
  }
  attr(tbl, "catalogue") <- .fiktive_icd_stamp$catalogue %||% NA_character_
  attr(tbl, "catalogue_version") <- .fiktive_icd_stamp$version %||% NA_character_
  tbl
}
