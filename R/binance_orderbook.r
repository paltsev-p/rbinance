


#' @export
binance_orderbook <- function(snapshot_url, wsschannel_url)
  # orderbook example snapshot_url <- "https://www.binance.com/api/v1/depth?symbol=BNBBTC&limit=10"
  # example wsschannel_url <- "wss://stream.binance.com:9443/ws/bnbbtc@depth"
  {
  ws <- websocket::WebsocketClient$new(wsschannel_url,
                            onOpen = function() {
                              cat("Connection opened\n")
                              cat("Type ws$close to close\n" )
                            },
                            onMessage = function(msg) {
                              cat("Client got msg: ", msg, "\n")
                            },
                            onClose = function() {
                              cat("Client disconnected\n")
                            }
      )

  binance_snapshot_parsing(RCurl::getURL(snapshot_url))

  }

insertRow <- function(existingDF, newrow, r) {
  existingDF[seq(r+1,nrow(existingDF)+1),] <- existingDF[seq(r,nrow(existingDF)),]
  existingDF[r,] <- newrow
  existingDF
}


binance_update_orderbook <- function(small, big)
  {

  assertthat::assert_that(small$type == "depthUpdate")
  assertthat::assert_that(!any(!(c("type", "time", "pair", "first", "last", "asks", "bids") %in% names(small)) ),
                          msg = "Not all expected elements are contained in last input to binance_update_orderbook(small = ...)
                          type, time, pair, first, last, asks, bids")

  assertthat::assert_that(!any(!(c("lastUpdateId", "asks", "bids")  %in% names(big)) ),
                        msg = "Not all expected elements are contained in last input to binance_update_orderbook(big = ...):
                        lastUpdateId, asks, bids")

    if (nrow(small) > 0)
    {
      for (x in 1:length(small$rate))
      {
        if ( ! (small$amount[x] == 0 & !(small$rate[x] %in% big$rate) ) )
          # ничего не делаем (закомменченная ветка else) если ( новый amount ==0  и такого значения в большом датасете нет )
        {
          # иначе: удаляем строчку если новый amount ==0
          if (small$amount[x] == 0) big <- big[-which(big$rate == small$rate[x]),]
          # заменяем amount новым значением amount
          else if (small$rate[x] %in% big$rate) big$amount[which(big$rate == small$rate[x])] <- small$amount[x]
          # вставляем новую строчку если значение rate ещё нет
          # https://stackoverflow.com/a/11562428/9736648
          else big <- insertRow(big, small[x,],  ifelse( small$rate[x] > max(big$rate), length(big$rate)+1, which.max(big$rate > small$rate[x]) )  )
        }
        # else big <- big
      }
    }
    return(big)
  }

  }
