#' @title Build DRB Project Architecture HTML Source Snapshot
#' @description Inject every repository R source file into the architecture HTML.

args <- commandArgs(trailingOnly = TRUE)
project_dir <- if (length(args) > 0L && nzchar(args[[1L]])) args[[1L]] else getwd()
project_dir <- normalizePath(project_dir, winslash = "/", mustWork = TRUE)
html_path <- file.path(project_dir, "docs", "ko", "PROJECT_CODE_ARCHITECTURE.html")

if (!file.exists(html_path)) {
    stop("Architecture HTML not found: ", html_path)
}

normalize_relative_path <- function(path, root) {
    normalized <- normalizePath(path, winslash = "/", mustWork = TRUE)
    prefix <- paste0(sub("/$", "", root), "/")
    if (!startsWith(normalized, prefix)) {
        stop("Source file is outside the project: ", normalized)
    }
    substring(normalized, nchar(prefix) + 1L)
}

source_order_group <- function(path) {
    if (identical(path, "run_gui.R")) return(1L)
    if (identical(path, "run.R")) return(2L)
    if (identical(path, "main.R")) return(3L)
    if (startsWith(path, "config/")) return(10L)
    if (startsWith(path, "src/bootstrap/")) return(20L)
    if (grepl("^src/[0-9]{2}_", path)) return(30L)
    if (startsWith(path, "src/gui/")) return(40L)
    if (startsWith(path, "src/metrics/")) return(50L)
    if (startsWith(path, "tools/")) return(60L)
    99L
}

extract_function_names <- function(lines) {
    pattern <- "^\\s*([A-Za-z.][A-Za-z0-9._]*)\\s*<-\\s*function\\b"
    matches <- regexec(pattern, lines, perl = TRUE)
    parts <- regmatches(lines, matches)
    unique(vapply(
        parts[lengths(parts) >= 2L],
        function(value) value[[2L]],
        character(1L)
    ))
}

escape_html <- function(value) {
    value <- gsub("&", "&amp;", value, fixed = TRUE)
    value <- gsub("<", "&lt;", value, fixed = TRUE)
    gsub(">", "&gt;", value, fixed = TRUE)
}

escape_attribute <- function(value) {
    value <- escape_html(value)
    value <- gsub('"', "&quot;", value, fixed = TRUE)
    gsub("'", "&#39;", value, fixed = TRUE)
}

r_paths <- list.files(
    project_dir,
    pattern = "[.]R$",
    recursive = TRUE,
    full.names = TRUE,
    all.files = FALSE
)
r_paths <- r_paths[!grepl("/(output|data|[.]git|[.]Rproj[.]user)/", gsub("\\\\", "/", r_paths))]
relative_paths <- vapply(r_paths, normalize_relative_path, character(1L), root = project_dir)
ordering <- order(vapply(relative_paths, source_order_group, integer(1L)), relative_paths)
r_paths <- r_paths[ordering]
relative_paths <- relative_paths[ordering]

source_records <- lapply(seq_along(r_paths), function(index) {
    lines <- readLines(r_paths[[index]], warn = FALSE, encoding = "UTF-8")
    lines <- sub("[[:blank:]]+$", "", lines)
    list(
        path = relative_paths[[index]],
        lines = lines,
        functions = extract_function_names(lines)
    )
})

templates <- vapply(source_records, function(record) {
    paste0(
        '<template class="r-source-template" data-path="',
        escape_attribute(record$path),
        '" data-lines="',
        length(record$lines),
        '" data-functions="',
        escape_attribute(paste(record$functions, collapse = "|")),
        '">',
        paste(escape_html(record$lines), collapse = "\n"),
        '</template>'
    )
}, character(1L))

start_marker <- "<!-- R_SOURCE_DATA_START -->"
end_marker <- "<!-- R_SOURCE_DATA_END -->"
html <- paste(readLines(html_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
start_pos <- regexpr(start_marker, html, fixed = TRUE)[[1L]]
end_pos <- regexpr(end_marker, html, fixed = TRUE)[[1L]]
if (start_pos < 1L || end_pos < 1L || end_pos <= start_pos) {
    stop("Source data markers are missing or out of order in: ", html_path)
}

generated_block <- paste(
    start_marker,
    paste0("<!-- Generated from ", length(source_records), " R files. Do not edit this block manually. -->"),
    paste(templates, collapse = "\n"),
    end_marker,
    sep = "\n"
)
after_end <- end_pos + nchar(end_marker)
html <- paste0(
    if (start_pos > 1L) substr(html, 1L, start_pos - 1L) else "",
    generated_block,
    if (after_end <= nchar(html)) substr(html, after_end, nchar(html)) else ""
)

total_lines <- sum(vapply(source_records, function(record) length(record$lines), integer(1L)))
replace_stat <- function(document, id, value) {
    pattern <- paste0('(<b id="', id, '">)[^<]*(</b>)')
    sub(pattern, paste0("\\1", format(value, big.mark = ",", scientific = FALSE), "\\2"), document, perl = TRUE)
}
html <- replace_stat(html, "r-file-count", length(source_records))
html <- replace_stat(html, "r-line-count", total_lines)

connection <- file(html_path, open = "wb")
on.exit(close(connection), add = TRUE)
writeChar(enc2utf8(html), connection, eos = NULL, useBytes = TRUE)

message(
    "Updated ", html_path,
    " with ", length(source_records),
    " R files / ", format(total_lines, big.mark = ","),
    " lines."
)
