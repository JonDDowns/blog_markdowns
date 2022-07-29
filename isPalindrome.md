## Introduction

Hello, and welcome to my code blog! I started this website as a way for
me to share my coding work publicly. It took a lot of time and messy C#
code to get here, and I could not be more excited. Now, let’s get into
palindromes! <br /> A common coding interview task is to write code that
tells you whether a given string is a palindrome. It is easy to see why:
it is a great way to showcase knowledge of regular expressions and
reshaping data. Additionally, I think it’s a great time to introduce the
idea of [testing](https://r-pkgs.org/testing-basics.html) in R. <br />
\## Testing <br /> One of my biggest pet peeves in coding is when people
use cross-tabs, print statements, and other output in the middle of
their scripts to spot check their results. Good code is consistent and
accurate. It is written in a logical fashion and tells a story. Please
stop giving me research assignments in the middle of your code! If you
feel the need to check the results at each run, that’s a good sign the
code is not ready yet. <br /> And this is where formal testing comes
into play. Take all of those spot checks you were previously doing,
automate them, and store them in a unit test. Then, if new code is
added, you can quickly re-run all of those previously written checks
again. It will change your life! <br /> In this post, we will be using
testthat to implement our unit testing.
