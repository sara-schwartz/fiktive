\name{load_registers_schema}
\alias{load_registers_schema}
\title{Load the registers-guide schema}
\usage{
load_registers_schema(source = NULL)
}
\arguments{
\item{source}{Schema root for the DST/registers-guide half only. The
default loads the live GitHub \code{steno-aarhus/registers-guide} schema
directory. Pass a local directory that contains \code{registers/} for
offline use. Either way, the bundled DCH/DCH-NG registers are still merged
in -- this argument does not control that half.}
}
\value{
A list with \code{registers} (named by id -- DST and DCH/DCH-NG together),
\code{code_systems}, \code{families}, \code{schema_commit} (40-character SHA of the
DST half; the bundled DCH/DCH-NG metadata is versioned with the installed
fiktive package instead, not independently), and \code{schema_source}.
}
\description{
Consumes YAML at runtime. The git commit used is stamped as
\code{schema_commit}. The YAML is not vendored into the installed package.

\strong{Always also includes fiktive's own bundled DCH / DCH-NG cohort metadata}
(Diet, Cancer and Health / ...and Next Generations), merged into
the returned \code{registers} alongside the DST ones -- not a second call to
remember, and not something \code{source=} controls. This is fiktive's own
data, not registers-guide's: variable name, type, and Danish/English label
only (per KKH/DCH's data-sharing approval), shipped inside the installed
package, never fetched from or written to \code{steno-aarhus/registers-guide}.
Register ids are \code{dch}/\code{dchng} so they can never collide with a
DST register id. Each column carries a \code{dataset} field recording which
of the ~27 real underlying SAS datasets it came from (both cohorts were
originally delivered as many separate tables, not one) -- see
\code{\link{codebook}}. Generate them the same way as any DST register -- see
\code{\link{generate_register}} -- no separate function.
}
