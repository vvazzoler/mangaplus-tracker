# https://www.reddit.com/r/WeeklyShonenJump/comments/1bww81r/i_made_a_site_that_tracks_m_views/
# https://github.com/MangaplusTracker/MangaplusTracker.github.io
# https://mangaplustracker.github.io/

# Mangaplus 2026/04  Update ----------------------------------------------

library(rvest)
library(tidyverse)
library(mongolite)

options(chromote.timeout = 60)
url       <- 'https://mangaplus.shueisha.co.jp'

read_live_with_retry <- function(url, attempts = 3, wait = 10) {
  for (i in seq_len(attempts)) {
    tryCatch({
      page <- rvest::read_html_live(url)
      Sys.sleep(8)
      return(page)
    }, error = function(e) {
      message(sprintf("Attempt %d failed: %s", i, e$message))
      if (i < attempts) Sys.sleep(wait)
      else stop(e)
    })
  }
}

# Data Collection ---------------------------------------------------------

## Main Page ----

tryCatch({
  
  live_page <- read_live_with_retry(url)
  
  ### first title ----
  main_first_manga <- ".UpdatedTitle-module_topChapter_27M5N p" |>
    live_page$html_elements(css = _) |>
    rvest::html_text()
  
  ### all other ----
  
  main_all_manga <- ".UpdatedTitle-module_titleDescription_Cf0hO p" |>
    live_page$html_elements(css = _) |>
    rvest::html_text()
  
  now_timestamp <- now(tzone = "UTC") |> floor_date(unit = "minute")
  
}, finally = {
  try(live_page$session$close(), silent = TRUE)
})

### any new manga ?
# ".UpdatedTitle-module_topTitleWrapper_1wAqA p" |>
#   live_page$html_elements(css = _) |>
#   rvest::html_text()
# 
# ".UpdatedTitle-module_upLabel_3afXn" |>
#   live_page$html_elements(css = _) |>
#   rvest::html_text()

# Upload ------------------------------------------------------------------

manga_data <-
  c(
    # the first manga also contain the author(s) name
    main_first_manga[-2],
    main_all_manga
  ) |>
  matrix(ncol = 3, byrow = T) |>
  as_tibble() |>
  rename_all(~c("title", "chapter", "views")) |>
  mutate(
    timestamp = now_timestamp
  )

# Set MongoDB connection
mongo_conn <- mongo(db = "default", collection = "mangaplus", url = Sys.getenv("MONGO_URL"))

# Add it to the collection
mongo_conn$insert(manga_data)

# Close the MongoDB connection
mongo_conn$disconnect()