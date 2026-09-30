#' Manage the lyrics cache
#'
#' lyricsr caches two things on disk so repeat requests don't hit
#' Genius again:
#'
#' * **lyrics**: extracted lyrics text, keyed by song URL. These don't expire.
#' * **api**: API responses (search results, song and artist metadata),
#'   which expire after `getOption("lyricsr.api_max_age")` seconds
#'   (default 7 days) so new releases eventually show up.
#'
#' Turn caching off with `options(lyricsr.cache = FALSE)`. Change the
#' location with `options(lyricsr.cache_dir = "path")`.
#'
#' @param which Which cache to clear: `"all"`, `"lyrics"`, or `"api"`.
#' @return `genius_cache_dir()` returns the cache directory path.
#'   `genius_cache_clear()` returns `NULL` invisibly.
#' @export
#' @examples
#' genius_cache_dir()
genius_cache_dir <- function() {
  getOption(
    "lyricsr.cache_dir",
    tools::R_user_dir("lyricsr", which = "cache")
  )
}

#' @rdname genius_cache_dir
#' @export
genius_cache_clear <- function(which = c("all", "lyrics", "api")) {
  which <- match.arg(which)
  kinds <- if (which == "all") c("lyrics", "api") else which
  for (kind in kinds) {
    get_cache(kind)$reset()
  }
  invisible(NULL)
}

the <- new.env(parent = emptyenv())

get_cache <- function(kind) {
  dir <- file.path(genius_cache_dir(), kind)
  key <- paste(kind, dir)
  if (is.null(the$caches[[key]])) {
    max_age <- if (kind == "api") {
      getOption("lyricsr.api_max_age", 60 * 60 * 24 * 7)
    } else {
      Inf
    }
    the$caches[[key]] <- cachem::cache_disk(dir, max_age = max_age, max_size = Inf)
  }
  the$caches[[key]]
}

cache_enabled <- function() {
  isTRUE(getOption("lyricsr.cache", TRUE))
}

# cachem keys must be lowercase letters and digits, so hash the URL.
cache_key <- function(x) {
  rlang::hash(x)
}

cache_get <- function(kind, key) {
  if (!cache_enabled()) {
    return(NULL)
  }
  value <- get_cache(kind)$get(cache_key(key))
  if (cachem::is.key_missing(value)) NULL else value
}

cache_set <- function(kind, key, value) {
  if (cache_enabled()) {
    get_cache(kind)$set(cache_key(key), value)
  }
  invisible(value)
}
