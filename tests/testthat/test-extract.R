test_that("lyrics are extracted from the lyrics containers", {
  expect_equal(extract_lyrics(fixture_html()), expected_lyrics)
})

test_that("embedded JSON is used when the containers are missing", {
  html <- gsub('data-lyrics-container="true"', 'data-x="1"', fixture_html(), fixed = TRUE)
  expect_equal(extract_lyrics(html), expected_lyrics)
})

test_that("NA is returned when there are no lyrics", {
  expect_identical(extract_lyrics("<html><body><p>Nothing</p></body></html>"), NA_character_)
})

test_that("section headers can be removed", {
  expect_equal(
    strip_section_headers(expected_lyrics),
    "First line, it's here\nSecond line costs $5\nHook line"
  )
})
