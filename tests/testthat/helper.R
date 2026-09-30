fixture_html <- function() {
  paste(readLines(test_path("fixtures", "song.html"), encoding = "UTF-8"), collapse = "\n")
}

expected_lyrics <- paste(
  "[Verse 1: Test Artist]",
  "First line, it's here",
  "Second line costs $5",
  "",
  "[Chorus]",
  "Hook line",
  sep = "\n"
)

skip_if_no_genius <- function() {
  skip_on_cran()
  skip_if_offline("genius.com")
  skip_if_not(identical(Sys.getenv("LYRICSR_LIVE_TESTS"), "true"),
              "Set LYRICSR_LIVE_TESTS=true to run live tests")
}
