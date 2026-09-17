# Curated, per-analyte realistic value ranges for lab_dm_forsker/labka's
# value/unit/reference-interval columns, keyed by real NPU code. Every code
# below is verified active and current in the public IFCC C-NPU catalogue --
# the same catalogue fiktive samples analysiscode from (see
# catalogue-labterm.R) -- confirmed against
# https://cms.ifcc.org/wp-content/uploads/npu-codes-latest.csv. Deliberately
# a small, common blood-panel subset (electrolytes, renal, liver, lipids,
# haematology, thyroid, inflammation, glucose/HbA1c), not the full NPU
# catalogue: an analysiscode outside this set still falls back to the same
# generic 3-digit noise as before -- a documented limitation, not a bug.
#
# `draw` is the range `value` is sampled from -- deliberately wider than the
# reference interval, so the fake data spans plausible abnormals, not only
# healthy results, matching fiktive's general "wide enough that a uniform
# draw is not obviously wrong" philosophy elsewhere (e.g. nutrient/anthro
# ranges). `ref` is what's reported in referenceinterval_lowerlimit/
# upperlimit. Both are typical adult intervals from common clinical
# reference sources, not lab-, analyser-, age- or sex-specific -- real
# reference intervals vary along all four axes, so this is a deliberate
# simplification, the same class as borger_koen or weighted_municipality
# elsewhere in fiktive.
.LABTERM_ANALYTE_RANGES <- list(
  NPU03230 = list(label = "Potassium (P)",             unit = "mmol/L",  draw = c(2.8, 6.5),  ref = c(3.5, 4.6),   digits = 1),
  NPU03429 = list(label = "Sodium (P)",                 unit = "mmol/L",  draw = c(120, 160),  ref = c(137, 145),   digits = 0),
  NPU01536 = list(label = "Chloride (P)",                unit = "mmol/L",  draw = c(85, 115),   ref = c(98, 106),    digits = 0),
  NPU01443 = list(label = "Calcium (P)",                 unit = "mmol/L",  draw = c(1.8, 3.2),  ref = c(2.15, 2.51), digits = 2),
  NPU18016 = list(label = "Creatinine (P)",              unit = "µmol/L", draw = c(30, 500), ref = c(45, 105), digits = 0),
  NPU02192 = list(label = "Glucose (P)",                 unit = "mmol/L",  draw = c(2.5, 25),   ref = c(4.0, 7.8),   digits = 1),
  NPU28309 = list(label = "Haemoglobin (B)",             unit = "g/L",     draw = c(60, 190),   ref = c(117, 170),   digits = 0),
  NPU19748 = list(label = "C-reactive protein (P)",      unit = "mg/L",    draw = c(0, 250),    ref = c(0, 8),       digits = 1),
  NPU53495 = list(label = "Alanine transaminase (P)",    unit = "U/L",     draw = c(5, 500),    ref = c(10, 70),     digits = 0),
  NPU57159 = list(label = "Aspartate transaminase (P)",  unit = "U/L",     draw = c(5, 500),    ref = c(15, 45),     digits = 0),
  NPU01566 = list(label = "Cholesterol, total (P)",      unit = "mmol/L",  draw = c(2.0, 10.0), ref = c(2.9, 6.2),   digits = 1),
  NPU01567 = list(label = "Cholesterol, HDL (P)",        unit = "mmol/L",  draw = c(0.4, 3.0),  ref = c(1.0, 2.2),   digits = 2),
  NPU01568 = list(label = "Cholesterol, LDL (P)",        unit = "mmol/L",  draw = c(0.5, 8.0),  ref = c(1.2, 4.3),   digits = 1),
  NPU04094 = list(label = "Triglyceride (P)",            unit = "mmol/L",  draw = c(0.3, 10.0), ref = c(0.45, 2.6),  digits = 1),
  NPU01366 = list(label = "Bilirubin (P)",                unit = "µmol/L", draw = c(2, 200), ref = c(5, 25),   digits = 0),
  NPU29296 = list(label = "Haemoglobin A1c (B, NGSP)",   unit = "%",       draw = c(4.0, 14.0), ref = c(4.0, 5.6),   digits = 1),
  NPU03577 = list(label = "Thyrotropin/TSH (P)",         unit = "mIU/L",   draw = c(0.01, 20),  ref = c(0.4, 4.0),   digits = 2)
)

# Realistic, analyte-specific noise for lab_dm_forsker/labka's
# value/unit/referenceinterval_* columns -- see .LABTERM_ANALYTE_RANGES
# above. A row whose analysiscode isn't in the curated set keeps the
# pre-existing generic fallback (a bare 3-digit code string), unchanged.
labterm_analyte_noise <- function(name, n, analysiscode) {
  fallback <- function(k) sprintf("%03d", sample.int(1000L, k, replace = TRUE) - 1L)
  out <- fallback(n)
  if (is.null(analysiscode) || !length(analysiscode) || n == 0L) {
    return(out)
  }
  ranges <- .LABTERM_ANALYTE_RANGES[as.character(analysiscode)]
  matched <- which(!vapply(ranges, is.null, logical(1)))
  if (!length(matched)) {
    return(out)
  }
  for (i in matched) {
    r <- ranges[[i]]
    fmt <- paste0("%.", r$digits, "f")
    out[[i]] <- switch(
      name,
      value = sprintf(fmt, stats::runif(1L, r$draw[[1]], r$draw[[2]])),
      unit = r$unit,
      referenceinterval_lowerlimit = sprintf(fmt, r$ref[[1]]),
      referenceinterval_upperlimit = sprintf(fmt, r$ref[[2]])
    )
  }
  out
}
