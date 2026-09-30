#' Get the lyrics for a Genius song
#'
#' The R equivalent of `Genius.lyrics()` in the Python package. Downloads
#' the song page and extracts the lyrics. Pass either `song_url` or
#' `song_id`; a URL saves one request.
#'
#' Lyrics are cached by URL (see [genius_cache_dir()]), so asking for the
#' same song again doesn't hit Genius.
#'
#' @param song_url A Genius song URL, e.g.
#'   `"https://genius.com/Andy-shauf-to-you-lyrics"`.
#' @param song_id A Genius song ID. Used to look up the URL if `song_url`
#'   isn't given.
#' @param remove_section_headers If `TRUE`, removes `[Chorus]`, `[Verse 1]`,
#'   and similar headers.
#' @return A single string of lyrics with lines separated by `"\n"`, or
#'   `NA` if no lyrics were found.
#' @export
#' @examples
#' \dontrun{
#' cat(genius_lyrics("https://genius.com/Andy-shauf-to-you-lyrics"))
#' }
genius_lyrics <- function(song_url = NULL, song_id = NULL,
                          remove_section_headers = FALSE) {
  if (is.null(song_url)) {
    if (is.null(song_id)) {
      cli::cli_abort("Supply either {.arg song_url} or {.arg song_id}.")
    }
    song_url <- genius_song(song_id)$url
  }

  lyrics <- genius_page(song_url)$lyrics
  if (remove_section_headers && !is.na(lyrics)) {
    lyrics <- strip_section_headers(lyrics)
  }
  lyrics
}

# Download a song page once and keep what we need from it: the lyrics and the
# song ID (tag pages only give URLs, so the ID is how we get metadata).
genius_page <- function(song_url) {
  page <- cache_get("lyrics", song_url)
  if (!is.null(page)) {
    return(page)
  }

  html <- genius_get_html(song_url)
  page <- list(
    lyrics = if (is.null(html)) NA_character_ else extract_lyrics(html),
    song_id = if (is.null(html)) NA_integer_ else extract_song_id(html)
  )
  if (is.na(page$lyrics)) {
    cli::cli_warn(c(
      "Couldn't find lyrics on the page.",
      "i" = "Song URL: {.url {song_url}}"
    ))
  } else {
    cache_set("lyrics", song_url, page)
  }
  page
}

extract_song_id <- function(html) {
  for (pattern in c("genius://songs/([0-9]+)", '\\\\"songId\\\\":([0-9]+)')) {
    m <- regmatches(html, regexec(pattern, html))[[1]]
    if (length(m) == 2) {
      return(as.integer(m[[2]]))
    }
  }
  NA_integer_
}

#' Extract lyrics from a Genius song page
#'
#' Tries two methods, so a layout change on Genius is less likely to break
#' extraction:
#'
#' 1. The `div[data-lyrics-container="true"]` elements in the page HTML
#'    (what the Python package uses).
#' 2. The lyrics HTML inside the page's embedded
#'    `window.__PRELOADED_STATE__` JSON.
#'
#' @param html The page HTML as a string (or anything [xml2::read_html()]
#'   accepts).
#' @return A single string, or `NA` if neither method finds lyrics.
#' @export
#' @keywords internal
extract_lyrics <- function(html) {
  doc <- xml2::read_html(html)

  containers <- xml2::xml_find_all(doc, "//div[@data-lyrics-container='true']")
  if (length(containers) > 0) {
    lyrics <- nodes_to_text(containers)
    if (nzchar(lyrics)) {
      return(lyrics)
    }
  }

  lyrics_html <- preloaded_lyrics_html(html)
  if (!is.null(lyrics_html)) {
    # Line breaks are <br> tags; the literal newlines after them are markup.
    lyrics_html <- gsub("\n", "", lyrics_html, fixed = TRUE)
    body <- xml2::xml_find_all(xml2::read_html(lyrics_html), "//body")
    lyrics <- nodes_to_text(body)
    if (nzchar(lyrics)) {
      return(lyrics)
    }
  }

  NA_character_
}

# Convert lyrics nodes to text: drop page furniture (the "N Contributors"
# header and anything else Genius marks as excluded from selection), turn
# <br> into newlines, and join containers.
nodes_to_text <- function(nodes) {
  xml2::xml_remove(xml2::xml_find_all(
    nodes,
    ".//*[@data-exclude-from-selection='true'] | .//div[contains(@class, 'LyricsHeader')]"
  ))
  brs <- xml2::xml_find_all(nodes, ".//br")
  xml2::xml_text(brs) <- "\n"

  text <- paste(xml2::xml_text(nodes), collapse = "\n")
  text <- gsub("\u00a0", " ", text, fixed = TRUE)
  text <- gsub("[ \t]+\n", "\n", text)
  text <- gsub("\n{3,}", "\n\n", text)
  trimws(text)
}

# Pull songPage$lyricsData$body$html out of the page's embedded state, which
# is written as window.__PRELOADED_STATE__ = JSON.parse('...');
preloaded_lyrics_html <- function(html) {
  if (!is.character(html)) {
    return(NULL)
  }
  m <- regmatches(
    html,
    regexpr("window\\.__PRELOADED_STATE__ = JSON\\.parse\\('(.*?)'\\);", html, perl = TRUE)
  )
  if (length(m) == 0) {
    return(NULL)
  }
  js <- sub("^window\\.__PRELOADED_STATE__ = JSON\\.parse\\('", "", m)
  js <- sub("'\\);$", "", js)

  # The argument is a single-quoted JS string. Turn it into a JSON string
  # literal, decode it, then parse the resulting JSON document. JS allows
  # escapes JSON doesn't (\', \$, \xNN, ...), so set escaped backslashes
  # aside, convert \xNN to \u00NN, and drop the backslash from any other
  # escape JSON doesn't know.
  js <- gsub("\\\\", "\001", js, fixed = TRUE)
  js <- gsub("\\\\x([0-9A-Fa-f]{2})", "\\\\u00\\1", js)
  js <- gsub('\\\\([^"/bfnrtu])', "\\1", js)
  js <- gsub('(?<!\\\\)"', '\\\\"', js, perl = TRUE)
  js <- gsub("\001", "\\\\", js, fixed = TRUE)
  state <- tryCatch(
    jsonlite::parse_json(jsonlite::parse_json(paste0('"', js, '"'))),
    error = function(e) NULL
  )
  state$songPage$lyricsData$body$html
}

strip_section_headers <- function(lyrics) {
  lyrics <- gsub("\\[[^]]*\\]\n?", "", lyrics)
  lyrics <- gsub("\n{2,}", "\n", lyrics)
  trimws(lyrics)
}
