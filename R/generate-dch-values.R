# Realistic value ranges/domains for DCH/DCH-NG's numeric and categorical
# columns. Without this, any DCH/DCH-NG column with no code_system hits the
# same generic fallback as any other schema-driven register (runif(0.5, 20)
# for numeric, a bare 3-digit string for character) -- fine as a structural
# placeholder, but a BMI of 4.2 or a birth-cohort weight of 0.7 kg is not
# just "unweighted", it's out of scale. Ported from a companion project's
# already-reviewed build_columns.R/families.py (same author), which built
# these for generate_custom_register() before this package's own bundled
# DCH schema (R/schema.R) existed.
#
# Two provenance tiers, as with the labka/lab_dm_forsker analyte ranges:
#
# Cited anchors (DCH): median age 56 (P5-P95 50-64); BMI 24.8 (19.9-33.6)
# women / 26.1 (21.5-32.9) men; waist 80 (67-103) / 89 (81-113) cm; energy
# 8.5 MJ/d (5.4-12.7) / 10.7 MJ/d (7.1-15.9) -- from Table 1 of:
#   Lacoppidan SA, Kyro C, Loft S, Helnaes A, Christensen J, Hansen CP,
#   Dahm CC, Overvad K, Tjonneland A, Olsen A. Adherence to a Healthy
#   Nordic Food Index Is Associated with a Lower Risk of Type-2 Diabetes --
#   The Danish Diet, Cancer and Health Cohort Study. Nutrients.
#   2015;7(10):8633-8644. doi:10.3390/nu7105418. PMID 26506373.
#
# Cited anchors (DCH-NG): mean age 50.7 (SD 7.5), 43% male; BMI 25.65 (SD
# 4.25); systolic 119.61 (SD 16.93), diastolic 83.04 (SD 11.19) mmHg; total
# cholesterol 5.21 (SD 0.97), LDL 3.21 (SD 0.88), HDL 1.59 (SD 0.46) mmol/L
# -- from Table 1 of:
#   Zhang J, Andersen C, Olsen A, Halkjaer J, Petersen KE, Schaarup JFR,
#   Antoniussen CS, Witte DR, Dahm CC. Life-long body mass index
#   trajectories and cardiometabolic biomarkers -- the Danish diet, cancer,
#   and health-next generations cohort. Int J Obes (Lond).
#   2025;49(11):2311-2319. doi:10.1038/s41366-025-01882-7. PMID 40847072.
# Both verified directly against each paper's own Table 1, not recalled or
# taken from a secondary summary.
#
# Plausible clinical/domain-knowledge tier: every other range/domain below.
# Reasonable adult bands widened for plausible abnormals (same "1st-99th
# percentile, wide enough not to be obviously wrong" philosophy as the rest
# of fiktive), not individually literature-cited the way the anchors above
# are. The nutrient/food-group/amino-acid/fatty-acid tables live in
# R/generate-dch-nutrients.R.
#
# Categorical `values` are plausible, DOCUMENTED GUESSES, not read off a
# real code list: neither KKH/DCH catalogue publishes one (variable name,
# type and label only were shared -- see R/schema.R). Getting the real
# codings requires going back to KKH/DCH; until then these exist so a
# column at least draws a small, structurally plausible set (e.g. smoking
# status as 1/2/3) instead of meaningless noise. Do not treat a specific
# level as confirmed -- e.g. `rygning`'s 1/2/3 order (never/former/current)
# is unverified, `kqn`'s coding is unknown and was dropped rather than
# guessed here (see R/schema.R) precisely because -- unlike these -- it
# would contradict bef's koen if guessed wrong.
#
# Column ids below are unique within "dch" and within "dchng" (the two
# collapsed registers -- see data-raw/collapse_dch_registers.R), so a flat
# name-keyed lookup is safe: no id repeats across the ~8 (dch) or ~19
# (dchng) real underlying datasets each is merged from.

.DCH_NUMERIC_OVERRIDES <- list(
  # --- journal: identifiers, visit, anthropometry, clinical ---
  id = c(1, 60000), age = c(50, 65), alderind = c(18250, 23750),
  stahqjde = c(148, 200), sidhqjde = c(75, 105), vaegt = c(42, 145),
  livvidde = c(62, 135), hofvidde = c(78, 145), blodtsys = c(90, 200),
  blodtdia = c(50, 120), blodpklo = c(700, 1800), blodprqv = c(2.8, 9.5),
  # --- afledte: body composition, smoking, alcohol, activity ---
  ffm = c(32, 75), bfm = c(5, 65), fat_pct = c(8, 55), bmi = c(17, 45),
  ratio = c(0.65, 1.25), rygestart = c(8, 60), rygestop = c(12, 64),
  varighed = c(0, 50), tidophqr = c(0, 45), forbrug = c(0, 60),
  packyear = c(0, 80), c_forbrug = c(0, 900000), alk_cu_alko = c(0, 60000),
  alk_c_alko = c(0, 60), tsport = c(0, 20), met = c(0, 150),
  sommer = c(0, 60), vinter = c(0, 60), aar_hrt = c(0, 30),
  ant_bqrn = c(0, 8), ant_fqds = c(0, 8), mdiets = c(0, 8), hnfi = c(0, 6),
  # --- nutri6ny/nutri: energy and macronutrients (overrides beat the
  # nutrient-stem family lookup for these headline totals) ---
  energi = c(4000, 18000), energx = c(3800, 17500), alko = c(0, 150),
  fedt = c(20, 200), prot = c(30, 200), suktil = c(0, 150), kfibre = c(5, 60),
  # --- bagskema: weight history, reproduction ---
  s32a01n = c(40, 130), s32b01n = c(42, 135), s32c01n = c(44, 140), s32d01n = c(45, 145),
  s33x01n = c(9, 20), s34x01n = c(20, 60), s35x01n = c(0, 13), s37x01n = c(35, 64),
  # --- dtqst_wholegrain_dk, g/day ---
  vaegtc = c(800, 6000), whg_tot_dq = c(0, 250), wheat_dq = c(0, 130),
  rye_dq = c(0, 150), oat_dq = c(0, 100), whg_othr_dq = c(0, 60),

  # --- DCH-NG: diet totals ---
  alder = c(18, 75), energitot = c(3500, 19000), energitotxalko = c(3300, 18000),
  fuldkorn = c(0, 250),
  # --- lsq_fysakt/lsq_afledte: activity ---
  fa14_02 = c(0, 20), fa02 = c(0, 70), arbfa01 = c(0, 80), arbfa04_02_h = c(0, 15),
  sid01 = c(0, 20), sid02 = c(0, 20),
  # --- lsq_sovn: sleep ---
  sovn20 = c(3, 12), sovn21 = c(3, 12), sovn03 = c(0, 120), sovn06 = c(0, 120),
  # --- study-centre questionnaire/measurements ---
  scq04 = c(0, 48), scq06 = c(0, 72),
  # faecal sample: clock time, hhmm (same representation caveat as journal's
  # blodpklo -- the catalogue doesn't say what the real encoding is)
  fsq00_02 = c(0, 2359),
  schrm01 = c(85, 195), schrm02 = c(50, 118), schrm03 = c(40, 110),
  scant01 = c(60, 140), scant02 = c(78, 150),
  scbia01 = c(16, 45), scbia02 = c(42, 150), scbia03 = c(148, 200),
  scbia04 = c(8, 55), scbia05 = c(5, 70), scbia06 = c(0.2, 9), scbia07 = c(35, 80),
  scbia08 = c(18, 50), scbia08_01 = c(1.5, 5), scbia08_02 = c(5, 14),
  scbia08_03 = c(1.5, 5), scbia08_04 = c(5, 14), scbia08_05 = c(8, 25),
  scbia20 = c(45, 70), scbia21 = c(8, 22), scbia22 = c(12, 32), scbia23 = c(22, 55),
  # --- blood biomarkers ---
  crea = c(40, 120), cho = c(2.8, 9.0), ldl = c(0.8, 6.5), hdl = c(0.6, 3.2),
  hscrp = c(0.1, 20), tg = c(0.3, 7.0), hba1cpc = c(4.0, 9.0), hba1cmm = c(20, 75)
)

.DCH_INTEGER_COLS <- c(
  "id", "alderind", "blodpklo", "rygestart", "rygestop", "ant_bqrn", "ant_fqds",
  "mdiets", "hnfi", "s33x01n", "s34x01n", "s35x01n", "s37x01n", "schrm03", "fsq00_02"
)

YESNO_01 <- c(0L, 1L)

.DCH_CATEGORICAL_OVERRIDES <- list(
  center = c("KBH", "AAR"),
  fedtbiop = YESNO_01, ualbumin = 0:3, usukker = 0:3, ublod = 0:3,
  rygning = 1:3, rygepause = YESNO_01, alk_stat = 0:2, outdoor = YESNO_01,
  nsaid = YESNO_01, nsaid_exclasp = YESNO_01, nsaid_onlyasp = YESNO_01,
  menopaus = c("pre", "peri", "post"), menstruation = YESNO_01,
  hrt = c("never", "former", "current"), fasting = c("fasting", "non-fasting"),
  lav_sko = YESNO_01, mel_sko = YESNO_01, hqj_sko = YESNO_01,
  s15x01n = 1:6,

  # Sub-cohort flags: MAX is 720 of ~39,554 participants (~2%); DiGuMeT's
  # size is unpublished, same order assumed (weighted via repetition -- see
  # dch_value_noise()).
  ismax = c(rep(0L, 49), 1L), isdigumet = c(rep(0L, 49), 1L),
  ryg01_bin = YESNO_01, nic01_bin = YESNO_01, nic02_bin = YESNO_01,
  ryg01_cat = 0:2, nic01_cat = 0:2, nic02_cat = 0:2,
  fa14_01 = YESNO_01, fa01 = 1:4, fa12 = 1:5, fa13 = YESNO_01,
  arbfa04_02_g = YESNO_01, hae01 = 1:3, hae02 = 1:5, sovn08 = 1:5,
  aff01 = 1:5, aff02 = 1:5, aff03 = 1:5, aff04 = 1:5, aff05 = 1:5,
  aff06 = 1:7, aff07 = YESNO_01,
  fsq01 = 1:7, fsq02 = YESNO_01, fsq03 = 1:5, fsq04 = 1:6,
  scq01 = YESNO_01, scq02 = YESNO_01, scq03 = YESNO_01, scq05 = YESNO_01,
  scq07 = YESNO_01, scq08 = 1:5, scq09 = 1:6, scq10 = YESNO_01,
  scq11 = YESNO_01, scq12 = YESNO_01, scq14 = 1:5, scq15 = 1:5,
  schrm06 = 1:6, schrm07 = YESNO_01, schrm08 = 1:3, schrm09 = YESNO_01,
  scbia04_89 = YESNO_01, scbia06_88 = YESNO_01, scbia06_89 = YESNO_01,
  ldl_reagens = 1:2, hdl_reagens = 1:2
)

# 50 harmonised food groups shared by dch's own "foods6ny" dataset and
# dchng's own "vaegtc" dataset (see each column's `dataset` field), g/day.
.DCH_VAEGTC <- list(
  `1` = c(0, 200), `2` = c(0, 300), `3` = c(0, 500), `4` = c(0, 250), `5` = c(0, 250),
  `6` = c(0, 100), `7` = c(0, 100), `8` = c(0, 150), `9` = c(0, 150), `10` = c(0, 300),
  `11` = c(0, 600), `12` = c(0, 60), `13` = c(0, 350), `14` = c(0, 300), `15` = c(0, 250),
  `17` = c(0, 150), `18` = c(0, 150), `19` = c(0, 120), `20` = c(0, 1000), `21` = c(0, 500),
  `22` = c(0, 500), `23` = c(0, 500), `24` = c(0, 300), `25` = c(0, 200), `26` = c(0, 100),
  `27` = c(0, 60), `28` = c(0, 60), `29` = c(0, 80), `30` = c(0, 40), `31` = c(0, 100),
  `32` = c(0, 100), `33` = c(0, 80), `34` = c(0, 1500), `35` = c(0, 2500), `36` = c(0, 1500),
  `37` = c(0, 1200), `38` = c(0, 600), `39` = c(0, 1500), `40` = c(0, 150), `41` = c(0, 80),
  `42` = c(0, 200), `43` = c(0, 100), `44` = c(0, 150), `45` = c(0, 150), `46` = c(0, 150),
  `47` = c(0, 150), `48` = c(0, 150), `49` = c(0, 150), `60` = c(0, 300)
)

# dch's "foods6ny" dataset summary totals, g/day.
.DCH_FOOD_TOTALS <- list(
  allfruit = c(0, 800), allplant = c(0, 1500), allpotat = c(0, 500),
  allvegs = c(0, 800), fatfoods = c(0, 500), fishfat = c(0, 200),
  fishlean = c(0, 200), fishmid = c(0, 200), fishtot = c(0, 350),
  fruit = c(0, 700), vegs = c(0, 600), juices = c(0, 600),
  meattot = c(0, 500), meatwhit = c(0, 300), totcerea = c(0, 500),
  totdiary = c(0, 1200)
)

dch_food_group_range <- function(name) {
  m <- regmatches(name, regexec("^vaegtc(\\d{2})$", name))[[1]]
  if (length(m) == 2) {
    n <- as.character(as.integer(m[[2]]))
    if (!is.null(.DCH_VAEGTC[[n]])) {
      return(.DCH_VAEGTC[[n]])
    }
  }
  .DCH_FOOD_TOTALS[[name]]
}

# FFQ item-level columns (dch's own "gpd6" dataset has g0300x-style ids;
# dchng's own "ffq_gpd" dataset has prefixed/suffixed ids -- see each
# column's `dataset` field) ranged by id shape, since there are hundreds
# of individual food items with no per-item catalogue range. The two id
# shapes never overlap (confirmed directly against the source catalogues),
# so this doesn't need to know which of the two collapsed registers (dch
# vs. dchng) it's running on, only the column name.
dch_ffq_item_range <- function(name) {
  if (grepl("^g03\\d{3}$", name)) {
    return(if (startsWith(name, "g030")) c(0, 2500) else c(0, 300))
  }
  if (endsWith(name, "sodest")) return(c(0, 12))
  if (endsWith(name, "sukker")) return(c(0, 40))
  if (endsWith(name, "maelk") || endsWith(name, "flode")) return(c(0, 250))
  if (startsWith(name, "gdri")) return(c(0, 2000))
  if (startsWith(name, "gfedtfpb") || startsWith(name, "gsod") ||
        startsWith(name, "gdre") || startsWith(name, "gttd")) {
    return(c(0, 60))
  }
  NULL
}

# Misc regex-matched column families (tobacco/alcohol history by decade,
# self-report questionnaire blocks, passive-smoking exposure, etc.) that
# aren't individually worth naming in .DCH_NUMERIC_OVERRIDES.
dch_family_numeric_range <- function(name) {
  if (grepl("^forbrug\\d{2}$", name)) return(c(0, 60))              # tobacco g/day, a decade
  if (grepl("^c_forbrug\\d{2}$", name)) return(c(0, 250000))        # cumulative g, a decade
  if (grepl("^alk_pause\\d{2}$", name)) return(c(0, 10))            # years off alcohol
  if (grepl("^alk_(ol|vin|hedvin|spir)\\d{2}$", name)) return(c(0, 80))
  if (grepl("^alk_total\\d{2}$", name)) return(c(0, 150))
  if (grepl("^alk_(alksum|alko)\\d{2}$", name)) return(c(0, 80))
  if (grepl("^al_\\dbarn$", name)) return(c(15, 45))                # age at nth child
  if (grepl("^t(gang|cykel|husarb|gqrselv|havearb)$", name)) return(c(0, 30)) # hours/week
  m <- regmatches(name, regexec("^s\\d{2}[a-z]0(\\d)n$", name))[[1]]
  if (length(m) == 2) return(if (m[[2]] == "2") c(10, 64) else YESNO_01)
  m <- regmatches(name, regexec("^s\\d{2}x0(\\d)n$", name))[[1]]
  if (length(m) == 2) return(if (m[[2]] == "2") c(10, 64) else YESNO_01)
  if (grepl("^energitot\\d{2}$", name)) return(c(0, 3500))          # energy from a food group
  if (grepl("^pas0[1-8]$", name)) return(YESNO_01)
  if (grepl("^pas(09|1[0-5])$", name)) return(c(0, 12))             # hours/day exposed
  if (grepl("^arb03_[a-z](_\\d{2}|_andet)?$", name)) return(c(0, 45)) # years in the job
  if (grepl("^fa20_\\d{2}_c$", name)) return(c(0, 10))              # hours/week per sport
  NULL
}

dch_family_categorical <- function(name) {
  if (grepl("^ktsk_grp_\\d{2}$", name)) return(YESNO_01)            # supplement taken
  if (name %in% c("gang", "cykel", "husarb", "gqrselv", "havearb", "sport")) return(YESNO_01)
  if (grepl("^sovn07_\\d{2}$", name)) return(1:5)                   # 5-point frequency
  if (grepl("^syg0[1-4]_[a-z](_[a-z]+)?$", name)) return(YESNO_01)
  if (grepl("^arb02_[a-z]$", name)) return(YESNO_01)
  if (grepl("^arb04_k_\\d{2}$", name) || identical(name, "arb04_k_andet")) return(YESNO_01)
  if (endsWith(name, "_abnormalflag")) return(c("N", "L", "H"))
  if (endsWith(name, "_status")) return(c("valid", "invalid", "missing"))
  NULL
}

dch_numeric_range <- function(register_id, name) {
  if (!register_id %in% dch_register_ids()) {
    return(NULL)
  }
  ov <- .DCH_NUMERIC_OVERRIDES[[name]]
  if (!is.null(ov)) {
    return(ov)
  }
  fg <- dch_food_group_range(name)
  if (!is.null(fg)) {
    return(fg)
  }
  ffq <- dch_ffq_item_range(name)
  if (!is.null(ffq)) {
    return(ffq)
  }
  fam <- dch_family_numeric_range(name)
  if (!is.null(fam)) {
    return(fam)
  }
  dch_nutrient_range(name)
}

dch_categorical_values <- function(register_id, name) {
  if (!register_id %in% dch_register_ids()) {
    return(NULL)
  }
  ov <- .DCH_CATEGORICAL_OVERRIDES[[name]]
  if (!is.null(ov)) {
    return(ov)
  }
  dch_family_categorical(name)
}

# value/domain noise for a DCH/DCH-NG column -- called from typed_noise()
# before its generic numeric/character fallback. Returns NULL (caller keeps
# its existing behaviour) for a column not covered above.
dch_value_noise <- function(register_id, name, type, n) {
  if (is.null(register_id) || !nzchar(register_id) || n == 0L) {
    return(NULL)
  }
  cat_values <- dch_categorical_values(register_id, name)
  if (!is.null(cat_values)) {
    drawn <- sample(cat_values, n, replace = TRUE)
    return(if (type %in% c("integer", "numeric")) as.numeric(drawn) else as.character(drawn))
  }
  rng <- dch_numeric_range(register_id, name)
  if (is.null(rng)) {
    return(NULL)
  }
  if (name %in% .DCH_INTEGER_COLS || identical(type, "integer")) {
    return(sample(rng[[1]]:rng[[2]], n, replace = TRUE))
  }
  stats::runif(n, rng[[1]], rng[[2]])
}
