catalog <- function() {
  tibble::tibble(
    title = c("Help!", "Help! - Remastered 2009", "Help! (Live at the BBC)",
              "Revolution (Take 20)", "Revolution 1", "Live and Let Die",
              "Yesterday", "Yesterday - Mono", "I Want You (She’s So Heavy)",
              "Let It Be (Naked Version)", "All Too Well (Taylor’s Version)",
              "Hello (Traducción al Español)", "Hey Jude (Album Version)",
              "Theme", "Single Song", "Title Track", "Copy"),
    artist = "X",
    album = c("Help!", "Help!", "Live at the BBC", "Deluxe", "The Beatles", "Solo",
              "Help!", "Help!", "Abbey Road", "Let It Be... Naked", "Red", "Hello",
              "Hey Jude", "Original Motion Picture Soundtrack", "Single Song",
              "Greatest Hits", "Help!"),
    album_type = c("album", "album", "live", "album", "album", "album", "album",
                   "album", "album", "album", "album", NA, "album", NA, "single",
                   NA, "album"),
    release_date = c("1965-08-06", "2009-09-09", "1994-11-30", NA, "1968-11-22",
                     NA, "1965-08-06", "1965-08-06", NA, NA, NA, NA, NA, NA, NA,
                     NA, "2000-01-01"),
    lyrics = c(NA, NA, NA, NA, NA, NA, strrep("yesterday all my troubles ", 5),
               NA, NA, NA, NA, NA, NA, NA, NA, NA,
               paste("[Verse]", strrep("yesterday all my troubles ", 5)))
  )
}

test_that("flag_songs finds version qualifiers but not main titles", {
  f <- flag_songs(catalog())
  expect_equal(f$base_title[1:4], c("Help!", "Help!", "Help!", "Revolution"))
  expect_equal(f$base_title[9], "I Want You (She’s So Heavy)")
  expect_equal(f$base_title[13], "Hey Jude")
  expect_true(f$is_remasters[2])
  expect_true(f$is_live[3])
  expect_false(f$is_live[6])
  expect_true(f$is_demos[4])
  expect_true(f$is_mono[8])
  expect_true(f$is_remixes[10])
  expect_true(f$is_rerecordings[11])
  expect_true(f$is_translations[12])
  expect_true(f$is_soundtracks[14])
  expect_true(f$is_singles[15])
  expect_true(f$is_compilations[16])
  expect_false(any(f$is_compilations[-16]))
})

test_that("album_type from Genius beats album-name keywords", {
  songs <- tibble::tibble(title = c("A", "B"), album = c("Live Through This", "Live Through This"),
                          album_type = c("album", NA))
  f <- flag_songs(songs)
  expect_false(f$is_live[1])
  expect_false(f$is_live[2])
  songs$album <- "Greatest Hits"
  expect_equal(flag_songs(songs)$is_compilations, c(FALSE, TRUE))
})

test_that("relationships and translation pages are flagged", {
  songs <- tibble::tibble(
    title = c("A", "B", "C"),
    artist = c("X", "X", "Genius English Translations"),
    relationship = c("cover_of", "remix_of, live_version_of", NA)
  )
  f <- flag_songs(songs)
  expect_equal(f$is_covers, c(TRUE, FALSE, FALSE))
  expect_equal(f$is_remixes, c(FALSE, TRUE, FALSE))
  expect_equal(f$is_live, c(FALSE, TRUE, FALSE))
  expect_equal(f$is_translations, c(FALSE, FALSE, TRUE))
})

test_that("distinct_songs keeps the original version", {
  kept <- distinct_songs(catalog())
  expect_true("Help!" %in% kept$title)
  expect_false(any(c("Help! - Remastered 2009", "Help! (Live at the BBC)", "Yesterday - Mono") %in% kept$title))
  # Same lyrics under another title is a duplicate too
  expect_false("Copy" %in% kept$title)
  expect_true("Yesterday" %in% kept$title)
})

test_that("distinct_songs keeps a version when it's the only one", {
  songs <- tibble::tibble(title = "Help! - Remastered 2009", artist = "X")
  expect_equal(nrow(distinct_songs(songs)), 1)
  expect_equal(nrow(filter_songs(songs, remove = "remasters", verbose = FALSE)), 0)
})

test_that("prefer changes which duplicate is kept", {
  songs <- tibble::tibble(
    title = c("Song", "Song (Remix)"), artist = "X",
    release_date = c("2001-01-01", "2000-01-01"), pageviews = c(1L, 100L)
  )
  expect_equal(distinct_songs(songs)$title, "Song")
  expect_equal(distinct_songs(songs, prefer = "earliest")$title, "Song (Remix)")
  expect_equal(distinct_songs(songs, prefer = "popular")$title, "Song (Remix)")
})

test_that("filter_songs removes chosen categories and reports", {
  expect_message(out <- filter_songs(catalog()), "Removed")
  expect_false(any(c("Help! (Live at the BBC)", "Revolution (Take 20)",
                     "Let It Be (Naked Version)") %in% out$title))
  expect_true("Theme" %in% out$title)
  out <- filter_songs(catalog(), remove = c("soundtracks", "singles", "compilations"), verbose = FALSE)
  expect_false(any(c("Theme", "Single Song", "Title Track") %in% out$title))
  expect_equal(names(out), names(catalog()))
  expect_equal(
    filter_songs(catalog(), remove = "all", verbose = FALSE)$title,
    c("Help!", "Revolution 1", "Live and Let Die", "Yesterday",
      "I Want You (She\u2019s So Heavy)", "Hey Jude (Album Version)")
  )
  expect_error(filter_songs(catalog(), remove = "bogus"), "Unknown")
})
