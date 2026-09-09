\name{generate_register}
\alias{generate_register}
\title{Generate a fictitious register table}
\usage{
generate_register(
  register,
  population,
  schema,
  from,
  to,
  seed = NULL,
  scenario = NULL,
  fidelity = c("clean", "messy"),
  na_rate = NULL,
  outlier_rate = NULL
)
}
\arguments{
\item{register}{Lowercase register id (fastreg name), e.g. \code{"bef"}.}
\item{population}{Persons table from \code{\link{generate_background_population}}.}
\item{schema}{Schema from \code{\link{load_registers_schema}}.}
\item{from}{Start of the requested window.}
\item{to}{End of the requested window.}
\item{seed}{Optional RNG seed. Restored on exit.}
\item{scenario}{Must be \code{NULL} (independence). Always attaches truth.}
\item{fidelity}{\code{"clean"} (default) or \code{"messy"}.}
\item{na_rate}{Optional override in \eqn{[0,1]}.}
\item{outlier_rate}{Optional override in \eqn{[0,1]}.}
}
\value{
A tibble whose columns are a subset of the schema column names for \code{register}.
Zero rows is a valid event or child table.
}
\description{
\code{scenario = NULL} is independence. Snapshot grains: \code{bef} (quarterly),
\code{udda} and \code{akm} (annual). Event-from-person: \code{dod}, \code{lmdb},
\code{vnds}, \code{cancer}, \code{mfr} (Levendefoedte; coverage ends 2018),
\code{lab_dm_forsker} (LabTerm / published NPU for \code{analysiscode}; coverage 2008--2025).
Expand-from-parent: LPR2 (\code{lpr_adm} then
\code{lpr_diag} / \code{lpr_sksopr} / \code{lpr_sksube}) and LPR3
(\code{lpr_a_kontakt} then \code{lpr_a_diagnose} / \code{lpr_a_procregistrering})
off the same contact table. Household-year: \code{faik}. Branch on
\code{code_system}: plain \code{icd10} (cancer) samples
\code{codeCollection::ICD10Koodit}; \code{icd10_sks} samples sksr Prefix dia.
Psych LPR (\code{t_psyk_*}) is not this step. Never mix \code{vnds} with
\code{vnds_hist}/\code{vnds_ind}/\code{vnds_ud}.
}
