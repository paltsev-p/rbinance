insertRow <- function(existingDF, newrow, r) {
  existingDF[seq(r+1,nrow(existingDF)+1),] <- existingDF[seq(r,nrow(existingDF)),]
  existingDF[r,] <- newrow
  existingDF
}


#' @export
binance_orderbook <- function(pair, limit, updatetime = 1)
  # orderbook example snapshot_url <- "https://www.binance.com/api/v1/depth?symbol=BNBBTC&limit=10"
  # example wsschannel_url <- "wss://stream.binance.com:9443/ws/bnbbtc@depth"
  {
  assertthat::assert_that(assertthat::is.string(pair), assertthat::is.count(limit), assertthat::is.count(updatetime))
  assertthat::assert_that(!"_" %in% unlist(strsplit(pair,"")), msg = paste0('pair variable ("', pair,'") for binance_orderbook function has _ or - character!'))
  assertthat::assert_that(!"-" %in% unlist(strsplit(pair,"")), msg = paste0('pair variable ("', pair,'") for binance_orderbook function has _ or - character!'))


  snapshot_url <-paste0("https://www.binance.com/api/v1/depth?symbol=",pair,"&limit=",limit)
  wsschannel_url <- paste0("wss://stream.binance.com:9443/ws/",pair,"@depth")

  message_buffer_name <- paste0("messages_BIN_",pair)
  assign(message_buffer_name,list(), envir = .GlobalEnv)

  obookname <- paste0("orderbook_BIN_",pair)
  assign(obookname,list(), envir = .GlobalEnv)

  lastupdated <- paste0(obookname,"_updtime")
  assign(lastupdated,double(), envir = .GlobalEnv)

  # get(obookname)
  # !!!!! global assignment
  ws <<- websocket::WebsocketClient$new(wsschannel_url,
                            onOpen = function() {
                              cat("Connection opened\n")
                              cat("Type ws$close to close\n" )
                            },
                            onMessage = function(msg)
                            {
                              cat("Client got msg: ", msg, "\n")
                              # on condition that required time elapsed since last update AND
                              # orderbook has already been loaded and parsed by binance_snapshot_parsing()
                              if (Sys.time() > get(lastupdated, envir = .GlobalEnv) + updatetime &
                                    length(get(obookname, envir = .GlobalEnv)) > 0 )
                                #
                                {
                                  # activating the orderbook and buffer. Parsing the received message to the buffer
                                  orderbook <- get(obookname, envir = .GlobalEnv)
                                  message_buffer <- get0(message_buffer_name, envir = .GlobalEnv)
                                  message <- binance_wss_parsing(msg)

                                  # checking that the message satisfies the condition Uprev+1 == u and producing warning otherwise
                                  # Reference: https://github.com/binance-exchange/binance-official-api-docs/blob/master/web-socket-streams.md#how-to-manage-a-local-order-book-correctly
                                  # Here: U - first, u - last
                                  if(length(message_buffer) > 0 & message_buffer[[length(message_buffer)]]$last + 1 != message["first"])
                                    warning(paste("Received message is out of the thread (expected U =",
                                                  message_buffer[[length(message_buffer)]]$last + 1, "received:\n", msg))

                                  # in any case, adding the received message to the buffer
                                  message_buffer[[length(message_buffer)+1]] <- message

                                  # Reference: https://github.com/binance-exchange/binance-official-api-docs/blob/master/web-socket-streams.md#how-to-manage-a-local-order-book-correctly
                                  # leaving in the buffer only the messages that can be used to update the orderbook
                                  # (U <= lastUpdateId+1 AND u >= lastUpdateId+1)
                                  # Here: U - first, u - last
                                  lastUpdateId <- orderbook[["lastUpdateId"]]

                                   startNo <-
                                    which(unlist(sapply(message_buffer, FUN = '[', FUN.VALUE = "first")) <= lastUpdateId+1 &
                                    unlist(sapply(message_buffer, FUN = '[', FUN.VALUE = "last")) >= lastUpdateId+1)

                                    # cutting the buffer to leave only the messages that could be used to update the orderbook
                                  if (length(startNo) == 0)
                                    { message_buffer_tmp <- NULL
                                    } else {message_buffer_tmp <- message_buffer[min(startNo):length(message_buffer)]}


                                  # Flushing the messages to the main orderbook with binance_update_orderbook()

                                  orderbook <- binance_update_orderbook(orderbook, message_buffer)

                                  # Updating the global orderbook + update time and clearing the buffer

                                  assign(lastupdated,Sys.time(), envir = .GlobalEnv)
                                  # leaving the processed events in the buffer so we could track the
                                  assign(message_buffer_name, message_buffer_tmp, envir = .GlobalEnv)
                                  assign(obookname, orderbook, envir = .GlobalEnv)

                                  # get(lastupdated)
                                }
                              else # otherwise just adding the message to the buffer
                                {

                                  message_buffer <- get0(message_buffer_name)

                                  # checking that the message satisfies the condition Uprev+1 == u and producing warning otherwise
                                  # Reference: https://github.com/binance-exchange/binance-official-api-docs/blob/master/web-socket-streams.md#how-to-manage-a-local-order-book-correctly
                                  # Here: U - first, u - last
                                  if(length(message_buffer) > 0 & message_buffer[[length(message_buffer)]]$last + 1 != message["first"])
                                    warning(paste("Received message is out of the thread (expected U =",
                                                  message_buffer[[length(message_buffer)]]$last + 1, "received:\n", msg))

                                  # in any case, adding the received message to the buffer
                                  message_buffer[[length(message_buffer)+1]] <- message
                                  assign(message_buffer_name, message_buffer, envir = .GlobalEnv)
                                }
                            },
                            onClose = function() {
                              cat("Client disconnected\n")
                            }
                                        ) # definition of websocket::WebsocketClient$new finished


  if ( length(get(obookname, envir = .GlobalEnv)) == 0 )
    {
      assign(obookname,binance_snapshot_parsing(RCurl::getURL(snapshot_url)), envir = .GlobalEnv)
      print(paste("Binance orderbook snapshot for pair", pair," loaded and parsed"))
    }

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


