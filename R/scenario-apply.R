# STEP 8b–8d — apply scenario associations / confounders / biases AFTER
# structural generation and BEFORE fidelity. Coefficients live only on the
# scenario object (never YAML / custom column CSV).

parse_register_column <- function(ref, arg = "register.column") {
  ref <- as.character(ref)[[1]]
  if (!nzchar(ref) || !grepl(".", ref, fixed = TRUE)) {
    stop(
      sprintf("`%s` must be 'register.column' (got %s).", arg, ref),
      call. = FALSE
    )
  }
  parts <- strsplit(ref, ".", fixed = TRUE)[[1]]
  if (length(parts) < 2L || !nzchar(parts[[1]]) || !nzchar(parts[[2]])) {
    stop(
      sprintf("`%s` must be 'register.column' (got %s).", arg, ref),
      call. = FALSE
    )
  }
  # Allow dotted column names after the first dot (rare); register is first token.
  list(
    register = parts[[1]],
    column = paste(parts[-1], collapse = "."),
    ref = ref
  )
}

validate_link <- function(link) {
  link <- as.character(link)[[1]]
  if (!link %in% c("identity", "logit", "log")) {
    stop("`link` must be one of: identity, logit, log.", call. = FALSE)
  }
  link
}

validate_fiktive_scenario <- function(scenario) {
  if (is.null(scenario)) {
    return(scenario_independence())
  }
  sc <- as_fiktive_scenario(scenario)
  for (a in sc$associations %||% list()) {
    if (is.null(a$exposure) || is.null(a$outcome) || is.null(a$link) ||
        is.null(a$coefficient)) {
      stop(
        "Each association needs exposure, outcome, link, and coefficient.",
        call. = FALSE
      )
    }
    parse_register_column(a$exposure, "associations$exposure")
    parse_register_column(a$outcome, "associations$outcome")
    validate_link(a$link)
    if (!is.numeric(a$coefficient) || length(a$coefficient) != 1L ||
        is.na(a$coefficient)) {
      stop("`coefficient` must be a single non-NA number.", call. = FALSE)
    }
  }
  for (cfd in sc$confounders %||% list()) {
    if (is.null(cfd$name) || is.null(cfd$affects_exposure) ||
        is.null(cfd$affects_outcome)) {
      stop(
        "Each confounder needs name, affects_exposure, and affects_outcome.",
        call. = FALSE
      )
    }
    parse_register_column(cfd$name, "confounders$name")
  }
  for (b in sc$biases %||% list()) {
    if (is.null(b$type) || !as.character(b$type)[[1]] %in%
        c("mnar", "complete_case")) {
      stop(
        "Each bias$type must be 'mnar' or 'complete_case' in this ship.",
        call. = FALSE
      )
    }
  }
  sc
}

invlogit <- function(x) {
  stats::plogis(x)
}

as_numeric_exposure <- function(x) {
  if (is.logical(x)) {
    return(as.numeric(x))
  }
  if (is.factor(x)) {
    return(as.numeric(x))
  }
  as.numeric(x)
}

#' @noRd
draw_outcome_from_exposure <- function(x, link, coefficient, intercept = 0,
                                       offset = 0, sigma = 1) {
  n <- length(x)
  eta <- intercept + coefficient * as_numeric_exposure(x) + offset
  if (identical(link, "identity")) {
    return(as.numeric(eta + stats::rnorm(n, sd = sigma)))
  }
  if (identical(link, "logit")) {
    p <- invlogit(eta)
    return(as.integer(stats::runif(n) < p))
  }
  if (identical(link, "log")) {
    # Positive continuous (log-normal mean structure).
    return(as.numeric(exp(eta + stats::rnorm(n, sd = 0.25))))
  }
  stop("Unknown link.", call. = FALSE)
}

ensure_column <- function(tbl, col, n, default = 0) {
  if (!col %in% names(tbl)) {
    if (length(default) == n) {
      tbl[[col]] <- default
    } else if (length(default) == 1L) {
      tbl[[col]] <- rep(default, n)
    } else {
      stop("ensure_column default length must be 1 or n.", call. = FALSE)
    }
  }
  tbl
}

join_key_for_tables <- function(tables) {
  # Prefer pnr when present on every table; else first shared name.
  nms <- lapply(tables, names)
  shared <- Reduce(intersect, nms)
  if ("pnr" %in% shared) {
    return("pnr")
  }
  if (length(shared)) {
    return(shared[[1]])
  }
  NULL
}

lookup_table <- function(tables, register_id) {
  if (is.data.frame(tables)) {
    return(tables)
  }
  if (!is.list(tables)) {
    stop("Expected a tibble or named list of tibbles.", call. = FALSE)
  }
  # Exact id, then case-insensitive.
  if (register_id %in% names(tables)) {
    return(tables[[register_id]])
  }
  hit <- names(tables)[tolower(names(tables)) == tolower(register_id)]
  if (length(hit)) {
    return(tables[[hit[[1]]]])
  }
  NULL
}

set_table <- function(tables, register_id, tbl) {
  if (is.data.frame(tables)) {
    return(tbl)
  }
  if (register_id %in% names(tables)) {
    tables[[register_id]] <- tbl
    return(tables)
  }
  hit <- names(tables)[tolower(names(tables)) == tolower(register_id)]
  if (length(hit)) {
    tables[[hit[[1]]]] <- tbl
    return(tables)
  }
  tables[[register_id]] <- tbl
  tables
}

#' @noRd
resolve_column <- function(tables, ref, register_hint = NULL) {
  parsed <- parse_register_column(ref)
  if (is.data.frame(tables)) {
    if (!is.null(register_hint) &&
        !identical(tolower(parsed$register), tolower(register_hint))) {
      stop(
        sprintf(
          "Association references '%s' but this table is register '%s'.",
          ref, register_hint
        ),
        call. = FALSE
      )
    }
    if (!parsed$column %in% names(tables)) {
      stop(sprintf("Column '%s' not found on table.", parsed$column), call. = FALSE)
    }
    return(list(values = tables[[parsed$column]], register = parsed$register,
                column = parsed$column, tbl = tables))
  }
  tbl <- lookup_table(tables, parsed$register)
  if (is.null(tbl)) {
    stop(
      sprintf("Register '%s' not in this run (needed for %s).", parsed$register, ref),
      call. = FALSE
    )
  }
  if (!parsed$column %in% names(tbl)) {
    stop(
      sprintf("Column '%s' not found on register '%s'.", parsed$column, parsed$register),
      call. = FALSE
    )
  }
  list(values = tbl[[parsed$column]], register = parsed$register,
       column = parsed$column, tbl = tbl)
}

write_column <- function(tables, register_id, column, values, register_hint = NULL) {
  if (is.data.frame(tables)) {
    tables[[column]] <- values
    return(tables)
  }
  tbl <- lookup_table(tables, register_id)
  if (is.null(tbl)) {
    stop(sprintf("Register '%s' missing when writing '%s'.", register_id, column),
         call. = FALSE)
  }
  if (length(values) != nrow(tbl)) {
    stop(
      sprintf(
        "Length mismatch writing %s.%s (%d vs %d rows).",
        register_id, column, length(values), nrow(tbl)
      ),
      call. = FALSE
    )
  }
  tbl[[column]] <- values
  set_table(tables, register_id, tbl)
}

align_by_key <- function(src_tbl, src_vals, dest_tbl, key) {
  if (is.null(key) || !key %in% names(src_tbl) || !key %in% names(dest_tbl)) {
    if (nrow(src_tbl) == nrow(dest_tbl)) {
      return(src_vals)
    }
    stop("Cannot align columns across registers without a shared key.", call. = FALSE)
  }
  idx <- match(dest_tbl[[key]], src_tbl[[key]])
  if (anyNA(idx)) {
    stop("Join key alignment failed (missing keys across registers).", call. = FALSE)
  }
  src_vals[idx]
}

#' @noRd
apply_associations <- function(tables, associations, register_hint = NULL) {
  if (!length(associations)) {
    return(tables)
  }
  key <- if (is.data.frame(tables)) {
    NULL
  } else {
    join_key_for_tables(tables)
  }
  for (a in associations) {
    link <- validate_link(a$link)
    coef <- as.numeric(a$coefficient)[[1]]
    intercept <- as.numeric(a$intercept %||% 0)[[1]]
    sigma <- as.numeric(a$sigma %||% 1)[[1]]
    exp_p <- parse_register_column(a$exposure)
    out_p <- parse_register_column(a$outcome)
    if (is.data.frame(tables)) {
      # Single table: both refs must target this register (or match hint).
      for (p in list(exp_p, out_p)) {
        if (!is.null(register_hint) &&
            !identical(tolower(p$register), tolower(register_hint))) {
          stop(
            sprintf(
              "Association %s references register '%s' but generating '%s'.",
              a$exposure %||% "", p$register, register_hint
            ),
            call. = FALSE
          )
        }
      }
      n <- nrow(tables)
      if (!exp_p$column %in% names(tables)) {
        tables[[exp_p$column]] <- stats::rnorm(n)
      }
      x <- as_numeric_exposure(tables[[exp_p$column]])
      y <- draw_outcome_from_exposure(x, link, coef, intercept = intercept, sigma = sigma)
      tables[[out_p$column]] <- y
    } else {
      exp_tbl <- lookup_table(tables, exp_p$register)
      out_tbl <- lookup_table(tables, out_p$register)
      if (is.null(exp_tbl) || is.null(out_tbl)) {
        stop(
          sprintf(
            "Association needs registers '%s' and '%s' in this run.",
            exp_p$register, out_p$register
          ),
          call. = FALSE
        )
      }
      if (!exp_p$column %in% names(exp_tbl)) {
        exp_tbl[[exp_p$column]] <- stats::rnorm(nrow(exp_tbl))
        tables <- set_table(tables, exp_p$register, exp_tbl)
        exp_tbl <- lookup_table(tables, exp_p$register)
      }
      x_on_exp <- as_numeric_exposure(exp_tbl[[exp_p$column]])
      if (identical(tolower(exp_p$register), tolower(out_p$register))) {
        y <- draw_outcome_from_exposure(x_on_exp, link, coef,
                                        intercept = intercept, sigma = sigma)
        out_tbl[[out_p$column]] <- y
        tables <- set_table(tables, out_p$register, out_tbl)
      } else {
        x_on_out <- align_by_key(exp_tbl, x_on_exp, out_tbl, key)
        y <- draw_outcome_from_exposure(x_on_out, link, coef,
                                        intercept = intercept, sigma = sigma)
        out_tbl[[out_p$column]] <- y
        tables <- set_table(tables, out_p$register, out_tbl)
      }
    }
  }
  tables
}

#' @noRd
apply_confounders <- function(tables, scenario, register_hint = NULL) {
  cfds <- scenario$confounders %||% list()
  if (!length(cfds)) {
    return(tables)
  }
  # First ship: one confounder + primary association.
  cfd <- cfds[[1]]
  assoc <- (scenario$associations %||% list())[[1]]
  if (is.null(assoc)) {
    stop("Confounding scenario needs a primary association (E→Y).", call. = FALSE)
  }
  link <- validate_link(assoc$link)
  beta <- as.numeric(assoc$coefficient)[[1]]
  a_ue <- as.numeric(cfd$affects_exposure)[[1]]
  a_uy <- as.numeric(cfd$affects_outcome)[[1]]
  u_ref <- parse_register_column(cfd$name)
  e_ref <- parse_register_column(assoc$exposure)
  y_ref <- parse_register_column(assoc$outcome)
  intercept_e <- as.numeric(cfd$intercept_exposure %||% 0)[[1]]
  intercept_y <- as.numeric(assoc$intercept %||% 0)[[1]]
  sigma_e <- as.numeric(cfd$sigma_exposure %||% 1)[[1]]
  sigma_y <- as.numeric(assoc$sigma %||% 1)[[1]]

  get_tbl <- function(reg) {
    if (is.data.frame(tables)) {
      if (!is.null(register_hint) &&
          !identical(tolower(reg), tolower(register_hint))) {
        stop(
          sprintf("Confounder refs register '%s' but generating '%s'.", reg, register_hint),
          call. = FALSE
        )
      }
      return(tables)
    }
    tbl <- lookup_table(tables, reg)
    if (is.null(tbl)) {
      stop(sprintf("Register '%s' required for confounding.", reg), call. = FALSE)
    }
    tbl
  }

  # Require U, E, Y on the same register for the first ship (person-level custom).
  if (!identical(tolower(u_ref$register), tolower(e_ref$register)) ||
      !identical(tolower(e_ref$register), tolower(y_ref$register))) {
    stop(
      "First-ship confounding requires confounder, exposure, and outcome on the same register.",
      call. = FALSE
    )
  }
  tbl <- get_tbl(u_ref$register)
  n <- nrow(tbl)
  u <- stats::rnorm(n)
  e <- intercept_e + a_ue * u + stats::rnorm(n, sd = sigma_e)
  if (identical(link, "logit")) {
    # Binary exposure under confounding: latent linear then threshold optional;
    # keep continuous E for identity; for logit outcome keep continuous E.
    e <- as.numeric(e)
  }
  offset_u <- a_uy * u
  y <- draw_outcome_from_exposure(e, link, beta, intercept = intercept_y,
                                  offset = offset_u, sigma = sigma_y)
  tbl[[u_ref$column]] <- as.numeric(u)
  tbl[[e_ref$column]] <- as.numeric(e)
  tbl[[y_ref$column]] <- y
  if (is.data.frame(tables)) {
    return(tbl)
  }
  set_table(tables, u_ref$register, tbl)
}

#' @noRd
apply_biases <- function(tables, scenario, register_hint = NULL) {
  biases <- scenario$biases %||% list()
  if (!length(biases)) {
    return(tables)
  }
  assoc <- (scenario$associations %||% list())[[1]]
  for (b in biases) {
    typ <- as.character(b$type)[[1]]
    # Target column for missingness / selection (default: outcome).
    target_ref <- parse_register_column(
      b$on %||% (assoc$outcome %||% stop("bias needs `on` or an association outcome.", call. = FALSE))
    )
    if (is.data.frame(tables)) {
      if (!is.null(register_hint) &&
          !identical(tolower(target_ref$register), tolower(register_hint))) {
        stop(
          sprintf("Bias refs register '%s' but generating '%s'.",
                  target_ref$register, register_hint),
          call. = FALSE
        )
      }
      tbl <- tables
    } else {
      tbl <- lookup_table(tables, target_ref$register)
      if (is.null(tbl)) {
        stop(sprintf("Register '%s' required for bias.", target_ref$register), call. = FALSE)
      }
    }
    if (!target_ref$column %in% names(tbl)) {
      stop(sprintf("Bias target column '%s' missing.", target_ref$column), call. = FALSE)
    }
    z <- as_numeric_exposure(tbl[[target_ref$column]])
    intercept <- as.numeric(b$intercept %||% -1)[[1]]
    coef_m <- as.numeric(b$coefficient %||% 1)[[1]]
    p <- invlogit(intercept + coef_m * z)
    if (identical(typ, "mnar")) {
      miss <- stats::runif(nrow(tbl)) < p
      tbl[[target_ref$column]][miss] <- NA
    } else if (identical(typ, "complete_case")) {
      keep <- stats::runif(nrow(tbl)) < p
      # Selection: keep rows with higher p (selected sample).
      # If selection depends on outcome, selected mean of E differs.
      tbl <- tbl[keep, , drop = FALSE]
    } else {
      stop(sprintf("Unsupported bias type '%s'.", typ), call. = FALSE)
    }
    if (is.data.frame(tables)) {
      tables <- tbl
    } else {
      tables <- set_table(tables, target_ref$register, tbl)
    }
  }
  tables
}

#' @noRd
apply_scenario <- function(tables, scenario, register_hint = NULL) {
  sc <- validate_fiktive_scenario(scenario)
  if (identical(sc$id, "independence") &&
      !length(sc$associations) && !length(sc$confounders) && !length(sc$biases)) {
    return(tables)
  }
  if (length(sc$confounders)) {
    tables <- apply_confounders(tables, sc, register_hint = register_hint)
  } else if (length(sc$associations)) {
    tables <- apply_associations(tables, sc$associations, register_hint = register_hint)
  }
  if (length(sc$biases)) {
    tables <- apply_biases(tables, sc, register_hint = register_hint)
  }
  tables
}
