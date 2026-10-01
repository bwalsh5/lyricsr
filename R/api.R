#' Low-level Genius API calls
#'
#' Thin wrappers around Genius's public API (`https://genius.com/api/`),
#' the same endpoints the Python package's `PublicAPI` uses. They need no
#' access token and return the parsed JSON as a list. Responses are cached
#' (see [genius_cache_dir()]).
#'
#' Most people want the higher-level [search_song()], [search_artist()], and
#' [search_album()] instead.
#'
#' @param search_term Text to search for.
#' @param type For `genius_search()`: `"multi"` (songs, artists, albums, and
#'   more, grouped into sections), `"song"`, `"artist"`, `"album"`, or
#'   `"lyric"` (search within lyrics). `NULL` uses the plain `search`
#'   endpoint, which only returns songs.
#' @param per_page,page Pagination. `per_page` is at most 5 for
#'   `type = "multi"` and 50 elsewhere.
#' @param song_id,artist_id,album_id Genius IDs.
#' @param sort For `genius_artist_songs()`: `"popularity"`, `"title"`, or
#'   `"release_date"`.
#' @param text_format Format for text fields such as descriptions:
#'   `"plain"`, `"html"`, `"markdown"`, or `"dom"`.
#' @return A list parsed from the JSON response.
#' @name genius_api
#' @examples
#' \dontrun{
#' res <- genius_search("Kendrick Lamar")
#' genius_song(378195)$title
#' genius_artist_songs(2020, per_page = 5)$songs
#' }
NULL

#' @rdname genius_api
#' @export
genius_search <- function(search_term, type = "multi", per_page = NULL, page = NULL) {
  path <- if (is.null(type)) "search" else paste0("search/", type)
  genius_get(path, list(q = search_term, per_page = per_page, page = page))
}

#' @rdname genius_api
#' @export
genius_song <- function(song_id, text_format = "plain") {
  genius_get(paste0("songs/", song_id), list(text_format = text_format))$song
}

#' @rdname genius_api
#' @export
genius_artist <- function(artist_id, text_format = "plain") {
  genius_get(paste0("artists/", artist_id), list(text_format = text_format))$artist
}

#' @rdname genius_api
#' @export
genius_artist_songs <- function(artist_id, per_page = 50, page = 1,
                                sort = c("popularity", "title", "release_date")) {
  sort <- match.arg(sort)
  genius_get(
    paste0("artists/", artist_id, "/songs"),
    list(per_page = per_page, page = page, sort = sort)
  )
}

#' @rdname genius_api
#' @export
genius_album <- function(album_id, text_format = "plain") {
  genius_get(paste0("albums/", album_id), list(text_format = text_format))$album
}

#' @rdname genius_api
#' @export
genius_album_tracks <- function(album_id, per_page = 50, page = 1,
                                text_format = "plain") {
  genius_get(
    paste0("albums/", album_id, "/tracks"),
    list(per_page = per_page, page = page, text_format = text_format)
  )
}
