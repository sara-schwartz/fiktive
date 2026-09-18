# Plausible daily-intake ranges for KKH/KKHNG nutrient columns, keyed on the
# lowercased nutrient stem before any _ffq / _ktsk / _tot suffix. Ported from
# a companion project's already-reviewed nutrient_ranges.py (same author),
# which anchors these on Danish adult intakes: DANSDA (the national dietary
# survey) and the Nordic Nutrition Recommendations reference intakes. Not
# individually re-verified against DANSDA/NNR the way the NORIP lab ranges
# are against their source table -- these are the "plausible clinical"
# tier, not the "read off a cited table" tier (see
# R/catalogue-labterm-analytes.R for that distinction).
#
# stem -> c(diet_min, diet_max, supplement_max); supplement_max = NA means no
# supplement (_ktsk) form exists for that nutrient.
.KKH_NUTRIENTS <- list(
  avit = c(200, 3000, 2500), retino = c(100, 1800, 2000), retinol = c(100, 1800, 2000),
  betaca = c(300, 9000, 15000), cvit = c(20, 300, 1500), evit = c(3, 25, 300),
  alfato = c(3, 25, 300), dvit = c(0.5, 20, 100), kvit = c(20, 350, NA),
  k1vit = c(20, 350, 200), thiami = c(0.5, 3.5, 50), thiamin = c(0.5, 3.5, 50),
  b1vit = c(0.5, 3.5, 50), ribofl = c(0.6, 4, 50), b2vit = c(0.6, 4, 50),
  niacin = c(10, 60, 100), niacin2 = c(8, 45, 100), neniac = c(15, 70, NA),
  b6vit = c(0.6, 4, 100), pantot = c(2, 12, 50), pantothen = c(2, 12, 50),
  biotin = c(10, 90, 200), folaci = c(100, 700, 800), folat = c(100, 700, 800),
  frifolat = c(30, 350, NA), b12vit = c(1, 20, 100),
  calciu = c(300, 2200, 1500), ca = c(300, 2200, 1500), jern = c(4, 30, 100),
  fe = c(4, 30, 100), zink = c(4, 25, 50), zn = c(4, 25, 50),
  magnes = c(150, 700, 600), mg = c(150, 700, 600), kalium = c(1200, 6000, 1000),
  ka = c(1200, 6000, 1000), natriu = c(1000, 7000, 500), na = c(1000, 7000, 500),
  fosfor = c(600, 3000, 800), p = c(600, 3000, 800), selen = c(15, 120, 300),
  se = c(15, 120, 300), jod = c(40, 350, 200), i = c(40, 350, 200),
  kobber = c(0.5, 3.5, 3), cu = c(0.5, 3.5, 3), mangan = c(1, 9, 10),
  mn = c(1, 9, 10), chrom = c(10, 150, 200), cr = c(10, 150, 200),
  nikkel = c(30, 450, NA), ni = c(30, 450, NA)
)

# Carbohydrate/sugar fractions and other bulk components, g/d unless noted.
.KKH_BULK <- list(
  cho = c(50, 500), kulhy = c(50, 500), kulhtil = c(50, 500), kulhtilx = c(50, 500),
  stivel = c(40, 350), stivelse = c(40, 350), sukker = c(30, 250), totsukker = c(30, 250),
  andresukker = c(0, 15), saccha = c(10, 130), sacchros = c(10, 130), glukos = c(3, 50),
  glucos = c(3, 50), frukto = c(3, 55), fructo = c(3, 55), galacto = c(0, 4),
  laktos = c(0, 40), lactos = c(0, 40), maltos = c(0, 12), raffinose = c(0, 3),
  monosaccha = c(5, 90), disacchar = c(10, 140), sukkeralko = c(0, 20),
  orgsyrertot = c(0.5, 10), aske = c(10, 40), vand = c(1000, 4500),
  kfibre = c(5, 60), choles = c(50, 800), hydprolin = c(0, 1.5)
)

# Amino acids, mg/d.
.KKH_AMINO <- list(
  isoleu = c(1500, 6000), leucin = c(2500, 10000), lysin = c(2000, 9000),
  methio = c(600, 3000), cystin = c(400, 2200), phenyl = c(1500, 6000),
  thyros = c(1200, 5000), threon = c(1500, 5500), trypto = c(400, 1800),
  valin = c(1800, 7000), argini = c(1500, 7000), histid = c(900, 4000),
  alanin = c(1500, 7000), aspara = c(2500, 11000), glutam = c(5000, 22000),
  glycin = c(1500, 7000), prolin = c(2000, 9000), serin = c(1500, 6500)
)

# Fatty-acid sums and the individually large ones, g/d.
.KKH_FA_SUMS <- list(
  total_fa = c(20, 170), sum_sfa = c(8, 70), sum_mufa = c(7, 60), sum_pufa = c(3, 35),
  total_transfa = c(0.2, 6), sum_n3fa = c(0.5, 8), sum_n6fa = c(3, 30),
  fedtms = c(8, 70), fedtus = c(7, 60), fedtps = c(3, 35), fiskn3 = c(0, 6)
)

.KKH_FA_INDIVIDUAL <- list(
  c4x0 = c(0, 2), c6x0 = c(0, 1.2), c8x0 = c(0, 1), c10x0 = c(0, 1.5),
  c12x0 = c(0, 3), c14x0 = c(0.3, 8), c15x0 = c(0, 1),
  c16x0 = c(4, 35), c17x0 = c(0, 0.8), c18x0 = c(1.5, 15),
  c20x0 = c(0, 0.5), c22x0 = c(0, 0.5), c24x0 = c(0, 0.3),
  c16x1n7 = c(0.2, 4), c18x1n9 = c(6, 50), c18x1n7 = c(0.3, 4),
  c20x1n9 = c(0, 1.5), c22x1n9 = c(0, 1), c24x1n9 = c(0, 0.4),
  c18x2n6 = c(2.5, 28), c18x3n3 = c(0.3, 5), c18x3n6 = c(0, 0.3),
  c20x4n6 = c(0, 0.5), c20x3n6 = c(0, 0.3),
  c20x5n3 = c(0, 2), c22x5n3 = c(0, 0.8), c22x6n3 = c(0, 3),
  c18x1_tran = c(0.1, 4), c18x2_tran = c(0, 1), c16x1_tran = c(0, 0.5),
  andre_sfa = c(0, 2), andre_mufa = c(0, 2), andr_pufa = c(0, 2), andre_fa = c(0, 3)
)
.KKH_FA_TRACE <- c(0, 0.4)

# Energy contributed by a macronutrient, kJ/day.
.KKH_ENERGY_FROM <- list(
  prote = c(400, 3500), fedte = c(700, 8000), kulhye = c(800, 8000),
  kulhtile = c(800, 8000), kulhtilxe = c(800, 8000), kulhtote = c(900, 8500),
  alkoe = c(0, 4000), kfibree = c(50, 800), orgsyrere = c(5, 350), sukkeralkoe = c(0, 400)
)

# Share of total energy, %.
.KKH_ENERGY_PCT <- list(
  protep = c(8, 25), protexp = c(8, 26), fedtep = c(15, 55), fedtexp = c(15, 57),
  kulhyep = c(25, 65), kulhyexp = c(25, 67), kulhtilxep = c(25, 65), kulhtotep = c(28, 68),
  kfibreep = c(0.5, 6), alkoep = c(0, 30), orgsyrerep = c(0, 3), sukkeralkoep = c(0, 3)
)

# Range for a nutrient column, honouring _ffq / _ktsk / _tot suffixes. Returns
# NULL if `name` isn't a recognised nutrient stem.
kkh_nutrient_range <- function(name) {
  stem <- name
  suffix <- ""
  for (suf in c("_ffq", "_ktsk", "_tot")) {
    if (endsWith(name, suf)) {
      stem <- substr(name, 1, nchar(name) - nchar(suf))
      suffix <- suf
      break
    }
  }
  if (!is.null(.KKH_NUTRIENTS[[stem]])) {
    v <- .KKH_NUTRIENTS[[stem]]
    lo <- v[[1]]; hi <- v[[2]]; supp <- v[[3]]
    if (identical(suffix, "_ktsk")) {
      return(c(0, if (is.na(supp)) hi else supp))
    }
    if (identical(suffix, "_tot") && !is.na(supp)) {
      return(c(lo, hi + supp))
    }
    return(c(lo, hi))
  }
  for (tbl in list(.KKH_BULK, .KKH_AMINO, .KKH_FA_SUMS, .KKH_FA_INDIVIDUAL)) {
    if (!is.null(tbl[[stem]])) {
      return(tbl[[stem]])
    }
  }
  # Any remaining C<n>x<m> fatty acid is a trace component.
  if (grepl("^c\\d{1,2}x\\d(_(tran|conj))?(n\\d{1,2})?$", stem)) {
    return(.KKH_FA_TRACE)
  }
  if (!is.null(.KKH_ENERGY_FROM[[stem]])) {
    return(.KKH_ENERGY_FROM[[stem]])
  }
  if (!is.null(.KKH_ENERGY_PCT[[stem]])) {
    return(.KKH_ENERGY_PCT[[stem]])
  }
  NULL
}
