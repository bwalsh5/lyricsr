#' Save lyrics to a CSV file
#'
#' Writes songs to a UTF-8 CSV with only the columns you need. By default
#' that's artist, album, release date, title, and lyrics.
#'
#' Lyrics contain line breaks, which are kept inside quoted fields. Most CSV
#' readers (`read.csv()`, `readr::read_csv()`, Excel, pandas) read them back
#' correctly. To avoid multi-line fields, use `by_line = TRUE` to write one
#' row per lyric line instead.
#'
#' @param songs A tibble from [search_song()], [search_artist()],
#'   [search_album()], or [search_genre()], optionally after
#'   [filter_songs()].
#' @param path File to write, e.g. `"lyrics.csv"`.
#' @param columns Columns to write, in order. Any column of `songs` can be
#'   used. `"lyrics"` is required unless `by_line = TRUE`.
#' @param by_line If `TRUE`, writes one row per lyric line (see
#'   [tidy_lyrics()]), with `line_number`, `section`, and `line` columns in
#'   place of `lyrics`.
#' @param remove_section_headers If `TRUE`, removes `[Chorus]`, `[Verse 1]`,
#'   and similar headers from the lyrics before saving. Ignored when
#'   `by_line = TRUE`, which moves headers into the `section` column.
#' @param na String written for missing values.
#' @return `path`, invisibly.
#' @export
#' @examples
#' songs <- tibble::tibble(
#'   title = "Example", artist = "Someone", album = "Debut",
#'   release_date = "2020-01-01", pageviews = 10L,
#'   lyrics = "[Verse 1]\nFirst line\nSecond line"
#' )
#' path <- tempfile(fileext = ".csv")
#' save_lyrics(songs, path)
#' read.csv(path)
#'
#' save_lyrics(songs, path, by_line = TRUE)
#' read.csv(path)
save_lyrics <- function(songs, path,
                        columns = c("artist", "album", "release_date", "title", "lyrics"),
                        by_line = FALSE, remove_section_headers = FALSE,
                        na = "") {
  missing <- setdiff(columns, names(songs))
  if (length(missing)) {
    cli::cli_abort(c(
      "{.arg songs} has no column{?s} {.field {missing}}.",
      "i" = "Available columns: {.field {names(songs)}}."
    ))
  }

  if (by_line) {
    meta <- setdiff(columns, "lyrics")
    out <- tidy_lyrics(songs[c(meta, "lyrics")])
    out <- out[c(meta, "line_number", "section", "line")]
  } else {
    out <- songs[columns]
    if (remove_section_headers && "lyrics" %in% columns) {
      has <- !is.na(out$lyrics)
      out$lyrics[has] <- strip_section_headers(out$lyrics[has])
    }
  }

  utils::write.csv(as.data.frame(out), path, row.names = FALSE, na = na,
                   fileEncoding = "UTF-8")
  cli::cli_inform("Saved {nrow(out)} row{?s} to {.file {path}}.")
  invisible(path)
}
