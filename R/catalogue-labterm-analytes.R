# Curated, per-analyte realistic value ranges for lab_dm_forsker/labka's
# value/unit/reference-interval columns, keyed by real NPU code. Every code
# below is verified active and current in the public IFCC C-NPU catalogue --
# the same catalogue fiktive samples analysiscode from (see
# catalogue-labterm.R) -- confirmed against
# https://cms.ifcc.org/wp-content/uploads/npu-codes-latest.csv. An
# analysiscode outside this curated set still falls back to the same
# generic 3-digit noise as before -- a documented limitation, not a bug.
#
# `draw` is the range `value` is sampled from -- deliberately wider than the
# reference interval, so the fake data spans plausible abnormals, not only
# healthy results, matching fiktive's general "wide enough that a uniform
# draw is not obviously wrong" philosophy elsewhere (e.g. nutrient/anthro
# ranges). `ref` is what's reported in referenceinterval_lowerlimit/
# upperlimit.
#
# Two provenance tiers, marked per entry -- do not blur them:
#
# NORIP (25 entries): `ref` is read directly off Table I of the primary
# source, not recalled/approximated:
#   Rustad P, Felding P, Franzson L, Kairisto V, Lahti A, Martensson A,
#   Hyltoft Petersen P, Simonsson P, Steensland H, Uldall A. The Nordic
#   Reference Interval Project 2000: recommended reference intervals for
#   25 common biochemical properties. Scandinavian Journal of Clinical and
#   Laboratory Investigation. 2004;64(4):271-284.
#   doi:10.1080/00365510410006324. PMID: 15223694.
# Verified three ways: (1) PubMed esearch/esummary metadata, (2) the paper's
# own printed header/citation on page 1, (3) Table I itself, all fetched and
# cross-checked directly, not from memory or a secondary summary. Table I
# reports reference intervals split by sex and, for several analytes, by
# age band, separately for serum and plasma; NORIP's own Discussion
# explicitly warns serum and plasma need different reference intervals for
# potassium specifically. Every `ref` below uses the plasma column (to
# match the "P--" NPU codes here) and collapses sex/age partitions into one
# adult band -- a real simplification of the source, not a value NORIP
# itself reports as a single number. LDL-cholesterol is in Table I but is
# NORIP's *calculated* value (cholesterol - HDL-cholesterol - triglyceride/2
# per their footnote), not one of the 25 directly-measured properties.
#
# Not NORIP (5 entries, marked below): chloride, haemoglobin, CRP, HbA1c
# and TSH aren't among NORIP's 25 biochemistry properties (haemoglobin is
# covered by a separate NORIP-family haematology paper this file doesn't
# yet draw on: Nordin G. Reference intervals for haematology properties in
# blood of adult women and men. Scand J Clin Lab Invest. 2004;64(4):385-398.
# doi:10.1080/00365510410006346). Their `ref` values here are ordinary
# clinical reference ranges, not read off a specific cited source the way
# the NORIP entries are -- lower-confidence than the NORIP tier and flagged
# as such rather than presented the same way.
.LABTERM_ANALYTE_RANGES <- list(
  # --- NORIP (Rustad et al. 2004, Table I; see header) ---
  NPU19673 = list(label = "Albumin (P)",                 unit = "g/L",    draw = c(20, 55),    ref = c(35, 48),    digits = 0, source = "NORIP"),
  NPU01366 = list(label = "Bilirubin (P)",                unit = "µmol/L", draw = c(2, 200),    ref = c(5, 26),     digits = 0, source = "NORIP"),
  NPU01443 = list(label = "Calcium (P)",                 unit = "mmol/L", draw = c(1.8, 3.2),  ref = c(2.14, 2.48), digits = 2, source = "NORIP"),
  NPU01459 = list(label = "Carbamide/urea (P)",          unit = "mmol/L", draw = c(1.5, 25),   ref = c(2.7, 8.2),  digits = 1, source = "NORIP"),
  NPU01566 = list(label = "Cholesterol, total (P)",      unit = "mmol/L", draw = c(2.0, 10.0), ref = c(2.9, 7.9),  digits = 1, source = "NORIP"),
  NPU18016 = list(label = "Creatinine (P)",              unit = "µmol/L", draw = c(30, 500),   ref = c(50, 100),   digits = 0, source = "NORIP"),
  NPU02508 = list(label = "Iron (P)",                    unit = "µmol/L", draw = c(3, 45),     ref = c(9, 34),     digits = 1, source = "NORIP"),
  NPU02192 = list(label = "Glucose (P, fasting)",        unit = "mmol/L", draw = c(2.5, 25),   ref = c(4.0, 6.3),  digits = 1, source = "NORIP"),
  NPU01567 = list(label = "Cholesterol, HDL (P)",        unit = "mmol/L", draw = c(0.4, 3.0),  ref = c(0.8, 2.7),  digits = 2, source = "NORIP"),
  NPU03230 = list(label = "Potassium (P)",               unit = "mmol/L", draw = c(2.8, 6.5),  ref = c(3.5, 4.4),  digits = 1, source = "NORIP"),
  NPU01568 = list(label = "Cholesterol, LDL (P, calc.)", unit = "mmol/L", draw = c(0.5, 8.0),  ref = c(1.2, 5.1),  digits = 1, source = "NORIP"),
  NPU02647 = list(label = "Magnesium (P)",               unit = "mmol/L", draw = c(0.4, 1.3),  ref = c(0.71, 0.93), digits = 2, source = "NORIP"),
  NPU03429 = list(label = "Sodium (P)",                  unit = "mmol/L", draw = c(120, 160),  ref = c(137, 144),  digits = 0, source = "NORIP"),
  NPU03096 = list(label = "Phosphate (P)",               unit = "mmol/L", draw = c(0.3, 2.5),  ref = c(0.72, 1.5), digits = 2, source = "NORIP"),
  NPU03278 = list(label = "Protein, total (P)",          unit = "g/L",    draw = c(40, 100),   ref = c(64, 80),    digits = 0, source = "NORIP"),
  NPU04094 = list(label = "Triglyceride (P, fasting)",   unit = "mmol/L", draw = c(0.3, 10.0), ref = c(0.45, 2.4), digits = 1, source = "NORIP"),
  NPU09356 = list(label = "Urate/uric acid (P)",         unit = "µmol/L", draw = c(80, 700),   ref = c(160, 480),  digits = 0, source = "NORIP"),
  NPU53495 = list(label = "Alanine transaminase (P)",    unit = "U/L",    draw = c(5, 500),    ref = c(6, 68),     digits = 0, source = "NORIP"),
  NPU57159 = list(label = "Aspartate transaminase (P)",  unit = "U/L",    draw = c(5, 500),    ref = c(13, 45),    digits = 0, source = "NORIP"),
  NPU57403 = list(label = "Creatine kinase (P)",         unit = "U/L",    draw = c(15, 900),   ref = c(32, 480),   digits = 0, source = "NORIP"),
  NPU27783 = list(label = "Alkaline phosphatase (P)",    unit = "U/L",    draw = c(15, 300),   ref = c(37, 106),   digits = 0, source = "NORIP"),
  NPU57407 = list(label = "Gamma-glutamyltransferase (P)", unit = "U/L",  draw = c(5, 300),    ref = c(9, 117),    digits = 0, source = "NORIP"),
  NPU53974 = list(label = "Amylase (P)",                 unit = "U/L",    draw = c(10, 300),   ref = c(20, 122),   digits = 0, source = "NORIP"),
  NPU57719 = list(label = "Amylase, pancreatic (P)",     unit = "U/L",    draw = c(2, 150),    ref = c(8, 71),     digits = 0, source = "NORIP"),
  NPU19658 = list(label = "Lactate dehydrogenase (P)",   unit = "U/L",    draw = c(60, 500),   ref = c(90, 210),   digits = 0, source = "NORIP"),

  # --- Not NORIP -- ordinary clinical reference ranges, not read off a
  # specific cited source (see header) ---
  NPU01536 = list(label = "Chloride (P)",                unit = "mmol/L", draw = c(85, 115),   ref = c(98, 106),   digits = 0, source = "clinical"),
  NPU28309 = list(label = "Haemoglobin (B)",             unit = "g/L",    draw = c(60, 190),   ref = c(117, 170),  digits = 0, source = "clinical"),
  NPU19748 = list(label = "C-reactive protein (P)",      unit = "mg/L",   draw = c(0, 250),    ref = c(0, 8),      digits = 1, source = "clinical"),
  NPU29296 = list(label = "Haemoglobin A1c (B, NGSP)",   unit = "%",      draw = c(4.0, 14.0), ref = c(4.0, 5.6),  digits = 1, source = "clinical"),
  NPU03577 = list(label = "Thyrotropin/TSH (P)",         unit = "mIU/L",  draw = c(0.01, 20),  ref = c(0.4, 4.0),  digits = 2, source = "clinical")
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
