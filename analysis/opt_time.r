# R scratch buffer

num.cores <- c(16, 48, 120, 26 * 16)
num.dp <- 26
time.per.dp <- c(3, 14/2, 60, 90)
orig.cores <- 16

df <- data.frame()
for (nc in num.cores) {
  for (t in time.per.dp) {
    ttl.time <- ((num.dp * t) * (orig.cores / nc))
    hrs <- floor(ttl.time / 60)
    if (hrs > 0) {
      mins <- round(ttl.time %% hrs)
    } else {
      mins <- round(ttl.time)
    }
    df <- rbind(df,
                data.frame(num.cores=nc, time.per.dp=t,
                           hrs.mins=paste(hrs,"h", mins, "m"),
                           ttl.time=ttl.time))
  }
}

df$time.per.dp <- as.factor(df$time.per.dp)
plot <- ggplot(data=df, aes(x=num.cores, y=ttl.time, col=time.per.dp)) +
  geom_line() +
  scale_y_continuous(
    name="Time (mins)",
    sec.axis=sec_axis(~./60, name="Time (hrs)")) +
  labs(x="# Cores", col=paste("Minutes per\ndata point\non", orig.cores, "cores"),
       title=paste("Optimisation time for", num.dp, "data points"))

ggsave("analysis/figures/optimisation_time.png", plot=plot)

### Includes implementation time for number of cores ###
df$ttl.time[df$num.cores > orig.cores] <- df$ttl.time[df$num.core > orig.cores] + 60
plot <- ggplot(data=df, aes(x=num.cores, y=ttl.time, col=time.per.dp)) +
  geom_line() +
  geom_hline(yintercept=60, lty=3) + 
  geom_hline(yintercept=120, lty=3) + 
  geom_hline(yintercept=180, lty=3) + 
  scale_y_continuous(
    name="Time (mins)",
    sec.axis=sec_axis(~./60, name="Time (hrs)")) +
  labs(x="# Cores", col=paste("Minutes per\ndata point\non", orig.cores, "cores"),
       title=paste("Optimisation time for", num.dp, "data points"))

print(plot)
print(df)
