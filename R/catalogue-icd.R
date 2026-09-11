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

sample_icd10_who_codes <- function(n, koen = NULL, age_years = NULL) {
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
  sample_icd10_coherent(codes, n, koen = koen, age_years = age_years)
}

# Definitionally-impossible ICD-10 chapters, not statistical realism: a man
# cannot carry a pregnancy/childbirth code, a woman cannot carry a male
# genital organ diagnosis, and a code from the perinatal chapter (conditions
# only ever diagnosed in the newborn period) cannot belong to someone who
# is already a year old. Deliberately narrow -- this is not an attempt at
# realistic age/sex-specific disease prevalence (see PLAN: structural noise,
# not calibrated realism), only at ruling out combinations WHO's own
# chapter definitions make impossible, the same kind of fix as excluding
# civst = "D" for a living resident.
icd10_chapter_num <- function(codes) {
  suppressWarnings(as.integer(substr(codes, 2, 3)))
}

icd10_female_only <- function(codes) {
  chapter <- substr(codes, 1, 1)
  num <- icd10_chapter_num(codes)
  (chapter == "O") | (chapter == "N" & !is.na(num) & num >= 70L & num <= 98L)
}

icd10_male_only <- function(codes) {
  chapter <- substr(codes, 1, 1)
  num <- icd10_chapter_num(codes)
  chapter == "N" & !is.na(num) & num >= 40L & num <= 53L
}

icd10_perinatal_only <- function(codes) {
  substr(codes, 1, 1) == "P"
}

# Draw from `codes` (plain WHO form), dropping per-row chapters that are
# impossible for that row's sex (1 = male, 2 = female; any other value, incl.
# NA/9 "unknown", is left unfiltered) and, when age is known, the perinatal
# chapter for anyone a year old or older. Falls back to the full pool if a
# row's filtered pool would be empty (should not happen with a real WHO
# catalogue, but never draw from nothing).
sample_icd10_coherent <- function(codes, n, koen = NULL, age_years = NULL) {
  if ((is.null(koen) || !length(koen)) && (is.null(age_years) || !length(age_years))) {
    return(sample(codes, n, replace = TRUE))
  }
  koen <- if (is.null(koen) || !length(koen)) rep(NA_integer_, n) else as.integer(koen)
  age_years <- if (is.null(age_years) || !length(age_years)) rep(NA_real_, n) else as.numeric(age_years)
  female_only <- icd10_female_only(codes)
  male_only <- icd10_male_only(codes)
  perinatal_only <- icd10_perinatal_only(codes)
  not_newborn <- !is.na(age_years) & age_years >= 1
  # Group rows into a handful of (sex, newborn) buckets so each distinct
  # filtered pool is only computed and sampled from once, not per row.
  group <- paste(koen, not_newborn, sep = "|")
  out <- character(n)
  for (g in unique(group)) {
    idx <- which(group == g)
    parts <- strsplit(g, "|", fixed = TRUE)[[1]]
    g_koen <- suppressWarnings(as.integer(parts[[1]]))
    g_not_newborn <- identical(parts[[2]], "TRUE")
    excl <- logical(length(codes))
    if (identical(g_koen, 1L)) {
      excl <- excl | female_only
    } else if (identical(g_koen, 2L)) {
      excl <- excl | male_only
    }
    if (g_not_newborn) {
      excl <- excl | perinatal_only
    }
    pool <- codes[!excl]
    if (!length(pool)) {
      pool <- codes
    }
    out[idx] <- sample(pool, length(idx), replace = TRUE)
  }
  out
}

stamp_icd10_who_catalogue <- function(tbl) {
  if (is.null(tbl) || !nrow(tbl)) {
    return(tbl)
  }
  attr(tbl, "catalogue") <- .fiktive_icd_stamp$catalogue %||% NA_character_
  attr(tbl, "catalogue_version") <- .fiktive_icd_stamp$version %||% NA_character_
  tbl
}
