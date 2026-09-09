# Opt-in data-quality fidelity (STEP 8a). MCAR-ish NA + rare numeric/date
# extremes. NOT informative MAR/MNAR, NOT confounding, NOT DST rates from
# microdata. Rates never live in schema YAML.

# Fixed messy presets (package constants — not estimated from real registers).
.FIKTIVE_MESSY_NA_RATE <- 0.03
.FIKTIVE_MESSY_OUTLIER_RATE <- 0.01

# Column ids filled by derived_column() — stay COMPLETE under fidelity.
.FIKTIVE_DERIVED_IDS <- c(
  "pnr", "k_cprnr", "cpr_barn", "patient_cpr", "samplingdate", "foedselsdato",
  "foedselsaar", "familie_id", "koen", "foed_dag", "referencetid", "year",
  "alder", "alder_ult_ink", "alder_haend", "aldr", "v_alder", "v_diagnosealder",
  "v_diagaar", "v_diagmd", "fdato", "d_fdsdato", "d_diagnosedato", "d_statdato",
  "doddato", "eksd", "haend_dato", "d_inddto", "d_uddto", "recnum",
  "dw_ek_kontakt", "kont_starttidspunkt", "kont_sluttidspunkt",
  "borger_foedselsdato", "borger_alder_aar_ind", "borger_alder_aar_ud",
  "d_odto", "proc_starttidspunkt", "proc_sluttidspunkt", "proc_indb_tidspunkt",
  "atc1", "atc2", "atc3", "atc4"
)

.FIKTIVE_PRESENCE_ROLES <- c("presence", "presence_flag")

#' Resolve fidelity preset + optional rate overrides
#'
#' @param fidelity `"clean"` or `"messy"`.
#' @param na_rate Optional override in `[0, 1]`.
#' @param outlier_rate Optional override in `[0, 1]`.
#' @return Named list: `preset`, `na_rate`, `outlier_rate`.
#' @keywords internal
resolve_fidelity <- function(fidelity = c("clean", "messy"),
                             na_rate = NULL,
                             outlier_rate = NULL) {
  fidelity <- match.arg(fidelity)
  if (identical(fidelity, "clean")) {
    base_na <- 0
    base_out <- 0
  } else {
    base_na <- .FIKTIVE_MESSY_NA_RATE
    base_out <- .FIKTIVE_MESSY_OUTLIER_RATE
  }
  na_eff <- if (is.null(na_rate)) base_na else as_rate01(na_rate, "na_rate")
  out_eff <- if (is.null(outlier_rate)) {
    base_out
  } else {
    as_rate01(outlier_rate, "outlier_rate")
  }
  list(
    preset = fidelity,
    na_rate = na_eff,
    outlier_rate = out_eff
  )
}

as_rate01 <- function(x, nm) {
  if (length(x) != 1L || is.na(x) || !is.numeric(x)) {
    stop(sprintf("`%s` must be a single number in [0, 1].", nm), call. = FALSE)
  }
  x <- as.numeric(x)[[1]]
  if (x < 0 || x > 1) {
    stop(sprintf("`%s` must be in [0, 1].", nm), call. = FALSE)
  }
  x
}

stamp_fidelity <- function(tbl, fidelity_info) {
  attr(tbl, "fidelity") <- fidelity_info$preset
  attr(tbl, "na_rate") <- fidelity_info$na_rate
  attr(tbl, "outlier_rate") <- fidelity_info$outlier_rate
  tbl
}

col_meta_by_name <- function(spec) {
  cols <- spec$columns %||% list()
  out <- list()
  for (col in cols) {
    nm <- as.character(col$name %||% col$id)
    if (nzchar(nm)) {
      out[[nm]] <- col
    }
  }
  out
}

join_key_names <- function(spec) {
  jk <- as.character(unlist(spec$join_keys %||% list()))
  cols <- spec$columns %||% list()
  role_keys <- character()
  for (col in cols) {
    if (identical(as.character(col$role %||% ""), "join_key")) {
      role_keys <- c(role_keys, as.character(col$name %||% col$id))
    }
  }
  unique(c(jk, role_keys))
}

is_derived_column_name <- function(nm) {
  nm %in% .FIKTIVE_DERIVED_IDS
}

is_presence_column <- function(col) {
  role <- as.character(col$role %||% "")
  role %in% .FIKTIVE_PRESENCE_ROLES
}

#' Columns eligible for MCAR-ish NA under fidelity
#'
#' Non-key, non-derived, non-presence only. Join keys / presence / derived
#' (e.g. `alder`) stay complete.
#'
#' @keywords internal
fidelity_na_eligible <- function(tbl, spec) {
  nms <- names(tbl)
  if (!length(nms)) {
    return(character())
  }
  meta <- col_meta_by_name(spec)
  keys <- join_key_names(spec)
  keep <- vapply(nms, function(nm) {
    if (nm %in% keys) {
      return(FALSE)
    }
    if (is_derived_column_name(nm)) {
      return(FALSE)
    }
    col <- meta[[nm]]
    if (!is.null(col) && is_presence_column(col)) {
      return(FALSE)
    }
    TRUE
  }, logical(1))
  nms[keep]
}

#' Columns eligible for rare extremes under fidelity
#'
#' Numeric / date / datetime only; never invent invalid catalogue codes.
#' Join keys, derived, presence, and `code_system` columns are excluded.
#'
#' @keywords internal
fidelity_outlier_eligible <- function(tbl, spec) {
  nms <- fidelity_na_eligible(tbl, spec)
  if (!length(nms)) {
    return(character())
  }
  meta <- col_meta_by_name(spec)
  keep <- vapply(nms, function(nm) {
    col <- meta[[nm]]
    type <- if (!is.null(col) && !is.null(col$type)) {
      as.character(col$type)[[1]]
    } else {
      infer_vec_type(tbl[[nm]])
    }
    if (!type %in% c("numeric", "integer", "date", "datetime")) {
      return(FALSE)
    }
    # Do not invent invalid clinical / enumerated codes via extremes.
    if (!is.null(col) && !is.null(col$code_system) &&
        nzchar(as.character(col$code_system)[[1]])) {
      return(FALSE)
    }
    if (!is.null(col) && identical(as.character(col$role %||% ""), "code")) {
      return(FALSE)
    }
    TRUE
  }, logical(1))
  nms[keep]
}

infer_vec_type <- function(x) {
  if (inherits(x, "POSIXt")) {
    return("datetime")
  }
  if (inherits(x, "Date")) {
    return("date")
  }
  if (is.integer(x)) {
    return("integer")
  }
  if (is.numeric(x)) {
    return("numeric")
  }
  if (is.logical(x)) {
    return("logical")
  }
  "character"
}

#' Apply opt-in fidelity (MCAR-ish NA + rare extremes)
#'
#' @param tbl Generated tibble.
#' @param spec Register spec (schema or custom) with `columns` / `join_keys`.
#' @param fidelity_info From [resolve_fidelity()].
#' @return `tbl` with fidelity applied and stamped.
#' @keywords internal
apply_fidelity <- function(tbl, spec, fidelity_info) {
  if (!is.data.frame(tbl)) {
    stop("`tbl` must be a data frame / tibble.", call. = FALSE)
  }
  n <- nrow(tbl)
  na_rate <- fidelity_info$na_rate
  out_rate <- fidelity_info$outlier_rate
  if (n > 0L && na_rate > 0) {
    meta <- col_meta_by_name(spec)
    for (nm in fidelity_na_eligible(tbl, spec)) {
      mask <- stats::runif(n) < na_rate
      if (any(mask)) {
        typ <- if (!is.null(meta[[nm]]$type)) {
          meta[[nm]]$type
        } else {
          infer_vec_type(tbl[[nm]])
        }
        tbl[[nm]][mask] <- na_of_type(typ, sum(mask))
      }
    }
  }
  if (n > 0L && out_rate > 0) {
    for (nm in fidelity_outlier_eligible(tbl, spec)) {
      mask <- stats::runif(n) < out_rate
      # Only replace non-missing cells (NA already applied).
      mask <- mask & !is.na(tbl[[nm]])
      if (any(mask)) {
        tbl[[nm]][mask] <- outlier_values(tbl[[nm]][mask], tbl[[nm]])
      }
    }
  }
  stamp_fidelity(tbl, fidelity_info)
}

outlier_values <- function(targets, full_col) {
  if (inherits(full_col, "POSIXt")) {
    return(as.POSIXct(full_col[seq_along(targets)], tz = "UTC") + 86400 * 5000)
  }
  if (inherits(full_col, "Date")) {
    return(as.Date(full_col[seq_along(targets)]) + 5000)
  }
  if (is.integer(full_col)) {
    base <- suppressWarnings(as.integer(stats::median(full_col, na.rm = TRUE)))
    if (is.na(base)) {
      base <- 0L
    }
    return(as.integer(base + 100000L))
  }
  if (is.numeric(full_col)) {
    med <- stats::median(full_col, na.rm = TRUE)
    if (is.na(med)) {
      med <- 0
    }
    iqr <- stats::IQR(full_col, na.rm = TRUE)
    if (is.na(iqr) || iqr == 0) {
      iqr <- max(1, abs(med), na.rm = TRUE)
    }
    return(as.numeric(med + 8 * iqr))
  }
  targets
}
