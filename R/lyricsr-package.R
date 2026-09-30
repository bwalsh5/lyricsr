#' lyricsr: Search Genius.com for Songs, Artists, Albums, and Lyrics
#'
#' An R port of the Python `lyricsgenius` package. No access token is
#' needed: it uses the public API that genius.com itself uses.
#'
#' @section Options:
#' * `lyricsr.rate`: maximum requests per second to Genius (default 2).
#' * `lyricsr.max_tries`: attempts per request, with backoff, for
#'   failures and 429/503 responses (default 3).
#' * `lyricsr.timeout`: request timeout in seconds (default 10).
#' * `lyricsr.user_agent`: user agent string.
#' * `lyricsr.cache`: set to `FALSE` to turn off caching.
#' * `lyricsr.cache_dir`: cache location (default
#'   `tools::R_user_dir("lyricsr", "cache")`).
#' * `lyricsr.api_max_age`: seconds before cached API responses expire
#'   (default 7 days). Cached lyrics don't expire.
#'
#' @keywords internal
#' @importFrom rlang %||% !!!
"_PACKAGE"
