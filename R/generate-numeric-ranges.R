# Curated, per-column plausible ranges for numeric/integer schema columns
# that have no code_system and aren't already derived from a known fact
# (age, dates -- see derived_column() in R/generate-columns.R). Without
# this, typed_noise()'s generic numeric fallback (runif(0.5, 20)) applies
# regardless of what the column actually measures -- fine as a placeholder
# for an arbitrary DKK amount, badly wrong for e.g. gestational age in days
# (real range ~154-300) or birth weight in grams (real range ~400-5500),
# which is not "structural noise, uniform not weighted" (fiktive's
# documented default -- see vignette("fiktive")) but simply an
# out-of-scale, implausible value regardless of that philosophy.
#
# Deliberately a curated subset, not exhaustive -- a column absent here
# still falls back to the pre-existing generic noise. Ranges are plausible
# adult/clinical/administrative bands from common domain knowledge (parity,
# hospital length-of-stay, household size, ...), not from a published
# per-variable source the way the labka/lab_dm_forsker analyte ranges are
# (see R/catalogue-labterm-analytes.R) -- these are administrative/
# demographic/anthropometric facts with no single authoritative reference
# range the way a lab test has, unlike e.g. NORIP for blood analytes.
.NUMERIC_COLUMN_RANGES <- list(
  # mfr (and its still-unimplemented child tables, which share these
  # column names for the same concepts: mfr_nyfoedte, mfrdfoed, mfrhjmfo,
  # ftbarn)
  gestationsalder_dage           = list(min = 154, max = 300, integer = TRUE),  # days; ~22-43 weeks
  vaegt_barn                     = list(min = 400, max = 5500, integer = TRUE), # grams
  hovedomfang                    = list(min = 26, max = 38, digits = 1),        # cm
  apgarscore_efter5minutter      = list(min = 0, max = 10, integer = TRUE),
  placentavaegt                  = list(min = 200, max = 1500, integer = TRUE), # grams
  vaegt_moder                    = list(min = 45, max = 150, digits = 1),       # kg
  hoejde_moder                   = list(min = 145, max = 195, integer = TRUE),  # cm
  bmi_moder                      = list(min = 15, max = 50, digits = 1),
  abdominalomfang                = list(min = 20, max = 40, digits = 1),        # cm
  alder_moder                    = list(min = 14, max = 55, integer = TRUE),    # years -- no maternal
  alder_fader                    = list(min = 14, max = 75, integer = TRUE),    # birth date on this
  paritet                        = list(min = 0, max = 8, integer = TRUE),      # table to derive from
  sengedage_beregnet_barn        = list(min = 0, max = 60, integer = TRUE),     # days
  sengedage_beregnet_moder       = list(min = 0, max = 14, integer = TRUE),     # days
  sengedage_neonatalafdeling_barn = list(min = 0, max = 90, integer = TRUE),    # days
  barnslevendenr_flerfoldfoedsel = list(min = 1, max = 4, integer = TRUE),
  barnsnummer_flerfoldsfoedsel   = list(min = 1, max = 4, integer = TRUE),
  alderveddoed_dage_barn         = list(min = 0, max = 365, integer = TRUE),    # days
  foedselsloebenummer            = list(min = 1, max = 5, integer = TRUE),

  # bef
  antboernf = list(min = 0, max = 6, integer = TRUE),
  antboernh = list(min = 0, max = 6, integer = TRUE),
  antpersf  = list(min = 1, max = 8, integer = TRUE),
  antpersh  = list(min = 1, max = 8, integer = TRUE),
  antefam   = list(min = 1, max = 3, integer = TRUE),
  opholdmd_dk = list(min = 0, max = 960, integer = TRUE), # months (up to 80 years)

  # sysi/sssy
  ydlant  = list(min = 1, max = 10, integer = TRUE),
  bruhon  = list(min = 50, max = 2000, integer = TRUE),   # DKK, primary-care fee
  kontakt = list(min = 1, max = 10, integer = TRUE),

  # lpr_adm/t_psyk_adm (and lpr_afl/t_psyk_afl/*_sksopr/*_sksube, which
  # share the v_ominut/v_otime timing columns for the same concept)
  v_sengdage = list(min = 0, max = 60, integer = TRUE),   # bed-days
  v_behdage  = list(min = 0, max = 60, integer = TRUE),   # treatment days
  v_indminut = list(min = 0, max = 59, integer = TRUE),   # minute of admission hour
  v_indtime  = list(min = 0, max = 23, integer = TRUE),   # hour of admission
  v_udtime   = list(min = 0, max = 23, integer = TRUE),   # hour of discharge
  v_ominut   = list(min = 0, max = 59, integer = TRUE),   # minute of procedure hour
  v_otime    = list(min = 0, max = 23, integer = TRUE),   # hour of procedure

  # lpr_a_kontakt: unambiguously binary from its own label ("Contact closed
  # flag"), unlike e.g. bef's opr_land/statsb or faik's famboligtype/
  # famsociogrup (also role=code, no code_system, but a real DST
  # classification of unknown cardinality -- guessing a range for those
  # risks being confidently wrong in a way a 0/1 flag can't be).
  flag_kont_afsluttet = list(min = 0, max = 1, integer = TRUE)
)

# Draws n values in a curated column's plausible range, or NULL if `name`
# isn't curated (caller keeps its existing generic fallback). See
# .NUMERIC_COLUMN_RANGES above.
numeric_range_noise <- function(name, n) {
  r <- .NUMERIC_COLUMN_RANGES[[name]]
  if (is.null(r) || n == 0L) {
    return(NULL)
  }
  if (isTRUE(r$integer)) {
    return(sample(r$min:r$max, n, replace = TRUE))
  }
  digits <- r$digits %||% 1L
  round(stats::runif(n, r$min, r$max), digits)
}

# Character columns whose own label says "flag" but declare no code_system
# and no values_from -- registers-guide has checked and found no published
# domain for these (see e.g. flag_valideret/flag_proc_uden_kont's own YAML
# comments), the same "unpublished value set" situation as borger_koen.
# Unlike borger_koen, though, the label leaves little doubt these are
# binary -- so unlike that NA+warning treatment, draw a plausible 0/1 (as
# a character, matching the column's declared type) rather than a bare
# 3-digit code, clearly flagged as an unconfirmed guess at the real
# encoding (could equally be J/N, Y/N, or something else in a real
# delivery).
.CHARACTER_FLAG_COLUMNS <- c("flag_valideret", "flag_proc_uden_kont")

character_flag_noise <- function(name, n) {
  if (n == 0L || !name %in% .CHARACTER_FLAG_COLUMNS) {
    return(NULL)
  }
  sample(c("0", "1"), n, replace = TRUE)
}
