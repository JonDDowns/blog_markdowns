## **Introduction**

Hello, and welcome to my code blog! I started this website as a way for
me to share my coding work publicly. It took a lot of time and messy C#
code to get here, and I could not be more excited. Now, let’s get into
palindromes!

<br />

A common coding interview task is to write code that tells you whether a
given string is a palindrome. It is easy to see why: it is a great way
to showcase knowledge of regular expressions and reshaping data.
Additionally, I think it’s a great time to introduce the idea of
[testing](https://r-pkgs.org/testing-basics.html) in R.

<br />

## **Testing**

One of my biggest pet peeves in coding is when people use cross-tabs,
print statements, and other output in the middle of their scripts to
spot check their results. Good code is consistent and accurate. It is
written in a logical fashion and tells a story. Please stop giving me
research assignments in the middle of your code! If you feel the need to
check the results at each run, that’s a good sign the code is not ready
yet. This is where formal testing comes into play. Take those spot
checks you were previously doing, automate them, and store them in a
unit test. Then, if new code is added, you can quickly re-run all of
those checks again. It will change your life! In this post, we will be
using [testthat](https://testthat.r-lib.org/) to implement our unit
testing. testthat is mostly built for package development, but now is a
good time to introduce it. Plus, it has some features built in to make
unit testing a little more fun.

<br />

## **Palindromes: Setting up tests**

Next, let’s set up our test cases. According to [the examples at
palindromelist.net](http://www.palindromelist.net/), punctuation and
capitalization should be disregarded for the purposes of identifying
palindromes. Let’s use a sample of entries to test our palindrome
function. Typically, in package development, you would store all of your
tests in the `mypackage/tests/testthat` directory. For the purposes of
this blog, we will place all of our unit tests in a single `run_tests()`
function. This is for convenience and to allow testing and function
writing to happen in a single script.

<br />

``` r
# Load libraries
library(testthat)

# Start with writing unit tests!
run_tests <- function(myfun) {
  # These should all return TRUE
  test_that('Works on real palindromes', {
  palindromes <- c('kayak', 'deified', 'rotator', 'repaper', 'deed', 'peep', 
                   'wow', 'noon', 'civic', 'racecar', 'level', 'mom', 
                   'bird rib', 'taco cat', 'UFO tofu', 'Borrow or rob?', 
                   'Never odd or even.', 'We panic in a pew.', 
                   'Won’t lovers revolt now?',  
                   'Ma is a nun, as I am.', 'Don’t nod.', 
                   'Sir, I demand, I am a maid named Iris.', 
                   'Was it a car or a cat I saw?', 'Yo, Banana Boy!', 
                   'Eva, can I see bees in a cave?', 
                   'Madam, in Eden, I’m Adam.', 
                   'A man, a plan, a canal, Panama!', 
                   'Never a foot too far, even.',
                   'Red roses run no risk, sir, on Nurse’s order.', 
                   'He lived as a devil, eh?', 'Ned, I am a maiden.', 
                   'Now, sir, a war is won!', 'Evade me, Dave!', 
                   'Dennis and Edna sinned.', 'Step on no pets!')
  funx <- myfun
    expect_equal(funx(palindromes), rep(TRUE, length(palindromes)))
  })
  
  # Ensure it returns False when it should
  test_that('Works on non-palindromes', {
    antipalindromes <- c('cat', 'dog', 'Mustard')
    expect_equal(is_palindrome(antipalindromes), rep(FALSE, length(antipalindromes)))
  })
  
  # Make sure error is thrown if non-character used
  test_that('Error if not character', {
    expect_error(is_palindrome(12))
    expect_error(is_palindrome(NULL))
    expect_error(is_palindrome(FALSE))
    expect_error(is_palindrome(Sys.Date()))
  })
}
```
