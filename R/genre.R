#' Get songs from a genre
#'
#' Collects songs from a Genius genre tag page, such as
#' <https://genius.com/tags/rock/all>, most popular first. The R equivalent
#' of `Genius.tag()` in the Python package, plus metadata and lyrics for
#' each song.
#'
#' Genius has no API endpoint for tags, so this reads the tag pages (20
#' songs each). Each song's page is then downloaded for its lyrics and ID,
#' and with `get_full_info = TRUE` its metadata is fetched too.
#'
#' @param genre A Genius tag, as a name (`"Rock"`, `"R&B"`, `"K-Pop"`) or as
#'   it appears in the URL (`"rock"`, `"r-b"`, `"k-pop"`). Common tags
#'   include `"rap"`, `"pop"`, `"rock"`, `"r-b"`, `"country"`, and `"indie"`.
#'   See <https://genius.com/tags> for more.
#' @param max_songs Maximum number of songs to return.
#' @param get_full_info If `TRUE`, fetches full metadata for each song
#'   (album, release date, tags, pageviews). If `FALSE`, only `title`,
#'   `artist`, `url`, and the lyrics are filled in.
#' @inheritParams search_artist
#' @return A tibble with one row per song (see [search_song()] for columns).
#' @export
#' @examples
#' \dontrun{
#' country <- search_genre("country", max_songs = 50)
#' }
search_genre <- function(genre, max_songs = 100, get_full_info = TRUE,
                         skip_non_songs = TRUE, excluded_terms = NULL,
                         replace_default_terms = FALSE,
                         remove_section_headers = FALSE, fetch_lyrics = TRUE,
                         verbose = TRUE) {
  terms <- excluded_terms(excluded_terms, replace_default_terms)
  if (verbose) cli::cli_inform("Collecting {.strong {genre}} songs")

  rows <- list()
  page <- 1
  while (!is.null(page) && length(rows) < max_songs) {
    res <- genius_tag(genre, page = page)
    for (i in seq_len(nrow(res$songs))) {
      hit <- res$songs[i, ]
      if (skip_non_songs && !result_is_lyrics(list(title = hit$title, lyrics_state = "complete"), terms)) next

      found <- list(lyrics = NA_character_, song_id = NA_integer_)
      if (fetch_lyrics || get_full_info) found <- genius_page(hit$url)
      if (skip_non_songs && fetch_lyrics && is.na(found$lyrics)) next

      song <- list(title = hit$title, url = hit$url,
                   primary_artist = list(name = hit$artist))
      if (get_full_info && !is.na(found$song_id)) {
        song <- merge_lists(song, genius_song(found$song_id))
        if (skip_non_songs && !result_is_lyrics(song, terms)) next
      }

      lyrics <- if (fetch_lyrics) found$lyrics else NA_character_
      if (remove_section_headers && !is.na(lyrics)) lyrics <- strip_section_headers(lyrics)
      rows[[length(rows) + 1]] <- song_row(song, lyrics, if (is.na(lyrics)) NA_character_ else "genius")
      if (verbose) cli::cli_inform("Song {length(rows)}: {.val {song$title}} by {song$primary_artist$name}")
      if (length(rows) >= max_songs) break
    }
    page <- res$next_page
  }

  songs <- bind_rows(rows)
  if (get_full_info) songs <- add_album_types(songs)
  if (verbose) cli::cli_inform("Done. Found {nrow(songs)} song{?s}.")
  songs
}

#' @rdname genius_api
#' @param genre For `genius_tag()`: a Genius tag name or URL slug, e.g.
#'   `"rock"` or `"R&B"`.
#' @return For `genius_tag()`: a list with `songs` (a tibble of `title`,
#'   `artist`, and `url`) and `next_page` (`NULL` on the last page).
#' @export
genius_tag <- function(genre, page = 1) {
  slug <- genre_slug(genre)
  url <- paste0(web_root, "tags/", slug, "/all?page=", page)

  res <- cache_get("api", url)
  if (!is.null(res)) {
    return(res)
  }

  html <- genius_get_html(url)
  if (is.null(html)) {
    cli::cli_abort(c(
      "Genius has no tag {.val {slug}}.",
      "i" = "Browse tags at {.url https://genius.com/tags}."
    ))
  }
  res <- parse_tag_page(html, page)
  cache_set("api", url, res)
  res
}

# "R&B" -> "r-b", "Hip Hop" -> "hip-hop", "K-Pop" -> "k-pop"
genre_slug <- function(genre) {
  slug <- gsub("[^a-z0-9]+", "-", tolower(genre))
  gsub("^-+|-+$", "", slug)
}

parse_tag_page <- function(html, page = 1) {
  doc <- xml2::read_html(html)
  links <- xml2::xml_find_all(doc, "//ul[contains(@class, 'song_list')]//a[contains(@class, 'song_link')]")
  text_of <- function(xpath) {
    vapply(links, function(a) {
      nodes <- xml2::xml_find_all(a, xpath)
      text <- gsub("\u00a0", " ", xml2::xml_text(nodes), fixed = TRUE)
      if (length(text)) paste(trimws(text), collapse = " & ") else NA_character_
    }, character(1))
  }
  songs <- tibble::tibble(
    title = text_of(".//span[@class='song_title']"),
    artist = text_of(".//span[@class='primary_artist_name']"),
    url = xml2::xml_attr(links, "href")
  )
  has_next <- length(xml2::xml_find_all(doc, "//a[@rel='next']")) > 0
  list(songs = songs, next_page = if (has_next) page + 1 else NULL)
}

