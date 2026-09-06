# ATC sampling: prefer codeCollection::ATCKoodit (WHO-form), else WHOCC dump.

.fiktive_atc_stamp <- new.env(parent = emptyenv())

atc_level5 <- function(codes) {
  codes <- toupper(as.character(unlist(codes, use.names = FALSE)))
  codes <- gsub("[^A-Z0-9]", "", codes)
  codes <- codes[!is.na(codes) & nzchar(codes)]
  unique(codes[grepl("^[A-Z][0-9]{2}[A-Z]{2}[0-9]{2}$", codes)])
}

load_atckoodit_codes <- function() {
  if (isTRUE(getOption("fiktive.atckoodit_disable"))) {
    return(character())
  }
  if (!requireNamespace("codeCollection", quietly = TRUE)) {
    return(character())
  }
  d <- tryCatch(codeCollection::ATCKoodit, error = function(e) NULL)
  if (is.null(d) || !nrow(d)) {
    return(character())
  }
  col <- if ("Koodi" %in% names(d)) d$Koodi else d[[1]]
  atc_level5(col)
}

sample_atc_codes <- function(n) {
  n <- as.integer(n)
  if (length(n) != 1L || is.na(n) || n < 0L) {
    stop("`n` must be a non-negative integer.", call. = FALSE)
  }
  if (n == 0L) {
    return(character())
  }
  codes <- load_atckoodit_codes()
  source <- "codeCollection::ATCKoodit"
  version <- if (requireNamespace("codeCollection", quietly = TRUE)) {
    as.character(utils::packageVersion("codeCollection"))
  } else {
    NA_character_
  }
  if (!length(codes)) {
    cat <- load_whocc_atc_catalogue(required = TRUE)
    codes <- cat$codes
    source <- cat$source
    version <- cat$version
  }
  if (!length(codes)) {
    schema_gap(
      "WHO-form ATC catalogue unloadable",
      "codeCollection::ATCKoodit or FIKTIVE_WHOCC_ATC; never sprintf; never decoder::atc"
    )
  }
  .fiktive_atc_stamp$source <- source
  .fiktive_atc_stamp$version <- version
  sample(codes, n, replace = TRUE)
}

stamp_atc_catalogue <- function(tbl) {
  if (!"atc" %in% names(tbl) || !nrow(tbl)) {
    return(tbl)
  }
  attr(tbl, "atc_catalogue") <- .fiktive_atc_stamp$source %||% "WHO ATC"
  attr(tbl, "atc_catalogue_version") <- .fiktive_atc_stamp$version %||% NA_character_
  tbl
}
