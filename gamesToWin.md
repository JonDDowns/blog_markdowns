## **Determining the probability that a series goes ‘all the way’**

<br />

I am currently working through the great [Ace the Data Science
Interview](https://www.amazon.com/Ace-Data-Science-Interview-Questions/dp/0578973839/ref=asc_df_0578973839/?tag=hyprod-20&linkCode=df0&hvadid=532387267820&hvpos=&hvnetw=g&hvrand=13153489800728978484&hvpone=&hvptwo=&hvqmt=&hvdev=c&hvdvcmdl=&hvlocint=&hvlocphy=9033498&hvtargid=pla-1408441908462&psc=1)
book by Kevin Huo and Nick Singh. So far, I’ve really enjoyed the
practical advice and the comprehensive list of questions to help prepare
for data science interview. I am now working on the coding interview
questions from the book, and the very first one inspired me to get R
running and do some simulations! I will also introduce an R Shiny
[interactive graph](https://jon-downs.shinyapps.io/bestofsim/) for you
to explore!

<br />

The following problem was presented in their probability chapter:

<br />

> Two teams play a series of games (best of 7 – whoever wins 4 games
> first) in which each team has a 50% chance of winning any given round
> (no draws allowed). What is the probability that the series goes to 7
> games?

<br />

I want to extend this past the 7-game use case and solve the general
case of the probability that a series of an arbitrary number of games
goes to the maximum number of games possible. We will compare
simulation-based and a theory-based approaches. Since any series with an
even number of games opens up the possibility of an additional
tie-breaker game, I will focus on series with an odd number of games.

<br />

## **Simulation**

<br />

### *Simulating a single series*

<br />

First, we write a function to simulate a single round. Let’s allow the
player to toggle the chance of winning, with a default of 50%. To win a
series, a team will need to win at least half of the games. And we will
output the number of games in the series, the total games actually
played, the number of wins, and the number of losses.

<br />

``` r
# Simulate a series with a specified number of games
simSeries <- function(nGames, pwin = 0.5){
  if(nGames %% 2 == 0){
    stop("Please enter an odd integer")
  }
  # Start with no wins/losses
  win <- 0
  loss <- 0
  
  # Determine the number of games needed to win the series
  nToWin <- floor(nGames/2 + 1)
 
  # Simulate each game until one side reaches target win count
  while(win < nToWin & loss < nToWin){
    if(sample(x = c(TRUE, FALSE), size = 1, prob = c(pwin, 1-pwin))){
      win <- win + 1
    } else{
      loss <- loss + 1
    }
  }
  
  # Return the game stats
  out <- data.frame(bestOf = nGames, gamesPlayed = win + loss, wins = win, losses = loss)
  return(out)
}

# Test out our single series simulation function
simSeries(nGames = 7, pwin = 0.5)
```

    ##   bestOf gamesPlayed wins losses
    ## 1      7           7    3      4

``` r
# Make sure series with even-numbered games throw an error
try(simSeries(nGames = 6, pwin = 0.5))
```

    ## Error in simSeries(nGames = 6, pwin = 0.5) : Please enter an odd integer

<br />

### *Simulating multiple series*

<br />

Looks like the function is working well, and not allowing even-numbered
series. Great! But, a single simulation is not nearly as informative as
many simulations. Let’s write a new function to simulate multiple series
of a given number of games at once, then we can look at some
distribution plots of the total number of games played in each
simulation. We will default to 1,000 simulations with a 50% probability
of winning each game.

<br />

``` r
# Simulate multiple series for a single number of games
simMulti <- function(nGames, nSims = 1000, pwin = 0.5){
  do.call(rbind, lapply(rep(nGames, nSims), simSeries))
}

# Simulate 1000 series, get frequency plot of the number of games plays
library(ggplot2)
ggplot(data = simMulti(7), aes(x = gamesPlayed)) + 
  geom_histogram() + 
  theme_bw() +
  xlab("Number of games played in series") +
  ylab("Number of simulations with outcome") +
  ggtitle("Histogram of number of games played in 1,000 simulations",
          subtitle = "7-game series, 50% chance of winning each game")
```

    ## `stat_bin()` using `bins = 30`. Pick better value with `binwidth`.

![](gamesToWin_files/figure-commonmark/unnamed-chunk-2-1.png)<!-- -->

<br />

You can make your own version of this chart using the [interactive
graph](https://jon-downs.shinyapps.io/bestofsim/) I made!

<br />

## **How does our simulation stack up to the theory?**

<br />

In this case, we could have calculated the probability using very few
lines of R code. So let’s briefly introduce the theory-based answer and
see how our simulations stack up. The probability function we are
looking for here in the [PMF of the binomial
distribution](https://en.wikipedia.org/wiki/Binomial_distribution). But
what arguments should we use to figure out the probability of a series
going all the way? There are a few different ways to come up with the
inputs, but the one that is most intuitive to me is this:

<br />

> If neither team has won the series before the last game, then the
> series is guaranteed to go all the way. Thus, we need the probability
> that n - 1 games have been played with both teams 1 game away from
> winning.

<br />

So, if we know the threshold of wins required to win the series and the
maximum number of games possible, then we can subtract one from each and
get the probability mass function at that value. Or, in R code:

<br />

``` r
# Using the PMF 
allGamesProb <- function(nGames, pwin = 0.5){
  x <- floor(nGames/2 + 1)
  dbinom(x - 1, nGames - 1, pwin)
}
```

<br />

To close this blog out, let’s compare our theory-based estimate to our
simulations. Let’s simulate 1,000 rounds for series of 7, 9, …19 games
and look at the percent of simulations that went the full number of
games. We will compare this to the calculated probability of such events
using the binomial distribution.

<br />

``` r
# Function to get the percent of games that went 'all the way' for a given
# number of games in series/simulations
simSummary <- function(nGames, nSims = 1000, pwin = 0.5){
  df <- simMulti(nGames, nSims, pwin)
  return(data.frame(nGames, nSims, pwin, pAllTheWay = sum(df$games == nGames)/nrow(df)))
}

# Run 1,000 simulations for series lengths 7-20
sims <- do.call(rbind, lapply(seq(7, 19, by = 2), simSummary))

# Get the theory-based estimate of the probability
sims$calc <- allGamesProb(sims$nGames)

# Compare theory (red line) to simulations (black line)
ggplot(sims, aes(x = nGames, y = pAllTheWay)) +
  geom_line() +
  geom_line(aes(y = calc), color = 'red') +
  theme_minimal() +
  ggtitle("Calculated versus simulated chances of going to the max number of games",
          subtitle = "by series length") +
  xlab("Number of games played") + ylab("Frequency")
```

![]("https://raw.githubusercontent.com/DOH-jpd2303/blog_markdowns/main/gamesToWin_files/figure-commonmark/unnamed-chunk-4-1.png")

<br />

Statistics to the rescue! Looks like the theory hold up well in this
case, but it is nice to know that we created a simulation that achieves
similar results.

<br />

How could I have done this better? Let me know at
[jon.d.downs@outlook.com](jon.d.downs@outlook.com).
