\name{schema_gap}
\alias{schema_gap}
\title{Signal a missing fact in the live schema}
\usage{
schema_gap(what, needed)
}
\arguments{
\item{what}{What is missing.}
\item{needed}{What the schema would need to supply.}
}
\description{
Stops with a message that starts with \verb{SCHEMA GAP:}. Use this instead of
inventing column names, code lists, id formats, or relationships the YAML
does not provide.
}
