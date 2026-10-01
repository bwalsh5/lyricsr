test_that("clean_str ignores case, punctuation, and apostrophe style", {
  expect_equal(clean_str("Don’t Stop!"), clean_str("dont stop"))
  expect_equal(clean_str("  HELLO, World "), "hello world")
})

test_that("result_is_lyrics rejects non-songs", {
  song <- list(title = "Real Song", lyrics_state = "complete")
  expect_true(result_is_lyrics(song))
  expect_false(result_is_lyrics(modifyList(song, list(title = "Album (Tracklist)"))))
  expect_false(result_is_lyrics(modifyList(song, list(title = "Interview with X"))))
  expect_false(result_is_lyrics(modifyList(song, list(lyrics_state = "unreleased"))))
  expect_false(result_is_lyrics(modifyList(song, list(instrumental = TRUE))))
  expect_true(result_is_lyrics(modifyList(song, list(title = "Interview")), terms = character()))
})

test_that("default_excluded_terms matches the Python package", {
  terms <- default_excluded_terms()
  expect_length(terms, 32)
  expect_true(all(c("tracklist", "(skit)", "[credits]", "(instrumental)") %in% terms))
})

search_response <- list(sections = list(
  list(type = "top_hit", hits = list(
    list(index = "song", result = list(id = 1, title = "HUMBLE. (Tracklist)", lyrics_state = "complete",
                                       primary_artist = list(name = "Kendrick Lamar")))
  )),
  list(type = "song", hits = list(
    list(index = "song", result = list(id = 1, title = "HUMBLE. (Tracklist)", lyrics_state = "complete",
                                       primary_artist = list(name = "Kendrick Lamar"))),
    list(index = "song", result = list(id = 2, title = "HUMBLE.", lyrics_state = "complete",
                                       primary_artist = list(name = "Someone Else"))),
    list(index = "song", result = list(id = 3, title = "HUMBLE.", lyrics_state = "complete",
                                       primary_artist = list(name = "Kendrick Lamar")))
  )),
  list(type = "artist", hits = list(
    list(index = "artist", result = list(id = 10, name = "Kendrick Lamar"))
  ))
))

test_that("pick_search_hit prefers an exact title and artist match", {
  expect_equal(pick_search_hit(search_response, "HUMBLE.", "song", "title", artist = "Kendrick Lamar")$id, 3)
  expect_equal(pick_search_hit(search_response, "HUMBLE.", "song", "title")$id, 2)
  expect_equal(pick_search_hit(search_response, "kendrick lamar", "artist", "name")$id, 10)
})

test_that("pick_search_hit returns NULL when the artist never matches", {
  expect_null(pick_search_hit(search_response, "Other", "song", "title", artist = "Nobody"))
})

test_that("song_row flattens metadata", {
  song <- list(
    id = 5, title = "T", primary_artist = list(id = 9, name = "A"),
    featured_artists = list(list(name = "F1"), list(name = "F2")),
    album = list(id = 7, name = "Alb"), stats = list(pageviews = 100),
    release_date_components = list(year = 2016, month = 5, day = 20),
    lyrics_state = "complete", url = "https://genius.com/x",
    primary_tag = list(name = "Rock"), tags = list(list(name = "Rock"), list(name = "Indie")),
    language = "en",
    song_relationships = list(
      list(relationship_type = "samples", songs = list(list(id = 1))),
      list(relationship_type = "cover_of", songs = list(list(id = 2))),
      list(relationship_type = "remix_of", songs = list())
    )
  )
  row <- song_row(song, "la la", "genius")
  expect_equal(row$featured_artists, "F1, F2")
  expect_equal(row$release_date, "2016-05-20")
  expect_equal(row$genre, "Rock")
  expect_equal(row$tags, "Rock, Indie")
  expect_equal(row$relationship, "cover_of")
  expect_equal(row$artist_id, 9L)
  expect_true(is.na(row$album_type))
  expect_equal(names(row), names(empty_songs()))
  expect_equal(nrow(empty_songs()), 0)
})
