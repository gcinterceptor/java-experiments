require(stringr)
require(boot)

# Parses the experiment's NGINX log file.
read.accesslog <- function(f, warmup, duration) {
  # https://lincolnloop.com/blog/tracking-application-response-time-nginx/
  al <- read.csv(f, sep=";", colClasses=c("upstream_response_time"="character"))
  # request processing time in seconds with a milliseconds resolution;
  # time elapsed between the first bytes were read from the client and
  # the log write after the last bytes were sent to the client
  # http://nginx.org/en/docs/http/ngx_http_log_module.html.
  al$request_time <- al$request_time * 1000 # Making it milliseconds.

  # Filtering out first warmup seconds
  al <- al %>% arrange(timestamp)
  tsBegin <- al[1,]$timestamp + warmup
  if (duration > 0) {
    al <- al %>% filter(timestamp > tsBegin & timestamp < (tsBegin + duration))
  } else {
    al <- al %>% filter(timestamp > tsBegin)
  }
  al$timestamp <- c(0, al$timestamp[2:NROW(al)]-al$timestamp[1])
  
  #al$exp_dur_ms <- c(0, al$timestamp[2:NROW(al)]-al$timestamp[1]) * 1000
  al$hop1 <- sub(',.*$', '', al$upstream_response_time)
  al$hop1 <- as.numeric(al$hop1)*1000
  al$hop2 <- sub('^.*,', '', al$upstream_response_time)
  al$hop2 <- as.numeric(al$hop2)*1000
  al$num_hops <- str_count(al$upstream_response_time, ',')+1
  return(list(
    warm=al,
    succ=filter(al, status == 200),
    fail=filter(al, status == 503)
  ))
}

accesslog <- function(outdir, exp, n, warmup, duration) {
  fname <- paste(outdir, "/al_", exp, "_1.log", sep="")
  al <- read.accesslog(fname, warmup, duration)
  al$succ["expid"] <- 1
  al$succ["id"] <- seq(1,NROW(al$succ))
  if (n == 1) {
    return(al)
  }
  for (i in 2:n) {
    aux <- read.accesslog(paste(outdir, "/al_", exp, "_", i,".log", sep=""), warmup, duration)
    aux$succ["expid"] <- i
    aux$succ["id"] <- seq(1,NROW(aux$succ))
    al$succ <- rbind(al$succ, aux$succ)
    al$warn <- rbind(al$warn, aux$warn)
    al$fail <- rbind(al$fail, aux$fail)
  }
  return(al)
}

ci.median <- function(x) {
  wt <- wilcox.test(sample(x, RESAMPLES), conf.level=0.95, conf.int = T)
  r <- wt$conf.int
  names(r) <- c("ymin", "ymax")
  return(r)
}

p99 <- function(x) {
  return(quantile(x, 0.99))
}

p999 <- function(x) {
  return(quantile(x, 0.999))
}

p9999 <- function(x) {
  return(quantile(x, 0.9999))
}

p99999 <- function(x) {
  return(quantile(x, 0.99999))
}

ci.fun <- function(data, f) {
  ci.fun <- function(data, indices) {
    return(f(data[indices]))
  }
  b <- boot(data, ci.fun, R=5000)
  return(boot.ci(b, conf=0.95, type="perc"))
}

ci.diff.fun <- function(x, y, f) {
  # Idea from: https://www.zoology.ubc.ca/~schluter/R/resample/
  mydata <- cbind.data.frame(x, y)
  ci.fun <- function(mydata, indices) {
    xq <- f(mydata$x[indices])
    yq <- f(mydata$y[indices])
    return(xq-yq)
  }
  b <- boot(mydata, ci.fun, R=5000)
  return(boot.ci(b, conf=0.95, type="perc"))
}

ci.p <- function(x, p) {
  ci.fun <- function(data, indices) {
    return(c(quantile(data[indices], c(p)), var(data)))
  }
  b <- boot(x, ci.fun, R=5000)
  bci <- boot.ci(b)
  return(data.frame("ymin"=c(bci$basic[4]), "ymax"=c(bci$basic[5])))
}

ci.p99 <- function(x) {
  return(ci.p(x, 0.99))
}

ci.p999 <- function(x) {
  return(ci.p(x, 0.999))
}

ci.p9999 <- function(x) {
  return(ci.p(x, 0.9999))
}

ci.p99999 <- function(x) {
  return(ci.p(x, 0.99999))
}

q.plot.data <- function(df) {
  q <-  df %>% group_by(trunc(timestamp)) %>% summarize(
    q50 = quantile(request_time, 0.5),
    q90 = quantile(request_time, 0.9),
    q99 = quantile(request_time, 0.99),
    q999 = quantile(request_time, 0.999),
    q9999 = quantile(request_time, 0.9999),
    max = max(request_time))
  q <- melt(q, id="trunc(timestamp)")
  colnames(q) <- c("ts", "func", "value")
  return(q)
}

tp <- function(df){
  return(NROW(df)/(df$timestamp[NROW(df)]-df$timestamp[1]))
}

tp.improvement.perc <- function(df1, df2) {
  return(((tp(df1)-tp(df2))/tp(df1))*100)
}

sd.improvement.perc <- function(df1, df2) {
  return(((sd(df1)-sd(df2))/sd(df1))*100)
}

tail.table <- function(statelessHighHP, statfulHighHP) {
  q.nshl <- quantile(statelessHighHP, c(0.99, 0.999, 0.9999, 0.99999))
  q.shl <-  quantile(statfulHighHP, c(0.99, 0.999, 0.9999, 0.99999))
  
  t1.df <- as.table(matrix(
    c(
      q.nshl[1], q.nshl[2], q.nshl[3], q.nshl[4],
      q.shl[1], q.shl[2], q.shl[3], q.shl[4]
    ), ncol=4, byrow=T))
  
  colnames(t1.df) <- c("99%", "99.9%", "99.99%", "99.999")
  rownames(t1.df) <- c(
    "Stateless",
    "Statefull"
  )
  return(t1.df)
}
