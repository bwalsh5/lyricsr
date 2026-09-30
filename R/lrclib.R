#' Get lyrics from LRCLIB
#'
#' [LRCLIB](https://lrclib.net) is a free, open lyrics database with a JSON
#' API and no key. It's used as an optional fallback when Genius has no
#' lyrics for a song (`fallback = "lrclib"` in [search_song()] and friends).
#'
#' LRCLIB lyrics aren't formatted like Genius lyrics: there are no section
#' headers and punctuation often differs. Check the `lyrics_source` column
#' before mixing the two in an analysis.
#'
#' @param title Track title.
#' @param artist Artist name.
#' @param album Album name. Optional; helps pick the right version.
#' @param synced If `TRUE`, returns time-synced (LRC format) lyrics when
#'   available.
#' @return A single string, or `NA` if LRCLIB has no lyrics for the track.
#' @export
#' @examples
#' \dontrun{
#' cat(lrclib_lyrics("To You", "Andy Shauf"))
#' }
lrclib_lyrics <- function(title, artist, album = NULL, synced = FALSE) {
  key <- paste("lrclib", title, artist, album %||% "", sep = "\r")
  rec <- cache_get("lyrics", key)

  if (is.null(rec)) {
    req <- httr2::request("https://lrclib.net/api/get") |>
      httr2::req_url_query(track_name = title, artist_name = artist, album_name = album) |>
      httr2::req_user_agent(getOption("lyricsr.user_agent", default_user_agent())) |>
      httr2::req_timeout(getOption("lyricsr.timeout", 10)) |>
      httr2::req_throttle(capacity = 1, fill_time_s = 0.5, realm = "lrclib.net") |>
      httr2::req_retry(max_tries = 3) |>
      httr2::req_error(is_error = function(resp) {
        httr2::resp_status(resp) >= 400 && httr2::resp_status(resp) != 404
      })
    resp <- httr2::req_perform(req)
    if (httr2::resp_status(resp) == 404) {
      return(NA_character_)
    }
    body <- httr2::resp_body_json(resp)
    rec <- list(plain = chr(body$plainLyrics), synced = chr(body$syncedLyrics))
    cache_set("lyrics", key, rec)
  }

  if (synced && !is.na(rec$synced)) rec$synced else rec$plain
}
