public_api_root <- "https://genius.com/api/"
web_root <- "https://genius.com/"

# Build a request with the package's user agent, throttle, retry and timeout
# settings. All Genius requests share one throttle realm so the rate limit
# applies across endpoints.
genius_req <- function(url) {
  httr2::request(url) |>
    httr2::req_user_agent(getOption("lyricsr.user_agent", default_user_agent())) |>
    httr2::req_timeout(getOption("lyricsr.timeout", 10)) |>
    httr2::req_throttle(
      capacity = 1,
      fill_time_s = 1 / getOption("lyricsr.rate", 2),
      realm = "genius.com"
    ) |>
    httr2::req_retry(
      max_tries = getOption("lyricsr.max_tries", 3),
      retry_on_failure = TRUE
    )
}

# Like the Python package: name, version, and platform. Genius's bot filter
# rejects user agents that contain a URL, so don't add one.
default_user_agent <- function() {
  sys <- Sys.info()
  sprintf(
    "lyricsr/%s (R %s; %s %s)",
    utils::packageVersion("lyricsr"), getRversion(),
    sys[["sysname"]], sys[["release"]]
  )
}

# GET a path on Genius's public API (the one genius.com itself uses) and
# return the parsed `response` element. No access token is needed.
genius_get <- function(path, params = list()) {
  params <- params[!vapply(params, is.null, logical(1))]
  req <- genius_req(paste0(public_api_root, path)) |>
    httr2::req_url_query(!!!params)
  url <- req$url

  cached <- cache_get("api", url)
  if (!is.null(cached)) {
    return(cached)
  }

  resp <- httr2::req_perform(req)
  body <- httr2::resp_body_json(resp, simplifyVector = FALSE)
  out <- body$response %||% body
  cache_set("api", url, out)
  out
}

# GET a web page on genius.com and return its HTML as a string. Returns NULL
# for 404s so callers can treat missing pages as "no lyrics".
genius_get_html <- function(url) {
  resp <- genius_req(url) |>
    httr2::req_error(is_error = function(resp) {
      httr2::resp_status(resp) >= 400 && httr2::resp_status(resp) != 404
    }) |>
    httr2::req_perform()
  if (httr2::resp_status(resp) == 404) {
    return(NULL)
  }
  httr2::resp_body_string(resp)
}
