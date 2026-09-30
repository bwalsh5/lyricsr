songs <- tibble::tibble(
  title = c("One", "Two"), artist = "A", album = c("Debut", NA),
  release_date = c("2020-01-01", NA), pageviews = 1:2,
  lyrics = c("[Verse 1]\nFirst, line\n\n[Chorus]\n\"Quoted\" hook", NA)
)

test_that("save_lyrics writes only the chosen columns and round-trips lyrics", {
  path <- withr::local_tempfile(fileext = ".csv")
  expect_message(save_lyrics(songs, path), "Saved 2 rows")
  back <- utils::read.csv(path, na.strings = "")
  expect_equal(names(back), c("artist", "album", "release_date", "title", "lyrics"))
  expect_equal(back$lyrics[1], songs$lyrics[1])
  expect_true(is.na(back$album[2]))
})

test_that("save_lyrics can remove headers or write one row per line", {
  path <- withr::local_tempfile(fileext = ".csv")
  save_lyrics(songs, path, columns = c("title", "lyrics"), remove_section_headers = TRUE)
  expect_equal(utils::read.csv(path)$lyrics[1], "First, line\n\"Quoted\" hook")

  save_lyrics(songs, path, columns = c("artist", "title", "lyrics"), by_line = TRUE)
  back <- utils::read.csv(path)
  expect_equal(names(back), c("artist", "title", "line_number", "section", "line"))
  expect_equal(back$line, c("First, line", "\"Quoted\" hook"))
  expect_equal(back$section, c("Verse 1", "Chorus"))
})

test_that("save_lyrics errors on unknown columns", {
  expect_error(save_lyrics(songs, tempfile(), columns = c("title", "genre")), "genre")
})
