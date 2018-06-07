
# install.packages("root")
library("httpuv")
library("websocket")
library("RJSONIO")
library("RCurl")
library("tidyjson")
library("rbenchmark")
library("futile.logger")
library("testthat")
library("devtools")

# https://github.com/binance-exchange/binance-official-api-docs/blob/master/web-socket-streams.md#how-to-manage-a-local-order-book-correctly

binance_logfile <- "~/Dropbox/logs/binance.log"


ws <- WebsocketClient$new("wss://stream.binance.com:9443/ws/bnbbtc@depth",
                          onOpen = function() {
                            cat("Connection opened\n")
                          },
                          onMessage = function(msg) {
                            cat("Client got msg: ", msg, "\n")
                          },
                          onClose = function() {
                            cat("Client disconnected\n")
                          })


#-----------





binance_upd_obook <- function(msg, big_orderbook) 
{
  
  msg <- binance_mess(msg)
  
  cat(paste0(msg,"\n"), file=binance_logfile, append = T)
  

  
  cat(paste0(smallasks,"\n"), file=binance_logfile, append = T)
  
  big_orderbook$lastUpdateId <- as.numeric(msg[10])
  big_orderbook$asks <- binance_upd_ab(small = smallasks, big = big_orderbook$asks)
  big_orderbook$bids <- binance_upd_ab(small = smallbids, big = big_orderbook$bids)
  big_orderbook
}


#-----------


#-----------


ws <- WebsocketClient$new("wss://stream.binance.com:9443/ws/bnbbtc@depth",
                          onOpen = function() {
                            cat("Connection opened\n")
                          },
                          onMessage = function(msg) {
                            msg <<- msg
                            pmsg <<- binance_wss_parsing(msg)
                            # if cat(error)
                          
                            
                          },
                          onClose = function() {
                            cat("Client disconnected\n")
                          })

ws$close()
base_orderbook = getURL("https://www.binance.com/api/v1/depth?symbol=BNBBTC&limit=1000")
obook2 <- binance_mess(base_orderbook)


  
  
  
  

# wss://stream.binance.com:9443/ws/bnbbtc@depth