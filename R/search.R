#' Search for a song and get its lyrics
#'
#' The R equivalent of `Genius.search_song()` in the Python package. Searches
#' Genius, picks the best matching song, and downloads its lyrics.
#'
#' `title` and `artist` are vectorised: pass several titles (and one artist,
#' or one artist per title) to get one row per song found.
#'
#' @param title Song title(s) to search for.
#' @param artist Artist name(s). Optional, but gives much better matches.
#' @param song_id Genius song ID(s). Skips the search when supplied.
#' @param get_full_info If `TRUE`, makes an extra request per song for full
#'   metadata (album, release date, pageviews).
#' @param skip_non_songs If `TRUE`, rejects results that aren't songs
#'   (track lists, liner notes, instrumentals, songs with unfinished lyrics).
#' @param excluded_terms Extra title terms that mark a result as not a song.
#'   Added to [default_excluded_terms()] unless `replace_default_terms = TRUE`.
#' @param replace_default_terms If `TRUE`, `excluded_terms` replaces the
#'   default list instead of adding to it.
#' @param remove_section_headers If `TRUE`, removes `[Chorus]`, `[Verse 1]`,
#'   and similar headers from the lyrics.
#' @param fallback Where to look if Genius has no lyrics for a song:
#'   `"none"` or `"lrclib"` (see [lrclib_lyrics()]). The `lyrics_source`
#'   column records where each song's lyrics came from.
#' @return A tibble with one row per song found and columns `song_id`,
#'   `title`, `artist`, `artist_id`, `featured_artists`, `album`, `album_id`,
#'   `release_date`, `pageviews`, `lyrics_state`, `url`, `lyrics`, and
#'   `lyrics_source`. Songs that can't be found are skipped with a warning.
#' @export
#' @examples
#' \dontrun{
#' song <- search_song("HUMBLE.", "Kendrick Lamar")
#' cat(song$lyrics)
#'
#' search_song(c("HUMBLE.", "Alright", "Swimming Pools (Drank)"), "Kendrick Lamar")
#' }
search_song <- function(title = NULL, artist = NULL, song_id = NULL,
                        get_full_info = TRUE, skip_non_songs = TRUE,
                        excluded_terms = NULL, replace_default_terms = FALSE,
                        remove_section_headers = FALSE,
                        fallback = c("none", "lrclib")) {
  fallback <- match.arg(fallback)
  terms <- excluded_terms(excluded_terms, replace_default_terms)

  if (!is.null(song_id)) {
    rows <- lapply(song_id, function(id) {
      search_one_song(song_id = id, get_full_info = get_full_info,
                      skip_non_songs = skip_non_songs, terms = terms,
                      remove_section_headers = remove_section_headers,
                      fallback = fallback)
    })
  } else {
    if (is.null(title)) {
      cli::cli_abort("Supply either {.arg title} or {.arg song_id}.")
    }
    artist <- artist %||% ""
    if (length(artist) != 1 && length(artist) != length(title)) {
      cli::cli_abort("{.arg artist} must be length 1 or the same length as {.arg title}.")
    }
    rows <- Map(function(t, a) {
      search_one_song(title = t, artist = a, get_full_info = get_full_info,
                      skip_non_songs = skip_non_songs, terms = terms,
                      remove_section_headers = remove_section_headers,
                      fallback = fallback)
    }, title, rep_len(artist, length(title)))
  }
  songs <- bind_rows(rows)
  if (get_full_info) songs <- add_album_types(songs)
  songs
}

search_one_song <- function(title = NULL, artist = "", song_id = NULL,
                            get_full_info = TRUE, skip_non_songs = TRUE,
                            terms = default_excluded_terms(),
                            remove_section_headers = FALSE, fallback = "none") {
  if (!is.null(song_id)) {
    song <- genius_song(song_id)
    label <- paste("song ID", song_id)
  } else {
    search_term <- trimws(paste(title, artist))
    label <- paste0("'", search_term, "'")
    song <- pick_search_hit(genius_search(search_term), title, "song", "title",
                            artist = artist, skip_non_songs = skip_non_songs,
                            terms = terms)

    # search/multi misses some queries (e.g. ones with common words), so
    # fall back to the plain search endpoint like the Python package does.
    if (is.null(song)) {
      hits <- lapply(genius_search(search_term, type = NULL)$hits, `[[`, "result")
      matches <- Filter(function(h) result_is_match(h, title, artist), hits)
      if (length(matches) == 0) {
        matches <- Filter(function(h) {
          !is.null(h$primary_artist) && !is.null(h$url) &&
            (!nzchar(artist) || clean_str(h$primary_artist$name) == clean_str(artist))
        }, hits)
      }
      if (length(matches) > 0) song <- matches[[1]]
    }
  }

  if (is.null(song)) {
    cli::cli_warn("No results found for {label}.")
    return(NULL)
  }
  if (skip_non_songs && !result_is_lyrics(song, terms)) {
    cli::cli_warn("{label} matched {.val {song$full_title}}, which doesn't have lyrics. Skipping.")
    return(NULL)
  }
  if (is.null(song_id) && get_full_info) {
    song <- merge_lists(song, genius_song(song$id))
  }

  found <- fetch_song_lyrics(song, remove_section_headers, fallback)
  if (skip_non_songs && is.na(found$lyrics)) {
    return(NULL)
  }
  song_row(song, found$lyrics, found$source)
}

#' Get an artist's songs and lyrics
#'
#' The R equivalent of `Genius.search_artist()` in the Python package. Finds
#' the artist, pages through their songs, and downloads lyrics for each.
#'
#' @param artist_name Artist name to search for.
#' @param max_songs Maximum number of songs to return. `NULL` returns all
#'   of them; `0` returns none (useful for looking up the artist ID).
#' @param sort Order to fetch songs in: `"popularity"`, `"title"`, or
#'   `"release_date"`.
#' @param per_page Songs per page of API results (at most 50).
#' @param artist_id Genius artist ID. Skips the name search when supplied.
#' @param include_features If `TRUE`, also includes songs where the artist
#'   is only a featured artist.
#' @param allow_name_change If `TRUE`, uses the closest match when no
#'   artist's name matches exactly. If `FALSE`, returns an empty tibble
#'   instead.
#' @param max_pages Maximum pages of search results to check for an exact
#'   name match.
#' @param fetch_lyrics If `FALSE`, returns only song metadata. Much faster
#'   for large catalogs.
#' @param verbose If `TRUE`, prints each song as it's collected.
#' @inheritParams search_song
#' @return A tibble with one row per song (see [search_song()] for columns).
#' @export
#' @examples
#' \dontrun{
#' kendrick <- search_artist("Kendrick Lamar", max_songs = 10)
#' kendrick[, c("title", "album", "release_date")]
#' }
search_artist <- function(artist_name = NULL, max_songs = NULL,
                          sort = c("popularity", "title", "release_date"),
                          per_page = 50, artist_id = NULL,
                          get_full_info = TRUE, include_features = FALSE,
                          allow_name_change = TRUE, max_pages = 10,
                          skip_non_songs = TRUE, excluded_terms = NULL,
                          replace_default_terms = FALSE,
                          remove_section_headers = FALSE,
                          fetch_lyrics = TRUE, fallback = c("none", "lrclib"),
                          verbose = TRUE) {
  sort <- match.arg(sort)
  fallback <- match.arg(fallback)
  terms <- excluded_terms(excluded_terms, replace_default_terms)

  if (is.null(artist_id)) {
    if (is.null(artist_name)) {
      cli::cli_abort("Supply either {.arg artist_name} or {.arg artist_id}.")
    }
    artist_id <- find_artist_id(artist_name, max_pages, allow_name_change)
    if (is.null(artist_id)) {
      return(empty_songs())
    }
  }

  artist <- genius_artist(artist_id)
  if (verbose) cli::cli_inform("Collecting songs by {.strong {artist$name}}")

  rows <- list()
  page <- 1
  done <- identical(max_songs, 0) || identical(max_songs, 0L)
  while (!done && !is.null(page)) {
    res <- genius_artist_songs(artist_id, per_page = per_page, page = page, sort = sort)
    for (song in res$songs) {
      if (skip_non_songs && !result_is_lyrics(song, terms)) next
      if (!include_features && !identical(int(song$primary_artist$id), int(artist_id))) next

      if (get_full_info) {
        song <- merge_lists(song, genius_song(song$id))
      }
      found <- if (fetch_lyrics) {
        fetch_song_lyrics(song, remove_section_headers, fallback)
      } else {
        list(lyrics = NA_character_, source = NA_character_)
      }
      rows[[length(rows) + 1]] <- song_row(song, found$lyrics, found$source)
      if (verbose) cli::cli_inform("Song {length(rows)}: {.val {song$title}}")

      if (!is.null(max_songs) && length(rows) >= max_songs) {
        done <- TRUE
        break
      }
    }
    page <- res$next_page
  }

  songs <- bind_rows(rows)
  if (get_full_info) songs <- add_album_types(songs)
  if (verbose) cli::cli_inform("Done. Found {nrow(songs)} song{?s}.")
  songs
}

find_artist_id <- function(artist_name, max_pages = 10, allow_name_change = TRUE) {
  per_page <- 5
  best <- NULL
  for (page in seq_len(max_pages)) {
    res <- genius_search(artist_name, per_page = per_page, page = page)
    section <- Filter(function(s) identical(s$type, "artist"), res$sections)
    n_hits <- if (length(section)) length(section[[1]]$hits) else 0
    if (n_hits == 0) break

    candidate <- pick_search_hit(res, artist_name, "artist", "name")
    if (is.null(best)) best <- candidate
    if (!is.null(candidate) && clean_str(candidate$name) == clean_str(artist_name)) {
      return(candidate$id)
    }
    if (n_hits < per_page) break
  }

  if (is.null(best)) {
    cli::cli_warn("No artist found for {.val {artist_name}}.")
    return(NULL)
  }
  if (!allow_name_change) {
    cli::cli_warn("No exact match for {.val {artist_name}}; closest is {.val {best$name}}.")
    return(NULL)
  }
  cli::cli_inform("No exact match for {.val {artist_name}}; using {.val {best$name}}.")
  best$id
}

#' Get an album's tracks and lyrics
#'
#' The R equivalent of `Genius.search_album()` in the Python package.
#'
#' @param name Album name to search for.
#' @param artist Artist name. Optional, but gives much better matches.
#' @param album_id Genius album ID. Skips the search when supplied.
#' @param fetch_lyrics If `FALSE`, returns only track metadata.
#' @inheritParams search_song
#' @return A tibble with one row per track: a `track_number` column followed
#'   by the columns described in [search_song()]. The album name and ID come
#'   from the album, so they're filled in even without `get_full_info`.
#' @export
#' @examples
#' \dontrun{
#' damn <- search_album("DAMN.", "Kendrick Lamar")
#' damn[, c("track_number", "title")]
#' }
search_album <- function(name = NULL, artist = NULL, album_id = NULL,
                         get_full_info = FALSE, remove_section_headers = FALSE,
                         fetch_lyrics = TRUE, fallback = c("none", "lrclib")) {
  fallback <- match.arg(fallback)

  if (is.null(album_id)) {
    if (is.null(name)) {
      cli::cli_abort("Supply either {.arg name} or {.arg album_id}.")
    }
    search_term <- trimws(paste(name, artist %||% ""))
    hit <- pick_search_hit(genius_search(search_term), name, "album", "name")
    if (is.null(hit)) {
      cli::cli_warn("No album found for {.val {search_term}}.")
      return(tibble::add_column(empty_songs(), track_number = integer(), .before = 1))
    }
    album_id <- hit$id
  }
  album <- genius_album(album_id)

  rows <- list()
  page <- 1
  while (!is.null(page)) {
    res <- genius_album_tracks(album_id, page = page)
    for (track in res$tracks) {
      song <- track$song
      if (get_full_info) {
        song <- merge_lists(song, genius_song(song$id))
      }
      song$album <- list(id = album$id, name = album$name, album_type = album$album_type)
      found <- if (fetch_lyrics && result_is_lyrics(song, character())) {
        fetch_song_lyrics(song, remove_section_headers, fallback)
      } else {
        list(lyrics = NA_character_, source = NA_character_)
      }
      row <- song_row(song, found$lyrics, found$source)
      rows[[length(rows) + 1]] <- tibble::add_column(
        row, track_number = int(track$number), .before = 1
      )
    }
    page <- res$next_page
  }
  if (length(rows) == 0) {
    return(tibble::add_column(empty_songs(), track_number = integer(), .before = 1))
  }
  bind_rows(rows)
}

fetch_song_lyrics <- function(song, remove_section_headers = FALSE, fallback = "none") {
  lyrics <- NA_character_
  source <- NA_character_
  if (identical(song$lyrics_state, "complete") && !isTRUE(song$instrumental)) {
    lyrics <- genius_lyrics(song$url, remove_section_headers = remove_section_headers)
    if (!is.na(lyrics)) source <- "genius"
  }
  if (is.na(lyrics) && fallback == "lrclib") {
    lyrics <- lrclib_lyrics(song$title, song$primary_artist$name, album = song[["album"]][["name"]])
    if (!is.na(lyrics)) source <- "lrclib"
  }
  list(lyrics = lyrics, source = source)
}

bind_rows <- function(rows) {
  rows <- Filter(Negate(is.null), rows)
  if (length(rows) == 0) {
    return(empty_songs())
  }
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}
