test_that("tidy_lyrics splits lines and carries sections forward", {
  songs <- tibble::tibble(title = c("A", "B"), lyrics = c(expected_lyrics, NA))
  out <- tidy_lyrics(songs)
  expect_equal(out$line, c("First line, it's here", "Second line costs $5", "Hook line"))
  expect_equal(out$section, c("Verse 1", "Verse 1", "Chorus"))
  expect_equal(out$section_artist, c("Test Artist", "Test Artist", NA))
  expect_equal(out$line_number, 1:3)
  expect_equal(out$title, rep("A", 3))
  expect_false("lyrics" %in% names(out))
})

test_that("tidy_lyrics can keep blank lines and handles no lyrics", {
  songs <- tibble::tibble(title = "A", lyrics = expected_lyrics)
  expect_equal(nrow(tidy_lyrics(songs, keep_empty = TRUE)), 4)
  empty <- tidy_lyrics(tibble::tibble(title = "A", lyrics = NA_character_))
  expect_equal(nrow(empty), 0)
  expect_type(empty$section, "character")
})
