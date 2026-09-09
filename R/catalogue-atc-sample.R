# ATC sampling: prefer codeCollection::ATCKoodit (WHO-form), else WHOCC dump.

.fiktive_atc_stamp <- new.env(parent = emptyenv())

atc_level5 <- function(codes) {
  codes <- gsub("\\s+", "", as.character(codes))
  codes <- toupper(codes)
  # WHO ATC level 5: letter + 2 digits + 2 letters + 2 digits (e.g. C09AA05)
  codes[grepl("^[A-Z][0-9]{2}[A-Z]{2}[0-9]{2}$", codes)]
}

load_atckoodit_codes <- function() {
  if (isTRUE(getOption("fiktive.atckoodit_disable"))) {
    return(NULL)
  }
  if (!requireNamespace("codeCollection", quietly = TRUE)) {
    return(NULL)
  }
  d <- tryCatch(codeCollection::ATCKoodit, error = function(e) NULL)
  if (is.null(d) || !nrow(d)) {
    return(NULL)
  }
  col <- if ("ATC" %in% names(d)) "ATC" else if ("atc" %in% names(d)) "atc" else names(d)[[1]]
  atc_level5(d[[col]])
}

sample_atc_codes <- function(n) {
  n <- as.integer(n)[[1]]
  codes <- load_atckoodit_codes()
  if (!length(codes)) {
    # Fallback: WHOCC dump via existing loader if available
    if (exists("load_whocc_atc_catalogue", mode = "function", inherits = TRUE)) {
      cat_tbl <- tryCatch(load_whocc_atc_catalogue(required = FALSE), error = function(e) NULL)
      if (!is.null(cat_tbl) && length(cat_tbl$codes)) {
        codes <- atc_level5(cat_tbl$codes)
        .fiktive_atc_stamp$catalogue <- "WHOCC"
        .fiktive_atc_stamp$version <- cat_tbl$version %||% NA_character_
      }
    }
  } else {
    .fiktive_atc_stamp$catalogue <- "codeCollection::ATCKoodit"
    .fiktive_atc_stamp$version <- as.character(utils::packageVersion("codeCollection"))
  }
  if (!length(codes)) {
    schema_gap(
      "ATC codes without a WHO-form catalogue",
      "codeCollection::ATCKoodit or FIKTIVE_WHOCC_ATC; never sprintf; never decoder::atc"
    )
  }
  sample(codes, n, replace = TRUE)
}

stamp_atc_catalogue <- function(tbl) {
  if (is.null(tbl) || !nrow(tbl)) {
    return(tbl)
  }
  attr(tbl, "catalogue") <- .fiktive_atc_stamp$catalogue %||% NA_character_
  attr(tbl, "catalogue_version") <- .fiktive_atc_stamp$version %||% NA_character_
  tbl
}
