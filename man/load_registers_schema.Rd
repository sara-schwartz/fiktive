\name{load_registers_schema}
\alias{load_registers_schema}
\title{Load the registers-guide schema}
\usage{
load_registers_schema(source = NULL)
}
\arguments{
\item{source}{Schema root. The default loads the live GitHub
\code{steno-aarhus/registers-guide} schema directory. Pass a local directory
that contains \code{registers/} for offline use.}
}
\value{
A list with \code{registers} (named by id), \code{code_systems}, \code{families},
\code{schema_commit} (40-character SHA), and \code{schema_source}.
}
\description{
Consumes YAML at runtime. The git commit used is stamped as
\code{schema_commit}. The YAML is not vendored into the installed package.
}
