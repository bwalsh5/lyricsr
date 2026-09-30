test_that("tag pages are parsed into songs", {
  html <- paste(readLines(test_path("fixtures", "tag.html")), collapse = "\n")
  res <- parse_tag_page(html, page = 1)
  expect_equal(res$songs$title, c("One", "Two"))
  expect_equal(res$songs$artist, c("Artist A", "B & C"))
  expect_equal(res$songs$url[1], "https://genius.com/A-one-lyrics")
  expect_equal(res$next_page, 2)

  last <- parse_tag_page(sub('<a rel="next"[^<]*</a>', "", html), page = 3)
  expect_null(last$next_page)
})

test_that("genre names become tag slugs", {
  expect_equal(genre_slug(c("R&B", "Hip Hop", "K-Pop", " Rock ", "rap")),
               c("r-b", "hip-hop", "k-pop", "rock", "rap"))
})

test_that("song IDs are found in song pages", {
  expect_equal(extract_song_id('<meta content="genius://songs/2857381" name="x">'), 2857381L)
  expect_equal(extract_song_id("window.x = JSON.parse('{\\\"songId\\\":42}')"), 42L)
  expect_identical(extract_song_id("<html></html>"), NA_integer_)
})
