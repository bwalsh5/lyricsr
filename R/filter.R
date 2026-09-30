#' Flag, filter, and de-duplicate songs
#'
#' Genius often has many pages for one song: live recordings, demos, alternate
#' takes, remixes, mono and stereo mixes, remasters, radio edits, soundtrack and
#' compilation appearances, and translations. These functions find and remove
#' them.
#'
#' * `flag_songs()` adds a `base_title` column and one logical `is_*` column
#'   per category, so you can inspect or filter them yourself.
#' * `filter_songs()` removes the categories you choose and, if
#'   `"duplicates"` is among them, collapses what's left to one row per song.
#' * `distinct_songs()` only collapses duplicates.
#'
#' @section Categories:
#' Categories marked *(title)* are detected from qualifiers in the song title,
#' meaning text in parentheses or brackets, or after `" - "`. For example,
#' `"Help! - Remastered 2009"` or `"Revolution (Take 20)"`. The main title is
#' never matched, so `"Live and Let Die"` isn't flagged as live.
#' Categories marked *(album)* use the album's `album_type` from Genius when
#' known, and otherwise keywords in the album name.
#'
#' | Category | What it matches |
#' |---|---|
#' | `duplicates` | Other versions of a song already kept: same artist and `base_title`, or identical lyrics. |
#' | `live` | *(title)* Live, concert, BBC, rooftop, and other performances; *(album)* live albums; songs Genius marks as a live version of another song. |
#' | `demos` | *(title)* Demos, takes, outtakes, rehearsals, jams, sessions, alternate and early versions, auditions. |
#' | `remixes` | *(title)* Remixes, mixes, stereo mixes, mashups, and other named versions (e.g. `"Naked Version"`); songs Genius marks as a remix. |
#' | `edits` | *(title)* Radio edits, single versions, extended, sped up, slowed, clean, and explicit versions. |
#' | `acoustic` | *(title)* Acoustic, unplugged, stripped, piano, and orchestral versions. |
#' | `remasters` | *(title)* Remasters. |
#' | `mono` | *(title or album name)* Mono versions and mono releases. |
#' | `rerecordings` | *(title)* Re-recordings, including `"Taylor's Version"`. |
#' | `instrumentals` | *(title)* Instrumentals, karaoke, and backing tracks. |
#' | `covers` | Songs Genius marks as a cover; *(title)* `"Cover"`. |
#' | `translations` | Songs Genius marks as a translation; Genius translation and romanization pages; *(title)* `"Translation"` and similar. |
#' | `non_songs` | *(title)* Speeches, interviews, dialogue, commentary, skits, and scripts. |
#' | `soundtracks` | *(album)* Soundtracks and film or TV music. |
#' | `compilations` | *(album)* Compilations, greatest hits, best-ofs, anthologies. |
#' | `singles` | *(album)* Songs whose album is a single. |
#' | `eps` | *(album)* Songs whose album is an EP. |
#' | `no_album` | Songs with no album on Genius. Often non-album singles, but also unreleased songs. Only meaningful with `get_full_info = TRUE`. |
#'
#' @section Choosing which duplicate to keep:
#' Rows are ranked, and the best in each group is kept:
#' * `prefer = "original"` (default): fewest version flags (so `"Help!"`
#'   beats `"Help! - Remastered 2009"`), then studio album over EP, single,
#'   live, compilation, and soundtrack; then earliest release; then most
#'   pageviews.
#' * `prefer = "earliest"`: earliest release date first.
#' * `prefer = "popular"`: most pageviews first.
#'
#' Songs with no other version are always kept by `distinct_songs()`. For
#' example, if Genius only has `"Help! - Remastered 2009"`, that row stays. To
#' drop a category outright, name it in `remove`.
#'
#' @param songs A tibble from [search_song()], [search_artist()],
#'   [search_album()], or [search_genre()]. It needs a `title` column; `artist`,
#'   `album`, `album_type`, `relationship`, `release_date`, `pageviews`, and
#'   `lyrics` are used when present.
#' @param remove Categories to remove (see below). Use `"all"` for every
#'   category.
#' @param prefer How to choose which version of a duplicated song to keep.
#' @param verbose If `TRUE`, reports how many songs were removed and why.
#' @return `flag_songs()` returns `songs` with `base_title` and `is_*` columns
#'   added. `filter_songs()` and `distinct_songs()` return `songs` with rows
#'   removed and the original columns.
#' @export
#' @examples
#' songs <- tibble::tibble(
#'   title = c("Help!", "Help! - Remastered 2009", "Help! (Live at the BBC)",
#'             "Revolution (Take 20)", "Live and Let Die", "Yesterday - Mono"),
#'   artist = "Example",
#'   album = c("Help!", "Help! (Remastered)", "Live at the BBC", "Revolution 1",
#'             "Singles", "Help!")
#' )
#' flag_songs(songs)[c("title", "base_title", "is_live", "is_demos", "is_mono")]
#' filter_songs(songs)
#' distinct_songs(songs)
filter_songs <- function(songs,
                         remove = c("duplicates", "live", "demos", "remixes",
                                    "translations", "non_songs"),
                         prefer = c("original", "earliest", "popular"),
                         verbose = TRUE) {
  prefer <- match.arg(prefer)
  if (identical(remove, "all")) remove <- song_categories()
  bad <- setdiff(remove, song_categories())
  if (length(bad)) {
    cli::cli_abort(c(
      "Unknown categor{?y/ies} in {.arg remove}: {.val {bad}}.",
      "i" = "Choose from {.val {song_categories()}}."
    ))
  }

  flags <- flag_songs(songs)
  drop_cats <- setdiff(remove, "duplicates")
  drop <- rep(FALSE, nrow(songs))
  counts <- integer()
  for (cat in drop_cats) {
    hit <- flags[[paste0("is_", cat)]] & !drop
    counts[cat] <- sum(hit)
    drop <- drop | hit
  }
  out <- songs[!drop, , drop = FALSE]

  if ("duplicates" %in% remove) {
    n <- nrow(out)
    out <- distinct_songs(out, prefer = prefer)
    counts["duplicates"] <- n - nrow(out)
  }

  if (verbose) {
    counts <- counts[counts > 0]
    removed <- nrow(songs) - nrow(out)
    detail <- if (length(counts)) paste0(" (", paste(counts, names(counts), collapse = ", "), ")") else ""
    cli::cli_inform("Removed {removed} of {nrow(songs)} song{?s}{detail}; {nrow(out)} left.")
  }
  out
}

#' @rdname filter_songs
#' @export
distinct_songs <- function(songs, prefer = c("original", "earliest", "popular")) {
  prefer <- match.arg(prefer)
  if (nrow(songs) == 0) {
    return(songs)
  }
  keep <- !duplicate_rows(flag_songs(songs), prefer)
  songs[keep, , drop = FALSE]
}

#' @rdname filter_songs
#' @export
flag_songs <- function(songs) {
  if (!"title" %in% names(songs)) {
    cli::cli_abort("{.arg songs} must have a {.field title} column.")
  }
  n <- nrow(songs)
  col <- function(name) if (name %in% names(songs)) as.character(songs[[name]]) else rep(NA_character_, n)
  title <- col("title")
  album <- col("album")
  album_type <- tolower(col("album_type"))
  relationship <- col("relationship")
  artist <- col("artist")

  quals <- title_qualifiers(title)
  q_cats <- lapply(quals, function(q) lapply(q, qualifier_categories))
  title_has <- function(cat) {
    vapply(q_cats, function(qc) any(vapply(qc, function(c) cat %in% c, logical(1))), logical(1))
  }
  rel_has <- function(type) !is.na(relationship) & grepl(type, relationship, fixed = TRUE)
  album_is <- function(type, pattern) {
    ifelse(!is.na(album_type), album_type == type,
           !is.na(album) & grepl(pattern, album, ignore.case = TRUE, perl = TRUE))
  }

  flags <- list(
    live = title_has("live") | rel_has("live_version_of") |
      (!is.na(album_type) & album_type == "live"),
    demos = title_has("demos"),
    remixes = title_has("remixes") | rel_has("remix_of"),
    edits = title_has("edits"),
    acoustic = title_has("acoustic"),
    remasters = title_has("remasters"),
    mono = title_has("mono") | (!is.na(album) & grepl("\\bmono\\b", album, ignore.case = TRUE)),
    rerecordings = title_has("rerecordings"),
    instrumentals = title_has("instrumentals"),
    covers = title_has("covers") | rel_has("cover_of"),
    translations = title_has("translations") | rel_has("translation_of") |
      (!is.na(artist) & grepl("^Genius\\b.*\\b(Translations?|Romanizations?|Traducciones|Tradu\u00e7\u00f5es|\u00dcbersetzungen)\\b", artist, perl = TRUE)),
    non_songs = title_has("non_songs"),
    soundtracks = album_is("soundtrack", album_patterns[["soundtracks"]]),
    compilations = album_is("compilation", album_patterns[["compilations"]]),
    singles = album_is("single", album_patterns[["singles"]]),
    eps = album_is("ep", album_patterns[["eps"]]) | title_has("eps"),
    no_album = is.na(album)
  )

  base <- as.character(mapply(base_title, title, quals, q_cats, USE.NAMES = FALSE))
  out <- songs
  out$base_title <- base
  for (cat in names(flags)) {
    out[[paste0("is_", cat)]] <- flags[[cat]]
  }
  out$is_duplicate <- duplicate_rows(out, "original")
  out
}

# All categories filter_songs() accepts.
song_categories <- function() {
  c("duplicates", "live", "demos", "remixes", "edits", "acoustic", "remasters",
    "mono", "rerecordings", "instrumentals", "covers", "translations",
    "non_songs", "soundtracks", "compilations", "singles", "eps", "no_album")
}

# Categories that mean "this is another version of a song", used to rank
# duplicates. Album-level categories are ranked separately.
version_categories <- c("live", "demos", "remixes", "edits", "acoustic",
                        "remasters", "mono", "rerecordings", "instrumentals",
                        "covers", "translations")

# Keyword patterns for title qualifiers (case-insensitive, Perl regex).
qualifier_patterns <- c(
  live = "\\blive\\b|\\bconcert\\b|\\bbbc\\b|\\bperformance\\b|\\brooftop\\b|\\bhollywood bowl\\b|\\bon tour\\b|\\bat the\\b.*\\b(festival|arena|theat(er|re)|hall|club|stadium)\\b",
  demos = "\\bdemos?\\b|\\btakes?\\s*(\\d|#|one|two|three)|\\bouttakes?\\b|\\brehearsals?\\b|\\bjam\\b|\\bsessions?\\b|\\balternat(e|ive)\\b|\\balt\\.?\\s+(take|version|mix)\\b|\\b(early|first|original) (version|take)\\b|\\bhome recording\\b|\\bwork ?tape\\b|\\brough\\b|\\bauditions?\\b|\\bunreleased\\b|\\bunnumbered\\b|\\bunumbered\\b|\\bfalse starts?\\b|\\bundubbed\\b|\\bwithout\\b|\\bisolated\\b|\\bvocals? (only|track)\\b|\\bvocals?,|\\bbreakdown\\b|\\bcoaching\\b|\\bsound effects\\b",
  remixes = "\\bre-?mix(ed)?\\b|\\bmix\\b|\\bmixes\\b|\\bstereo\\b|\\bmash-?up\\b|\\bdub\\b|\\bvip\\b|\\bflip\\b|\\bbootleg\\b",
  edits = "\\bedit\\b|\\bradio\\b|\\bsingle (version|edit|mix)\\b|\\bextended\\b|\\b\\d+ minute version\\b|\\b(short|long) version\\b|\\bsped up\\b|\\bslowed\\b|\\breverb\\b|\\bnightcore\\b|\\bclean\\b|\\bexplicit\\b|\\bcensored\\b|\\bdirty\\b|\\ba ?cappella\\b|\\bacapella\\b",
  acoustic = "\\bacoustic\\b|\\bunplugged\\b|\\bstripped\\b|\\bpiano (version|mix)\\b|\\borchestral\\b|\\bsymphonic\\b",
  remasters = "\\bre-?master(ed|ing)?\\b",
  mono = "\\bmono\\b",
  rerecordings = "taylor.?s version|\\bre-?record(ed|ing)?\\b",
  instrumentals = "\\binstrumental\\b|\\bkaraoke\\b|\\bbacking track\\b",
  covers = "\\bcover\\b",
  translations = "\\btranslations?\\b|\\btraducci\u00f3n\\b|\\btraduccion\\b|\\btradu\u00e7\u00e3o\\b|\\btraduction\\b|\\btraduzione\\b|\\b\u00fcbersetzung\\b|\\bromani[sz]ed\\b|\\bromanization\\b|\\btraducere\\b|\\bvertaling\\b|\\b\u00f6vers\u00e4ttning\\b|\\bt\u0142umaczenie\\b|\u00e7eviri|\\bterjemahan\\b|\u043f\u0435\u0440\u0435\u0432\u043e\u0434",
  non_songs = "\\bspeech\\b|\\binterview\\b|\\bdialogue\\b|\\bcommentary\\b|\\bspoken\\b|\\bskit\\b|\\bscript\\b|\\bintroduction by\\b|\\bannouncement\\b|\\bdocumentary\\b",
  eps = "^\\s*ep\\s*$|\\bep version\\b"
)

# Qualifiers that don't change the song, removed from base_title without
# flagging it.
neutral_pattern <- "^\\s*(lyrics|original|bonus( track)?|explicit|from the vault)\\s*$|\\b(album|original|lp)\\s+version\\b|\\bbonus track\\b"

# Album-name patterns, used only when Genius's album_type is unknown.
album_patterns <- c(
  soundtracks = "soundtrack|songtrack|\\bost\\b|music from|motion picture|original score|original (broadway |london )?cast|\\bfrom the\\b.*\\b(film|movie|series|musical)\\b",
  compilations = "greatest hits|\\bbest of\\b|\\bthe best\\b|\\bhits\\b|\\bcollection\\b|\\banthology\\b|\\bessential|\\bcompilation\\b|\\bretrospective\\b|\\bthe singles\\b|\\b(19|20)\\d\\d\\s*[-\u2013]\\s*(19|20)\\d\\d\\b",
  singles = "\\bsingle\\b",
  eps = "\\bep\\b"
)

# Text in (), [], or after " - " in each title.
title_qualifiers <- function(titles) {
  lapply(titles, function(t) {
    if (is.na(t)) return(character())
    groups <- regmatches(t, gregexpr("\\(([^()]*)\\)|\\[([^][]*)\\]", t, perl = TRUE))[[1]]
    groups <- substr(groups, 2, nchar(groups) - 1)
    suffix <- regmatches(t, regexec("\\s[-\u2013\u2014]\\s(.+)$", t, perl = TRUE))[[1]]
    c(groups, if (length(suffix) == 2) suffix[[2]])
  })
}

# Which categories one qualifier belongs to. A qualifier that names some
# other "version" (e.g. "Naked Version", "LOVE Version") counts as a remix.
qualifier_categories <- function(q) {
  cats <- names(qualifier_patterns)[vapply(qualifier_patterns, grepl, logical(1),
                                           x = q, ignore.case = TRUE, perl = TRUE)]
  if (length(cats) == 0 && grepl("\\bversion\\b", q, ignore.case = TRUE) &&
      !grepl(neutral_pattern, q, ignore.case = TRUE, perl = TRUE)) {
    cats <- "remixes"
  }
  cats
}

# Title with version qualifiers (and featured-artist credits) removed, so
# "Help! - Remastered 2009" and "Help! (Live)" both become "Help!". Qualifiers
# that aren't about versions, like "I Want You (She's So Heavy)", are kept.
base_title <- function(title, quals, q_cats) {
  if (is.na(title)) return(NA_character_)
  out <- title
  for (i in seq_along(quals)) {
    q <- quals[[i]]
    drop <- length(q_cats[[i]]) > 0 ||
      grepl("^(feat\\.?|ft\\.?|featuring|with|prod\\.?)\\s", q, ignore.case = TRUE) ||
      grepl(neutral_pattern, q, ignore.case = TRUE, perl = TRUE)
    if (!drop) next
    for (wrapped in c(paste0("(", q, ")"), paste0("[", q, "]"))) {
      out <- sub(wrapped, "", out, fixed = TRUE)
    }
    out <- sub(paste0("\\s[-\u2013\u2014]\\s", escape_regex(q), "$"), "", out, perl = TRUE)
  }
  trimws(gsub("\\s{2,}", " ", out))
}

escape_regex <- function(x) {
  gsub("([.|()\\^{}+$*?\\[\\]\\\\])", "\\\\\\1", x, perl = TRUE)
}

# TRUE for rows that duplicate a better-ranked row: same artist and
# base_title, or the same lyrics.
duplicate_rows <- function(flags, prefer = "original") {
  n <- nrow(flags)
  if (n == 0) return(logical())
  col <- function(name, default = NA) if (name %in% names(flags)) flags[[name]] else rep(default, n)

  n_versions <- Reduce(`+`, lapply(version_categories, function(cat) flags[[paste0("is_", cat)]]))
  album_rank <- match(tolower(col("album_type")),
                      c("album", "ep", "single", NA, "live", "compilation", "soundtrack"))
  album_rank[is.na(album_rank)] <- 4
  album_rank[flags$is_soundtracks] <- pmax(album_rank[flags$is_soundtracks], 7)
  album_rank[flags$is_compilations] <- pmax(album_rank[flags$is_compilations], 6)
  date <- as.character(col("release_date"))
  date[is.na(date)] <- "9999"
  views <- as.numeric(col("pageviews"))
  views[is.na(views)] <- 0

  ord <- switch(prefer,
    original = order(n_versions, album_rank, date, -views),
    earliest = order(date, n_versions, album_rank, -views),
    popular = order(-views, n_versions, album_rank, date)
  )

  artist <- clean_str(as.character(col("artist", "")))
  title_key <- paste(artist, clean_str(flags$base_title), sep = "\r")
  lyrics <- as.character(col("lyrics"))
  lyrics_key <- ifelse(
    !is.na(lyrics) & nchar(lyrics) >= 100,
    paste(artist, clean_str(strip_section_headers(lyrics)), sep = "\r"),
    paste0("\rrow", seq_len(n))
  )

  dup <- logical(n)
  dup[ord] <- duplicated(title_key[ord]) | duplicated(lyrics_key[ord])
  dup
}
