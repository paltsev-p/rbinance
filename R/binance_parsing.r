#' @importFrom dplyr %>%

binance_wss_parsing <- function(wssmsg)
  # data must be in the format effected put in place on 2017-12-01:
  # https://github.com/binance-exchange/binance-official-api-docs/blob/master/web-socket-streams.md#diff-depth-stream

  {
  # basic parsing of binance JSON messages (so far the same for Diff. Depth Stream (wss) messages and depth snapshots)
  wssmsg <- wssmsg %>% gsub("\"", "", .) %>% gsub(',\\[\\]' , "", .) %>% gsub('\\[' , "", .) %>%
    gsub('\\]' , "", .) %>% gsub('\\{' , "", .)  %>% gsub('\\}' , "", .)  %>% gsub(',' , ":", .)  %>% strsplit(":") %>%
    unlist()


# further parsing of messages from wss stream into list object
# https://github.com/binance-exchange/binance-official-api-docs/blob/master/web-socket-streams.md#diff-depth-stream

  # Expected message format:
  # wssmsg <- c("e", "depthUpdate", "E", "1528216289856", "s", "BNBBTC", "U", "80738292", "u", "80738300", "b", "0.00195200", "26.67000000", "0.00195140", "0.00000000", "0.00192140", "17.97000000", "a", "0.00195690", "4.56000000", "0.00195700", "0.00000000")

  assertthat::assert_that(wssmsg[2] == "depthUpdate")
  assertthat::assert_that("b" %in% wssmsg)
  assertthat::assert_that("a" %in% wssmsg)
  assertthat::assert_that(which(wssmsg == "a") - which(wssmsg == "b") > 0)
  assertthat::assert_that( !("[" %in% wssmsg) & !("]" %in% wssmsg))
  assertthat::assert_that( length(wssmsg) %% 2 == 0)


  if (which(wssmsg == "a") - which(wssmsg == "b") > 1 )
    { smallbids <- dplyr::tibble( rate = as.numeric(wssmsg[ seq.int((which(wssmsg == "b")+1), (which( wssmsg == "a")-2), by = 2)]),
                               amount = as.numeric(wssmsg[ seq.int((which(wssmsg == "b")+2), (which( wssmsg == "a")-1), by = 2)] ) )
    } else smallbids <- dplyr::tibble()


  if (length(wssmsg) - which(wssmsg == "a") > 0 )
    {smallasks <- dplyr::tibble( rate = as.numeric(wssmsg[ seq.int((which(wssmsg == "a")+1), length(wssmsg) -1, by = 2)] ),
                              amount = as.numeric(wssmsg[ seq.int((which(wssmsg == "a")+2), length(wssmsg), by = 2)] ) )
    }   else smallasks <- dplyr::tibble()

  result <- list()
  result$type <- wssmsg[2]
  result$time <- as.numeric(wssmsg[4])
  result$pair <- wssmsg[6]
  result$first <- as.numeric(wssmsg[8])
  result$last <- as.numeric(wssmsg[10])
  result$asks <- smallasks
  result$bids <- smallbids

  # assert_that((result$last-result$first) == nrow(result$asks)+nrow(result$bids))

  return(result)
}


binance_snapshot_parsing <- function(snapshot)
  # depth snapshot must be in the format put in place on 2017-12-01:
  # https://github.com/binance-exchange/binance-official-api-docs/blob/master/web-socket-streams.md#how-to-manage-a-local-order-book-correctly
  # example:
  # snapshot <- getURL("https://www.binance.com/api/v1/depth?symbol=BNBBTC&limit=10")

  {

  # basic parsing of binance JSON messages (so far the same for Diff. Depth Stream (wss) messages and depth snapshots)
  snapshot <- snapshot %>% gsub("\"", "", .) %>% gsub(',\\[\\]' , "", .) %>% gsub('\\[' , "", .) %>%
    gsub('\\]' , "", .) %>% gsub('\\{' , "", .)  %>% gsub('\\}' , "", .)  %>% gsub(',' , ":", .)  %>% strsplit(":") %>%
    unlist()

  # checking the format
  # expected message format at this stage:
  # snapshot <- c("lastUpdateId", "81481011", "bids", "0.00213780", "0.48000000", "0.00213770", "60.04000000", "0.00213550", "112.14000000", "0.00213380", "127.14000000", "0.00213350", "187.15000000", "0.00213310", "456.55000000", "0.00213280", "66.09000000", "0.00213260", "12.13000000", "0.00213150", "14.04000000", "0.00213140", "116.20000000", "asks", "0.00213800", "16.55000000", "0.00213810", "2.14000000", "0.00213820", "1.40000000", "0.00213830", "203.18000000", "0.00213870", "4.94000000", "0.00213940", "10.85000000", "0.00213980", "0.73000000", "0.00213990", "5.03000000", "0.00214000", "47.55000000", "0.00214010", "45.59000000")

  assertthat::assert_that(snapshot[1] == "lastUpdateId")
  assertthat::assert_that(snapshot[3] == "bids")
  assertthat::assert_that("asks" %in% snapshot)
  assertthat::assert_that(which(snapshot == "asks") - which(snapshot == "bids") > 0)
  assertthat::assert_that( !("[" %in% snapshot) & !("]" %in% snapshot))



  bids <- dplyr::tibble( rate = as.numeric(snapshot[ seq.int((which(snapshot == "bids")+1), (which( snapshot == "asks")-2), by = 2)]),
                      amount = as.numeric(snapshot[ seq.int((which(snapshot == "bids")+2), (which( snapshot == "asks")-1), by = 2)]) )

  asks <- dplyr::tibble( rate = as.numeric(snapshot[ seq.int((which(snapshot == "asks")+1), length(snapshot) -1, by = 2)]),
                      amount = as.numeric(snapshot[ seq.int((which(snapshot == "asks")+2), length(snapshot), by = 2)] ))


  return(list(lastUpdateId = as.numeric(snapshot[2]), asks = asks, bids = bids))

  }


