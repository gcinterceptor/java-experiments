#http://ggplot2.tidyverse.org/reference/#section-scales

library("ggplot2")
library("dplyr")

i1 <- read.csv("results/control/1i/sim_lb_gci_1.csv")
i2 <- read.csv("results/control/2i/sim_lb_gci_1.csv")
i4 <- read.csv("results/control/4i/sim_lb_gci_1.csv")

i1 <-subset(i1, i1[5] == "True") %>% select(latency)
i2 <-subset(i2, i2[5] == "True") %>% select(latency)
i4 <-subset(i4, i4[5] == "True") %>% select(latency)

i1 <- head(i1, 7000)
i2 <- head(i2, 7000)
i4 <- head(i4, 7000)

i <- data.frame(i1=i1[1], i2=i2[1], i4=i4[1])
boxplot(i)


