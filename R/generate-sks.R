# SKS sampling helpers (loaded with generate.R).

.sks_state <- new.env(parent = emptyenv())

sksr_is_installed <- function() {
  requireNamespace("sksr", quietly = TRUE)
}

sks_catalogue_stamp <- function() {
  list(
    catalogue = .sks_state$catalogue %||% "sksr::SKS_labels",
    version = .sks_state$version %||% NA_character_
  )
}

load_sks_labels <- function() {
  if (!sksr_is_installed()) {
    stop(
      "Package 'sksr' is required to sample published SKS codes. ",
      "Install it with install.packages(\"sksr\").",
      call. = FALSE
    )
  }
  if (!is.null(.sks_state$labels)) {
    return(.sks_state$labels)
  }
  labels <- sksr::SKS_labels
  if (is.null(labels) || !nrow(labels) || !("Kode" %in% names(labels))) {
    schema_gap(
      "sksr::SKS_labels",
      "a SKS_labels table with a Kode column"
    )
  }
  labels$Kode <- as.character(labels$Kode)
  if ("Prefix" %in% names(labels)) {
    labels$Prefix <- as.character(labels$Prefix)
  }
  keep <- !is.na(labels$Kode) & nzchar(labels$Kode)
  .sks_state$labels <- labels[keep, , drop = FALSE]
  .sks_state$catalogue <- "sksr::SKS_labels"
  .sks_state$version <- as.character(utils::packageVersion("sksr"))
  .sks_state$labels
}

draw_sks_dia_codes <- function(name, n, type, register_id, koen = NULL, age_years = NULL) {
  register_id <- as.character(register_id %||% "")
  # Contact-level action-diagnosis fields stay NA; child diagnosis tables sample.
  if (!register_id %in% c("lpr_diag", "lpr_a_diagnose", "t_psyk_diag")) {
    return(na_of_type(type %||% "character", n))
  }
  coerce_schema_type(
    sample_sks_codes(n, "dia", cs = NULL, koen = koen, age_years = age_years),
    type %||% "character"
  )
}

# kont_type.yaml's own reader_note: which of two genuinely different code
# formats a row holds is decided by lprindberetningssystem, not by year --
# LPR3-reported rows carry an SKS admin code, rows migrated from MiniPAS/
# LPR2/LPR1 carry a legacy LPR2 patient-type digit ("0" or "2" specifically
# -- that claim, not the full pattype set, is what kont_type.yaml makes).
# lprindberetningssystem = NULL (schema doesn't have that code system yet,
# e.g. older fixtures) falls back to the original always-SKS-adm behaviour.
draw_kont_type_codes <- function(n, lprindberetningssystem = NULL) {
  if (is.null(lprindberetningssystem) || !length(lprindberetningssystem)) {
    return(sample_sks_codes(n, "adm", cs = NULL))
  }
  is_lpr3 <- !is.na(lprindberetningssystem) & lprindberetningssystem == "LPR3"
  out <- character(n)
  if (any(is_lpr3)) {
    out[is_lpr3] <- sample_sks_codes(sum(is_lpr3), "adm", cs = NULL)
  }
  if (any(!is_lpr3)) {
    out[!is_lpr3] <- sample(c("0", "2"), sum(!is_lpr3), replace = TRUE)
  }
  out
}

sks_kind_for <- function(cs_id, register_id, name) {
  if (identical(as.character(cs_id), "kont_type")) {
    return("adm")
  }
  register_id <- as.character(register_id %||% "")
  if (identical(register_id, "lpr_sksopr")) {
    return("opr")
  }
  if (identical(register_id, "lpr_sksube")) {
    return("pro_und")
  }
  if (identical(register_id, "lpr_a_procregistrering")) {
    return("proc")
  }
  schema_gap(
    sprintf("SKS kind for column '%s' on '%s'", name, register_id %||% "register"),
    "a documented procedure grain (lpr_sksopr / lpr_sksube / lpr_a_procregistrering)"
  )
}

filter_published_sks <- function(labels, kind, cs) {
  kode <- as.character(labels$Kode)
  if ("Prefix" %in% names(labels)) {
    pref <- as.character(labels$Prefix)
    pick <- switch(
      kind,
      opr = pref == "opr",
      pro_und = pref %in% c("pro", "und"),
      proc = pref %in% c("opr", "pro", "und"),
      adm = pref == "adm",
      dia = pref == "dia",
      rep(TRUE, length(kode))
    )
    kode <- kode[pick]
  } else {
    if (identical(kind, "opr")) {
      kode <- kode[startsWith(kode, "K")]
    } else if (identical(kind, "adm")) {
      kode <- kode[nchar(kode) == 6L]
    }
  }
  kode <- kode[grepl("^[A-Za-z][A-Za-z0-9]{3,}$", kode)]
  if (identical(kind, "adm")) {
    kode <- kode[nchar(kode) == 6L]
  }
  if (identical(kind, "opr")) {
    kode <- kode[startsWith(kode, "K") | startsWith(kode, "k")]
  }
  if (identical(kind, "dia")) {
    # Danish LPR diagnoses already carry D-prefix in SKS (e.g. DE119).
    kode <- kode[startsWith(kode, "D") | startsWith(kode, "d")]
    kode <- kode[nchar(kode) >= 4L]
  }
  unique(kode)
}

sample_sks_codes <- function(n, kind, cs, koen = NULL, age_years = NULL) {
  labels <- load_sks_labels()
  codes <- filter_published_sks(labels, kind, cs)
  if (!length(codes)) {
    schema_gap(
      sprintf("published SKS codes in sksr::SKS_labels for kind '%s'", kind),
      "SKS_labels rows already classified for this grain"
    )
  }
  # Diagnosis codes only (dia): same sex/newborn-chapter check as plain WHO
  # icd10, applied on the D-stripped code (sksr dia codes are D + WHO form,
  # e.g. "DE119"). Procedure/admin kinds carry no such chapter semantics.
  if (identical(kind, "dia") && grepl("^D[A-Z]", codes[[1]])) {
    return(paste0("D", sample_icd10_coherent(sub("^D", "", codes), n, koen = koen, age_years = age_years)))
  }
  sample(codes, n, replace = TRUE)
}

typed_noise <- function(type, n, role = NULL, name = NULL, code_system = NULL, cs = NULL) {
  if (identical(type, "integer")) {
    return(sample.int(11L, n, replace = TRUE) - 1L)
  }
  if (identical(type, "numeric")) {
    return(stats::runif(n, 0.5, 20))
  }
  if (identical(type, "logical")) {
    return(sample(c(TRUE, FALSE), n, replace = TRUE))
  }
  if (identical(type, "date")) {
    return(as.Date("1990-01-01") + sample.int(10000L, n, replace = TRUE) - 1L)
  }
  if (identical(type, "datetime")) {
    return(
      as.POSIXct("1990-01-01", tz = "UTC") +
        (sample.int(10000L, n, replace = TRUE) - 1L) * 86400
    )
  }
  if (identical(as.character(code_system), "atc") || identical(name, "atc")) {
    schema_gap(
      "ATC codes without a WHO-form catalogue",
      "codeCollection::ATCKoodit or FIKTIVE_WHOCC_ATC; never sprintf; never decoder::atc"
    )
  }
  if (identical(name, "analysiscode")) {
    schema_gap(
      "lab_dm_forsker analysiscode without LabTerm / published NPU catalogue",
      "FIKTIVE_LABTERM or IFCC C-NPU CSV; never sprintf NPU/DNK noise"
    )
  }
  if (as.character(code_system %||% "") %in% c("icd10", "icd10_sks", "icd8", "sks", "kont_type")) {
    stop(
      "Internal error: clinical nomenclature must not fall through to typed noise.",
      call. = FALSE
    )
  }
  if (identical(role, "identifier") || (identical(role, "join_key") && !identical(name, "pnr"))) {
    prefix <- if (identical(role, "join_key")) "H" else "I"
    return(sprintf("%s%07d", prefix, sample.int(10000000L, n, replace = TRUE) - 1L))
  }
  sprintf("%03d", sample.int(1000L, n, replace = TRUE) - 1L)
}
