#' Terms that flag a Genius result as not being a song
#'
#' Songs whose titles contain any of these terms (case-insensitive, matched
#' literally) are skipped when `skip_non_songs = TRUE`. This is the same
#' list as the Python package: the base terms, plus each term wrapped in
#' parentheses and brackets, plus `"(instrumental)"` and `"[instrumental]"`.
#'
#' @return A character vector.
#' @export
#' @examples
#' default_excluded_terms()
default_excluded_terms <- function() {
  terms <- c(
    "tracklist", "track list", "album art", "album artwork", "liner notes",
    "booklet", "credits", "interview", "skit", "setlist"
  )
  c(terms, paste0("(", terms, ")"), paste0("[", terms, "]"),
    "(instrumental)", "[instrumental]")
}

excluded_terms <- function(extra = NULL, replace_default = FALSE) {
  if (replace_default) extra else c(default_excluded_terms(), extra)
}

# Normalize a string for comparison: NFKC, lowercase, no punctuation, trimmed.
# Matches the Python package's clean_str(), but removes all Unicode
# punctuation (so curly apostrophes match straight ones).
clean_str <- function(x) {
  x <- stringi::stri_trans_nfkc(x %||% "")
  x <- stringi::stri_replace_all_regex(x, "[\\p{P}\\p{S}\\x{200B}]", "")
  trimws(tolower(x))
}

# FALSE for results that aren't really lyrics: unfinished or instrumental
# songs, and titles containing an excluded term.
result_is_lyrics <- function(song, terms = default_excluded_terms()) {
  if (!identical(song$lyrics_state, "complete") || isTRUE(song$instrumental)) {
    return(FALSE)
  }
  title <- tolower(song$title %||% "")
  !any(vapply(tolower(terms), grepl, logical(1), x = title, fixed = TRUE))
}

result_is_match <- function(song, title, artist = NULL) {
  title_match <- clean_str(song$title) == clean_str(title)
  if (is.null(artist) || !nzchar(artist)) {
    return(title_match)
  }
  title_match && clean_str(song$primary_artist$name) == clean_str(artist)
}

# Choose the best hit of a given type from a search/multi response, following
# the Python package's _get_item_from_search_response(): an exact match wins;
# for songs, fall back to the first hit that has lyrics (by the right artist,
# if one was given); otherwise fall back to the first hit.
pick_search_hit <- function(response, search_term, type, field,
                            artist = NULL, skip_non_songs = TRUE,
                            terms = default_excluded_terms()) {
  hits <- list()
  for (section in response$sections) {
    for (hit in section$hits) {
      if (identical(hit$index, type)) hits[[length(hits) + 1]] <- hit$result
    }
  }
  ids <- vapply(hits, function(h) as.character(h$id %||% NA), character(1))
  hits <- hits[!duplicated(ids)]

  for (item in hits) {
    if (type == "song" && field == "title") {
      if (result_is_match(item, search_term, artist)) return(item)
    } else if (clean_str(item[[field]]) == clean_str(search_term)) {
      return(item)
    }
  }

  has_artist <- !is.null(artist) && nzchar(artist)
  if (type == "song" && skip_non_songs) {
    for (item in hits) {
      if (has_artist && clean_str(item$primary_artist$name) != clean_str(artist)) next
      if (result_is_lyrics(item, terms)) return(item)
    }
  }
  if (type == "song" && has_artist) {
    return(NULL)
  }
  if (length(hits) > 0) hits[[1]] else NULL
}

chr <- function(x) if (is.null(x)) NA_character_ else as.character(x)
int <- function(x) if (is.null(x)) NA_integer_ else as.integer(x)

release_date <- function(song) {
  # [[ ]] rather than $: $ would partially match release_date_components.
  if (!is.null(song[["release_date"]])) {
    return(song[["release_date"]])
  }
  d <- song[["release_date_components"]]
  if (is.null(d$year)) {
    return(NA_character_)
  }
  paste(c(d$year, sprintf("%02d", c(d$month, d$day))), collapse = "-")
}

collapse_or_na <- function(x) {
  if (length(x)) paste(x, collapse = ", ") else NA_character_
}

# Relationships that mark a song as a version of another song page. The full
# song record lists every relationship type, most with no songs.
version_relationships <- c("cover_of", "remix_of", "live_version_of", "translation_of")

song_relationship <- function(song) {
  rels <- Filter(function(r) {
    r[["relationship_type"]] %in% version_relationships && length(r[["songs"]]) > 0
  }, song[["song_relationships"]])
  collapse_or_na(vapply(rels, function(r) r[["relationship_type"]], character(1)))
}

# One tibble row of song metadata plus lyrics. Uses [[ ]] throughout: `$`
# partially matches, so song$album would return song$albums when a record
# has no album.
song_row <- function(song, lyrics = NA_character_, source = NA_character_) {
  name_of <- function(x) x[["name"]]
  # Not named `album`/`artist`: tibble() would see the columns instead.
  alb <- song[["album"]]
  art <- song[["primary_artist"]]
  tibble::tibble(
    song_id = int(song[["id"]]),
    title = chr(song[["title"]]),
    artist = chr(art[["name"]]),
    artist_id = int(art[["id"]]),
    featured_artists = collapse_or_na(vapply(song[["featured_artists"]], name_of, character(1))),
    album = chr(alb[["name"]]),
    album_id = int(alb[["id"]]),
    album_type = chr(alb[["album_type"]]),
    release_date = release_date(song),
    genre = chr(song[["primary_tag"]][["name"]]),
    tags = collapse_or_na(vapply(song[["tags"]], name_of, character(1))),
    language = chr(song[["language"]]),
    relationship = song_relationship(song),
    pageviews = int(song[["stats"]][["pageviews"]]),
    lyrics_state = chr(song[["lyrics_state"]]),
    url = chr(song[["url"]]),
    lyrics = lyrics,
    lyrics_source = source
  )
}

# Fill in album_type, which only the album endpoint returns. One request per
# distinct album (cached).
add_album_types <- function(songs) {
  todo <- is.na(songs$album_type) & !is.na(songs$album_id)
  ids <- unique(songs$album_id[todo])
  types <- vapply(ids, function(id) chr(genius_album(id)[["album_type"]]), character(1))
  songs$album_type[todo] <- types[match(songs$album_id[todo], ids)]
  songs
}

empty_songs <- function() {
  song_row(list())[0, ]
}

merge_lists <- function(x, y) {
  x[names(y)] <- y
  x
}
