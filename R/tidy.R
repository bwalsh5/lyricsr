#' Split lyrics into one row per line
#'
#' Turns the output of [search_song()], [search_artist()], or
#' [search_album()] into one row per lyric line, ready for text analysis
#' (e.g. `tidytext::unnest_tokens()`). Section headers such as
#' `[Chorus]` or `[Verse 2: Artist]` become `section` and
#' `section_artist` columns instead of lines.
#'
#' @param songs A tibble with a `lyrics` column.
#' @param keep_empty If `TRUE`, keeps blank lines (the gaps between
#'   stanzas).
#' @return A tibble with the input's columns except `lyrics`, plus
#'   `line_number`, `section`, `section_artist`, and `line`.
#' @export
#' @examples
#' songs <- tibble::tibble(
#'   title = "Example",
#'   lyrics = "[Verse 1: Someone]\nFirst line\nSecond line\n\n[Chorus]\nHook"
#' )
#' tidy_lyrics(songs)
tidy_lyrics <- function(songs, keep_empty = FALSE) {
  if (!"lyrics" %in% names(songs)) {
    cli::cli_abort("{.arg songs} must have a {.field lyrics} column.")
  }
  meta <- songs[setdiff(names(songs), "lyrics")]

  pieces <- lapply(seq_len(nrow(songs)), function(i) {
    lines <- strsplit(songs$lyrics[[i]] %||% "", "\n", fixed = TRUE)[[1]]
    if (length(lines) == 0 || all(is.na(lines))) {
      return(NULL)
    }
    lines <- trimws(lines)
    is_header <- grepl("^\\[.*\\]$", lines)

    header <- sub("^\\[(.*)\\]$", "\\1", ifelse(is_header, lines, NA_character_))
    section_name <- trimws(sub(":.*$", "", header))
    section_artist <- ifelse(grepl(":", header), trimws(sub("^[^:]*:", "", header)), NA_character_)
    # Carry each header forward to the lines below it.
    idx <- cumsum(is_header)
    section_name <- c(NA_character_, section_name[is_header])[idx + 1]
    section_artist <- c(NA_character_, section_artist[is_header])[idx + 1]

    keep <- !is_header & (keep_empty | nzchar(lines))
    if (!any(keep)) {
      return(NULL)
    }
    tibble::tibble(
      row = i,
      line_number = seq_len(sum(keep)),
      section = section_name[keep],
      section_artist = section_artist[keep],
      line = lines[keep]
    )
  })

  lines <- do.call(rbind, pieces)
  if (is.null(lines)) {
    lines <- tibble::tibble(row = integer(), line_number = integer(),
                            section = character(), section_artist = character(),
                            line = character())
  }
  out <- tibble::as_tibble(cbind(meta[lines$row, , drop = FALSE], lines[-1]))
  out
}
