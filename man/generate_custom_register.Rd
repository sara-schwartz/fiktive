\name{generate_custom_register}
\alias{generate_custom_register}
\title{Generate a custom / external register (structure only)}
\usage{
generate_custom_register(
  id,
  one_row_per,
  join_keys = NULL,
  columns,
  population,
  schema,
  from,
  to,
  seed = NULL,
  scenario = NULL,
  parent = NULL,
  cadence = NULL,
  fidelity = c("clean", "messy"),
  na_rate = NULL,
  outlier_rate = NULL
)
}
\arguments{
\item{id}{Custom register id (not looked up in schema YAML).}

\item{one_row_per}{Grain: \code{person}, \code{person_reference_date},
\code{event_from_person}, \code{expand_from_parent}, or \code{household_year}.
A novel grain is a SCHEMA GAP.}

\item{join_keys}{Join keys. Defaults to \code{pnr} for person-side grains;
required and household-side for \code{household_year}.}

\item{columns}{CSV path or tibble with \code{name}, \code{type}, and optional
\code{min}, \code{max}, \code{values}. No coefficients / raw extracts.}

\item{population}{Persons table from \code{\link{generate_background_population}}.}

\item{schema}{Schema from \code{\link{load_registers_schema}}.}

\item{from, to}{Window.}

\item{seed}{Optional RNG seed.}

\item{scenario}{Must be \code{NULL} (independence). Always attaches truth.}
\item{fidelity}{\code{"clean"} (default) or \code{"messy"}.}
\item{na_rate}{Optional override in \eqn{[0,1]}.}
\item{outlier_rate}{Optional override in \eqn{[0,1]}.}

\item{parent}{Already-generated parent table when
\code{one_row_per = "expand_from_parent"}.}

\item{cadence}{Snapshot cadence: \code{"annual"} (default) or \code{"quarterly"}.}
}
\value{
A tibble of structural noise that joins on \code{join_keys}.
}
\description{
Opt-in fidelity (\code{clean}/\code{messy}) and always-on independence truth (STEP 8a).
Front door for researcher-described tables that are not in the guide YAML.
Wraps the same grain engine as schema generation.
\code{\link{generate_register}} stays schema-ids only.
}
