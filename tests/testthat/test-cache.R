test_that("cache stores values and can be turned off or cleared", {
  withr::local_options(lyricsr.cache_dir = withr::local_tempdir())
  expect_null(cache_get("lyrics", "https://genius.com/x"))
  cache_set("lyrics", "https://genius.com/x", "la la")
  expect_equal(cache_get("lyrics", "https://genius.com/x"), "la la")

  withr::with_options(list(lyricsr.cache = FALSE), {
    expect_null(cache_get("lyrics", "https://genius.com/x"))
  })

  genius_cache_clear("lyrics")
  expect_null(cache_get("lyrics", "https://genius.com/x"))
})
