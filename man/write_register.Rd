\name{write_register}
\alias{write_register}
\alias{write_registers}
\alias{register_stamps}
\title{Write generated register tables (CSV default)}
\usage{
write_register(data, path, format = c("csv", "parquet"), hive_year = FALSE)

write_registers(tables, dir, format = c("csv", "parquet"), hive_year = FALSE)

register_stamps(tbl)
}
\arguments{
\item{data}{A tibble from \code{\link{generate_register}},
\code{\link{generate_registers}}, or \code{\link{generate_custom_register}}.}

\item{path}{Output file path, or directory when \code{hive_year = TRUE}.}

\item{format}{\code{"csv"} (default) or \code{"parquet"}.}

\item{hive_year}{If \code{TRUE}, write parquet hive partitions \code{year=YYYY/}
(requires a \code{year} column and the arrow package).}

\item{tables}{Named list of tibbles.}

\item{dir}{Output directory for \code{write_registers}.}

\item{tbl}{A generated tibble.}
}
\value{
\code{write_register} / \code{write_registers} return the path / directory
invisibly. \code{register_stamps} returns a named list of stamp fields.
}
\description{
Default on-disk format is CSV. Parquet and optional hive \code{year=}
partitioning are opt-in. Stamps (schema SHA, seed, package version, catalogue
when present) are written as a \code{.meta.yaml} sidecar. Generators still
return in-memory tibbles; these helpers only persist. Never call outputs extracts.
}
