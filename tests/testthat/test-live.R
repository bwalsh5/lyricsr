# Live tests hit genius.com. Run with LYRICSR_LIVE_TESTS=true.

test_that("search_song finds a song and its lyrics", {
  skip_if_no_genius()
  withr::local_options(lyricsr.cache_dir = withr::local_tempdir())
  song <- search_song("HUMBLE.", "Kendrick Lamar")
  expect_equal(nrow(song), 1)
  expect_equal(song$artist, "Kendrick Lamar")
  expect_equal(song$album, "DAMN.")
  expect_equal(song$lyrics_source, "genius")
  expect_match(song$lyrics, "sit down")
})

test_that("search_artist and search_album return songs", {
  skip_if_no_genius()
  withr::local_options(lyricsr.cache_dir = withr::local_tempdir())
  artist <- search_artist("Kendrick Lamar", max_songs = 2, fetch_lyrics = FALSE, verbose = FALSE)
  expect_equal(nrow(artist), 2)
  expect_true(all(artist$artist == "Kendrick Lamar"))

  album <- search_album("DAMN.", "Kendrick Lamar")
  expect_equal(album$track_number, 1:14)
  expect_true(all(!is.na(album$lyrics)))
})

test_that("search_genre returns songs with metadata", {
  skip_if_no_genius()
  withr::local_options(lyricsr.cache_dir = withr::local_tempdir())
  songs <- search_genre("rock", max_songs = 2, verbose = FALSE)
  expect_equal(nrow(songs), 2)
  expect_false(anyNA(songs$song_id))
  expect_false(anyNA(songs$lyrics))
})
