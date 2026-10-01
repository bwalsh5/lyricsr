# lyricsr

An R package to search [Genius](https://genius.com) for songs, artists, and albums, and
get their lyrics as tibbles.

- [Installation](#installation)
- [Usage](#usage): a step-by-step walkthrough and function reference
- [Downloading lyrics](#downloading-lyrics): [by song](#by-song), [by album](#by-album), [by artist](#by-artist), [by genre](#by-genre)
- [Cleaning up results](#cleaning-up-results): duplicates, soundtracks, singles, mono releases, live versions, and more
- [Saving to CSV](#saving-to-csv)
- [Text analysis](#text-analysis)
- [Speed, caching, and reliability](#speed-caching-and-reliability)

## Installation

```r
# install.packages("remotes")
remotes::install_github("bwalsh5/lyricsr")
library(lyricsr)
```

Or from a local copy: `devtools::install("path/to/lyricsr")`.

No Genius API token or account is needed. lyricsr uses the same public API
that genius.com itself uses.

## Usage

### Step by step

Most projects follow the same five steps: download, clean, check, save,
analyze.

**1. Load the package.**

```r
library(lyricsr)
```

**2. Download songs.** Choose one of these, depending on what you're
studying:

```r
songs <- search_song(c("HUMBLE.", "Alright"), "Kendrick Lamar")      # specific songs
songs <- search_album("DAMN.", "Kendrick Lamar")                     # one album
songs <- search_artist("Kendrick Lamar")                             # an artist's catalog
songs <- search_genre("country", max_songs = 200)                    # a genre
```

Progress is printed as songs are collected. The result is a tibble with one
row per song. Open it in RStudio's or Positron's data viewer with
`View(songs)`.

To combine several artists, download each and bind the results:

```r
songs <- rbind(
  search_artist("Kendrick Lamar", max_songs = 50),
  search_artist("Big Thief", max_songs = 50)
)
```

**3. Remove duplicates and releases you don't want.** Artist catalogs in
particular include live versions, demos, remixes, remasters, and songs from
soundtracks and compilations:

```r
clean <- filter_songs(songs)
#> Removed 12 of 60 songs (4 live, 3 demos, 5 duplicates); 48 left.

# Or choose exactly what to remove
clean <- filter_songs(songs, remove = c("duplicates", "live", "demos", "remixes",
                                        "soundtracks", "compilations", "singles", "mono"))
```

See [Cleaning up results](#cleaning-up-results) for all the categories.

**4. Check what was removed.** Detection is keyword-based, so look before
relying on it:

```r
flags <- flag_songs(songs)
View(flags)                                  # one TRUE/FALSE column per category
flags[flags$is_live, c("title", "album")]    # e.g. everything flagged as live
```

**5. Save or analyze.**

```r
save_lyrics(clean, "lyrics.csv")             # artist, album, release_date, title, lyrics
lines <- tidy_lyrics(clean)                  # one row per lyric line, for text analysis
```

### A complete script

```r
library(lyricsr)

# Download
songs <- search_artist("Kendrick Lamar")

# Clean: one studio version of each song
songs <- filter_songs(songs, remove = c("duplicates", "live", "demos", "remixes",
                                        "soundtracks", "compilations"))

# Save
save_lyrics(songs, "kendrick_lamar.csv")
save_lyrics(songs, "kendrick_lamar_lines.csv", by_line = TRUE)
```

The first run downloads everything. Later runs use the cache and finish in
seconds, so you can adjust the filters and rerun the whole script freely.

### Function reference

| Task | Function |
|---|---|
| **Download** | |
| Songs by title (and artist) | `search_song(title, artist)` |
| An album's tracks | `search_album(name, artist)` |
| An artist's songs | `search_artist(name, max_songs)` |
| A genre's most popular songs | `search_genre(genre, max_songs)` |
| Lyrics for one URL | `genius_lyrics(song_url)` |
| Lyrics from LRCLIB | `lrclib_lyrics(title, artist)` |
| **Clean** | |
| Remove categories and duplicates | `filter_songs(songs, remove)` |
| Remove only duplicates | `distinct_songs(songs)` |
| Flag songs without removing them | `flag_songs(songs)` |
| Title terms that mark non-songs | `default_excluded_terms()` |
| **Save and analyze** | |
| Write a CSV | `save_lyrics(songs, path)` |
| One row per lyric line | `tidy_lyrics(songs)` |
| **Cache** | |
| Where downloads are cached | `genius_cache_dir()` |
| Clear the cache | `genius_cache_clear()` |
| **Low-level Genius API** | |
| Raw search, song, artist, album, and tag data | `genius_search()`, `genius_song()`, `genius_artist()`, `genius_artist_songs()`, `genius_album()`, `genius_album_tracks()`, `genius_tag()` |

### Getting help

Every function has a help page with all its arguments and examples:

```r
?search_artist
?filter_songs        # includes the full list of categories
?save_lyrics
help(package = "lyricsr")
```

### Working on the package locally

To try changes without installing, open the `lyricsr` folder in Positron or
RStudio (in Positron: **File → Open Folder…**) and load it:

```r
devtools::load_all()   # or Cmd/Ctrl+Shift+L
```

Run `load_all()` again after editing files in `R/`. Other shortcuts:

| Task | Shortcut | Console |
|---|---|---|
| Load the package | Cmd/Ctrl+Shift+L | `devtools::load_all()` |
| Run tests | Cmd/Ctrl+Shift+T | `devtools::test()` |
| Rebuild help pages | Cmd/Ctrl+Shift+D | `devtools::document()` |
| Full package check | Cmd/Ctrl+Shift+E | `devtools::check()` |
| Install | Cmd/Ctrl+Shift+B | `devtools::install()` |

## Downloading lyrics

Every download function returns a tibble with one row per song:

| Column | Contents |
|---|---|
| `song_id`, `title`, `url` | The song on Genius |
| `artist`, `artist_id`, `featured_artists` | Primary artist and any featured artists |
| `album`, `album_id`, `album_type` | The song's album. `album_type` is `"album"`, `"ep"`, `"single"`, `"compilation"`, `"soundtrack"`, or `"live"` |
| `release_date` | `"YYYY-MM-DD"`, or shorter if Genius only has the year or month |
| `genre`, `tags` | Genius's primary genre tag, and all tags |
| `language` | Language code, e.g. `"en"` |
| `relationship` | Set if Genius marks the song as a `cover_of`, `remix_of`, `live_version_of`, or `translation_of` another song |
| `pageviews` | Genius pageviews, a rough popularity measure |
| `lyrics`, `lyrics_source` | The lyrics, with lines separated by `"\n"`, and where they came from |

### By song

```r
song <- search_song("HUMBLE.", "Kendrick Lamar")
cat(song$lyrics)

# Several at once: title and artist are vectorised
songs <- search_song(c("HUMBLE.", "Alright", "Swimming Pools (Drank)"), "Kendrick Lamar")

# By Genius ID, or just the lyrics from a URL
search_song(song_id = 3039923)
genius_lyrics("https://genius.com/Kendrick-lamar-humble-lyrics")
```

Songs that can't be found are skipped with a warning.

### By album

```r
damn <- search_album("DAMN.", "Kendrick Lamar")
damn[c("track_number", "title", "release_date")]
#>    track_number title   release_date
#>  1            1 BLOOD.  2017-04-14
#>  2            2 DNA.    2017-04-14
#>  ...

# By Genius album ID (every result has an album_id column)
search_album(album_id = damn$album_id[1])
```

Albums come back in track order, with a `track_number` column. Use
`get_full_info = TRUE` to also get each track's genre, tags, and pageviews
(one extra request per track).

### By artist

```r
# Top 50 songs by popularity
kendrick <- search_artist("Kendrick Lamar", max_songs = 50)

# Everything, oldest first
beatles <- search_artist("The Beatles", sort = "release_date")

# Only the song list, no lyrics (much faster), e.g. to decide what to download
catalog <- search_artist("The Beatles", fetch_lyrics = FALSE)
```

Useful arguments:

- `max_songs`: stop after this many songs. `NULL` (the default) gets all of them.
- `sort`: `"popularity"` (default), `"title"`, or `"release_date"`.
- `include_features = TRUE`: also include songs where the artist is only featured.
- `get_full_info = FALSE`: skip the extra request per song. Faster, but
  `album`, `release_date`, `genre`, and the other metadata columns will be
  empty, and the album-based filters below won't work.
- `artist_id`: use a Genius artist ID instead of searching by name.

Artists with long histories have many more song pages than songs. The
Beatles have about 1,200, most of them takes, mixes, and live recordings.
See [Cleaning up results](#cleaning-up-results).

### By genre

```r
country <- search_genre("country", max_songs = 200)
rnb     <- search_genre("R&B", max_songs = 100)
```

`search_genre()` reads Genius's tag pages, e.g.
<https://genius.com/tags/country/all>, most popular songs first. Pass the
genre as a name (`"R&B"`, `"Hip Hop"`, `"K-Pop"`) or as it appears in the
URL (`"r-b"`, `"hip-hop"`, `"k-pop"`). Common tags are `"rap"`, `"pop"`,
`"rock"`, `"r-b"`, `"country"`, and `"indie"`. Browse all tags at
<https://genius.com/tags>.

To get only one genre from an artist or album, filter on the `genre` or
`tags` column:

```r
kendrick[kendrick$genre == "Rap", ]
kendrick[grepl("West Coast", kendrick$tags), ]
```

### Common options

All the download functions accept:

- `remove_section_headers = TRUE`: drop `[Chorus]`, `[Verse 1]`, and similar headers.
- `skip_non_songs = TRUE` (default): skip track lists, liner notes, skits,
  interviews, instrumentals, and songs with unfinished lyrics. Add your own
  terms with `excluded_terms = c("(Remix)", "Interlude")`.
- `fallback = "lrclib"` (song, artist, and album): if Genius has no lyrics,
  look in [LRCLIB](https://lrclib.net). `lyrics_source` records which source
  was used. LRCLIB lyrics have no section headers and different punctuation,
  so check this column before combining the two.

## Cleaning up results

Genius has many pages for one song: live recordings, demos, numbered takes,
remixes, mono and stereo mixes, remasters, radio edits, appearances on
soundtracks and compilations, and translations. Three functions deal with
them:

| Function | What it does |
|---|---|
| `filter_songs(songs, remove = ...)` | Removes the categories you choose. If `"duplicates"` is among them, collapses what's left to one row per song. |
| `distinct_songs(songs)` | Only collapses duplicates, keeping the original version of each song. |
| `flag_songs(songs)` | Removes nothing. Adds a `base_title` column and one `TRUE`/`FALSE` `is_*` column per category, so you can see what would be removed. |

### Quick start

```r
beatles <- search_artist("The Beatles")

# Default: remove duplicates, live versions, demos/takes, remixes,
# translations, and non-songs (speeches, interviews)
studio <- filter_songs(beatles)
#> Removed 843 of 1200 songs (231 live, 360 demos, 191 remixes, ...); 357 left.

# Also drop soundtracks, compilations, singles, EPs, and mono releases
core <- filter_songs(beatles, remove = c(
  "duplicates", "live", "demos", "remixes", "translations", "non_songs",
  "soundtracks", "compilations", "singles", "eps", "mono"
))

# Every category
filter_songs(beatles, remove = "all")

# Only collapse duplicates, keeping one version of each song
distinct_songs(beatles)
```

### Categories

Use these names in `remove`:

| Category | What it removes |
|---|---|
| `duplicates` | Other versions of a song already kept: same artist and `base_title` (e.g. `"Help!"`, `"Help! - Remastered 2009"`, `"Help! (Take 4)"`), or identical lyrics under a different title. |
| `live` | Live, concert, BBC, and rooftop recordings; live albums; songs Genius marks as a live version of another song. |
| `demos` | Demos, numbered takes, outtakes, rehearsals, jams, sessions, false starts, alternate and early versions, auditions. |
| `remixes` | Remixes, mixes, stereo mixes, mashups, and other named versions (`"LOVE Version"`, `"Naked Version"`); songs Genius marks as a remix. |
| `edits` | Radio edits, single versions, extended and "10 minute" versions, sped up, slowed, clean, and explicit versions. |
| `acoustic` | Acoustic, unplugged, stripped, piano, and orchestral versions. |
| `remasters` | Remasters. |
| `mono` | Mono versions and mono releases (from the title or album name). |
| `rerecordings` | Re-recordings, including `"Taylor's Version"`. |
| `instrumentals` | Instrumentals, karaoke versions, and backing tracks. |
| `covers` | Songs Genius marks as a cover of another song. |
| `translations` | Translations and romanizations, including Genius's translation pages (e.g. "Genius English Translations"). |
| `non_songs` | Speeches, interviews, dialogue, commentary, skits, scripts, documentaries. |
| `soundtracks` | Songs whose album is a soundtrack or film/TV music. |
| `compilations` | Songs whose album is a compilation, greatest hits, best-of, or anthology. |
| `singles` | Songs whose album is a single. |
| `eps` | Songs whose album is an EP. |
| `no_album` | Songs with no album on Genius. Often non-album singles, but also unreleased songs. Needs `get_full_info = TRUE`. |

### How versions are detected

- **Song titles.** Only the qualifiers in a title are checked: text in
  parentheses or brackets, or after `" - "`. So `"Help! - Remastered 2009"`
  is a remaster and `"Revolution (Take 20)"` is a demo, but
  `"Live and Let Die"` isn't live and `"I Want You (She's So Heavy)"` keeps
  its full title.
- **Albums.** Genius's `album_type` is used when known. Otherwise the album
  name is checked, e.g. "Original Motion Picture Soundtrack" or "Greatest
  Hits".
- **Genius relationships.** Songs Genius links to another song as a cover,
  remix, live version, or translation.

### Removing vs. collapsing

These do different things:

- **Removing a category** drops every song in it, even when there's no other
  version. If Genius only has `"Help! - Remastered 2009"`, then
  `remove = "remasters"` loses the song.
- **Collapsing duplicates** keeps one row per song. The remastered
  `"Help!"` is dropped only if the original is also there.

For remasters, mono, edits, and re-recordings you usually want collapsing, so
the defaults leave those categories out and let `"duplicates"` handle them.

### Which version is kept

`prefer` controls which version of a duplicated song stays:

- `"original"` (default): fewest version markers (so `"Help!"` beats
  `"Help! - Remastered 2009"`), then studio album over EP, single, live,
  compilation, and soundtrack; then earliest release; then most pageviews.
- `"earliest"`: earliest release date first.
- `"popular"`: most pageviews first.

```r
distinct_songs(beatles, prefer = "earliest")
```

### Checking before you remove

Detection is keyword-based, so check what's flagged before relying on it for
research:

```r
flags <- flag_songs(beatles)

# What counts as a demo?
flags[flags$is_demos, c("title", "album")]

# Which versions were collapsed as duplicates?
flags[flags$is_duplicate, c("title", "base_title", "album")]

# Your own rule: studio albums released before 1970
flags[!flags$is_live & flags$album_type %in% "album" & flags$release_date < "1970", ]
```

## Saving to CSV

```r
save_lyrics(studio, "beatles.csv")
```

By default this writes only the columns most analyses need: `artist`,
`album`, `release_date`, `title`, and `lyrics`. It uses UTF-8, and lyrics
keep their line breaks inside quoted fields, which `read.csv()`,
`readr::read_csv()`, Excel, and pandas all read correctly.

```r
# Choose the columns (any column of the tibble)
save_lyrics(studio, "beatles.csv",
            columns = c("artist", "album", "release_date", "lyrics"))

# Without [Chorus] / [Verse] headers
save_lyrics(studio, "beatles.csv", remove_section_headers = TRUE)

# One row per lyric line, with line_number and section columns
# (no line breaks inside fields)
save_lyrics(studio, "beatles_lines.csv", by_line = TRUE)
```

A typical workflow for an artist:

```r
library(lyricsr)

songs <- search_artist("Kendrick Lamar")
songs <- filter_songs(songs, remove = c("duplicates", "live", "demos", "remixes",
                                        "soundtracks", "compilations", "singles"))
save_lyrics(songs, "kendrick_lamar.csv")
```

For a genre:

```r
songs <- search_genre("country", max_songs = 500)
songs <- filter_songs(songs)
save_lyrics(songs, "country.csv")
```

## Text analysis

`tidy_lyrics()` gives one row per lyric line. Section headers become
`section` and `section_artist` columns instead of lines:

```r
lines <- tidy_lyrics(studio)
lines[c("title", "line_number", "section", "line")]
#>   title        line_number section line
#> 1 The Magician           1 Verse 1 Do you find it gets a little ...
```

It works directly with tidytext:

```r
library(tidytext)
tidy_lyrics(studio) |>
  unnest_tokens(word, line) |>
  dplyr::anti_join(stop_words, by = "word") |>
  dplyr::count(word, sort = TRUE)
```

## Speed, caching, and reliability

- **Caching.** Lyrics are saved on disk by URL and never downloaded twice.
  API responses (search results, metadata) are cached for 7 days. Running
  the same script again is almost instant. See `?genius_cache_dir`; clear
  with `genius_cache_clear()`.
- **Rate limiting.** At most 2 requests per second by default, with
  automatic retries and backoff. With full info, each song takes about 2
  requests, so a 500-song artist takes around 8 minutes the first time.
  `fetch_lyrics = FALSE` or `get_full_info = FALSE` is much faster for
  exploring.
- **Reliable extraction.** Lyrics come from the page's
  `data-lyrics-container` elements. If Genius changes that markup, lyricsr
  falls back to the lyrics embedded in the page's `__PRELOADED_STATE__`
  JSON.

### Options

| Option | Default |
|---|---|
| `lyricsr.rate` | `2` requests per second |
| `lyricsr.max_tries` | `3` |
| `lyricsr.timeout` | `10` seconds |
| `lyricsr.cache` | `TRUE` |
| `lyricsr.cache_dir` | `tools::R_user_dir("lyricsr", "cache")` |
| `lyricsr.api_max_age` | 7 days (in seconds) |
| `lyricsr.user_agent` | `lyricsr/<version> (R <version>; <OS>)` |

## Mapping from the Python lyricsgenius package

| Python (`genius = Genius(token)`) | R |
|---|---|
| `genius.search_song(title, artist)` | `search_song(title, artist)` |
| `genius.search_artist(name, max_songs)` | `search_artist(name, max_songs)` |
| `genius.search_album(name, artist)` | `search_album(name, artist)` |
| `genius.tag(name)` | `search_genre(name)`, or `genius_tag(name)` for the raw list |
| `genius.lyrics(song_url=...)` | `genius_lyrics(song_url = ...)` |
| `genius.search_all(term)` | `genius_search(term)` |
| `genius.song(id)`, `.artist(id)`, `.album(id)` | `genius_song()`, `genius_artist()`, `genius_album()` |
| `genius.artist_songs(id)`, `.album_tracks(id)` | `genius_artist_songs()`, `genius_album_tracks()` |
| `artist.save_lyrics()` | `save_lyrics()` |
| `Song`, `Artist`, `Album` objects | tibbles |

## A note on use

Lyrics are copyrighted, and Genius's terms of service restrict scraping.
This package is intended for personal and research use, such as text
analysis. Keep request rates low and don't redistribute the lyrics you
collect.

## Tests

`devtools::test()` runs offline tests against synthetic pages. To also run
live tests against genius.com:

```r
Sys.setenv(LYRICSR_LIVE_TESTS = "true")
devtools::test()
```
