library(ggplot2)
library(DBI)

save.plot <- function(handle, plot) {
    img.dir <- "imgs"
    file.name <- paste(img.dir, handle, sep="/")
    ggsave(paste(file.name, "png", sep="."))
    ggsave(paste(file.name, "svg", sep="."))
  }
#+end_sr

#+begin_src R :results none
  # Controls the font size for all of the plots
  plot.text.size <- 30
  plot.theme <- theme(text=element_text(size=plot.text.size), #change font size of all text
                      axis.text=element_text(size=plot.text.size), #change font size of axis text
                      axis.title=element_text(size=plot.text.size), #change font size of axis titles
                      plot.title=element_text(size=plot.text.size), #change font size of plot title
                      legend.text=element_text(size=plot.text.size), #change font size of legend text
                      legend.title=element_text(size=plot.text.size)) #change font size of legend title 
  point.size <- 5
  line.size <- 2

sv.mu <- 73.1
sv.sd <- 18.5
num.vals <- 10000

print(paste("Mean\t", sv.mu, "\nStdev\t", sv.sd, sep=""))

sv.lb.vals <- c(52.3, 47.4, 45.1, 43.6, 39.6, 39.3)
pop.size <- c(320, 258, 195, 285, 221, 171)
sv.lb.frac <- 2.5e-2

sv.lb <- sum(sv.lb.vals * pop.size) / sum(pop.size)

print(paste("Stroke volume ", sv.lb.frac * 100, "% percentile: ", sv.lb, sep=""))

num.samples <- 10000
dof.vals <- 1:100
mu.vals <- seq(sv.mu/2, sv.mu*2, 1)
num.combinations <- length(dof.vals) * length(mu.vals)
dofs <- numeric(num.combinations)
mus <- numeric(num.combinations)
means <- numeric(num.combinations)
sds <- numeric(num.combinations)
lbs <- numeric(num.combinations)

i = 1
for (mu in mu.vals){
  for (dof in dof.vals){
    d.sample <- rt(num.samples, dof, ncp=mu)
    dofs[i] <- dof
    mus[i] <- mu
    means[i] <- mean(d.sample)
    sds[i] <- sd(d.sample)
    lbs[i] <- sum(d.sample <= sv.lb) / length(d.sample)
    i <- i + 1
  }
}

error.mean <- abs(means - sv.mu) / sv.mu
error.sd <- abs(sds - sv.sd) / sv.sd
error.lb <- abs(lbs - sv.lb.frac) / sv.lb.frac

error.ttl <- error.mean + error.sd + error.lb

min.idx <- which(error.ttl == min(error.ttl))

df <- data.frame(dof=dofs, ncp=mus, mean=means, sd=sds, lb=lbs,
                 mean.err=error.mean, sd.err=error.sd, lb.err=error.lb,
                 error=error.ttl)

plot <- ggplot(data=df, aes(x=dof, y=ncp, col=error)) +
  geom_point() +
  labs(x="Degrees of Freedom", y="Non-centrality Parameter", col="Error")
save.plot("sv_error", plot)

plot <- ggplot(data=df, aes(x=dof, y=error, col=ncp)) +
  geom_point() +
  labs(x="Degrees of Freedom", col="Non-centrality Parameter", y="Error")
save.plot("sv_error_dof", plot)

plot <- ggplot(data=df, aes(x=ncp, y=error, col=dof)) +
  geom_point() +
  labs(col="Degrees of Freedom", x="Non-centrality Parameter", y="Error")
save.plot("sv_error_ncp", plot)

df.clip <- subset(df, error <= max(error) * 0.01)
plot <- ggplot(data=df.clip, aes(x=dof, y=ncp, col=error)) +
  geom_point() +
  labs(x="Degrees of Freedom", y="Non-centrality Parameter", col="Error")
save.plot("sv_error_clip", plot)

plot <- ggplot(data=df.clip, aes(x=dof, y=error, col=ncp)) +
  geom_point() +
  labs(x="Degrees of Freedom", col="Non-centrality Parameter", y="Error")
save.plot("sv_error_dof_clip", plot)

plot <- ggplot(data=df.clip, aes(x=ncp, y=error, col=dof)) +
  geom_point() +
  labs(col="Degrees of Freedom", x="Non-centrality Parameter", y="Error")
save.plot("sv_error_ncp_clip", plot)

sv.dof <- dofs[min.idx]
sv.ncp <- mus[min.idx]
print(paste("DOF\t", sv.dof, "\nNCP\t", sv.ncp, sep=""))

d <- data.frame(vals=seq(sv.mu - 3 * sv.sd, sv.mu + 3 * sv.sd, length.out=num.vals))
d$norm <- dnorm(d$vals, mean=sv.mu, sd=sv.sd)
d$nct <- dt(d$vals, sv.dof, sv.ncp)

plot.orig <- ggplot(data=d, aes(x=vals, y=norm, col="norm")) +
  geom_line() +
  geom_line(aes(y=nct, col="nct")) +
  labs(x="Stroke Volume (mL)", y="Density", col="Distribution")
save.plot("sv_comparison", plot.orig)

dbname <- file.path(getwd(), "physiological.db")
table <- "sv_rel"
con <- dbConnect(RSQLite::SQLite(), dbname=dbname)
df <- dbGetQuery(con, paste("SELECT * FROM", table))

# Formats data
df$index <- c()

df.names <- c()
for (i in seq(1, ncol(df))) {
  var <- strsplit(names(df)[i], ".", fixed=TRUE)[[1]]
  print(var)
  print(var[length(var)])
  print("---")
  df.names[i] <- var[length(var)]
}
names(df) <- df.names

df$sex <- as.factor(df$sex)

summary(df)

num.vals <- nrow(df)

d.comparison <- data.frame(norm=rnorm(num.vals, sv.mu, sv.sd),
                nct=rt(num.vals, sv.dof, sv.ncp),
                sim=df$sv)

plot <- ggplot(data=d.comparison, aes(x=sim)) +
  geom_histogram(alpha=0.5, aes(y=..density.., fill='0D simulation')) +
  geom_histogram(alpha=0.5, aes(y=..density.., x=nct, fill='Non-central t')) +
  geom_histogram(alpha=0.5, aes(y=..density.., x=norm, fill='Normal')) +
  geom_density(show.legend=FALSE, alpha=0, aes(col='0D simulation')) +
  geom_density(show.legend=FALSE, alpha=0, aes(x=nct, col='Non-central t')) +
  geom_density(show.legend=FALSE, alpha=0, aes(x=norm, col='Normal')) +
  labs(x="Stroke Volume (mL)", y="Density", fill="Distribution")

save.plot("sv_comparison_w_simulation", plot)

print(paste("Data has", num.vals, "rows"))
