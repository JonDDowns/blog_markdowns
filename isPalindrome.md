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

Next, let’s set up our test cases. Some Googling brought me to
[palindromelist.net](http://www.palindromelist.net/). I noticed that
punctuation and capitalization are disregarded in these lists. For this
blog, I will assume that only the letters of the alphabet matter in
determining whether or not a word is a palindrome. Let’s use a sample of
entries from the website to test our palindrome function. We also want
to make sure the function correctly identifies words that are NOT
palindromes, so let’s add in a test for words that should return FALSE.
Finally, if the supplied value is not a character vector, an error
should be returned.

<br />

``` r
library(testthat)

# Start with writing unit tests!
run_tests <- function(myfun) {
  # These should all return TRUE
  test_that('Works on real palindromes', { # If a test fails, this prints
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
                     'Dennis and Edna sinned.', 'Step on no pets!', 'ää')
    funx <- myfun
    expect_equal(myfun(palindromes), rep(TRUE, length(palindromes)))
  })
  
  # Ensure it returns False when it should
  test_that('Works on non-palindromes', {
    antipalindromes <- c('cat', 'dog', 'Mustard', '', character(0))
    expect_equal(myfun(antipalindromes), rep(FALSE, length(antipalindromes)))
  })
  
  # Make sure error is thrown if non-character used
  test_that('Error if not character', {
    expect_error(myfun(12))
    expect_error(myfun(NULL))
    expect_error(myfun(FALSE))
    expect_error(myfun(Sys.Date()))
  })
}
```

<br />

Note the function names that read like English. It’s one of the many
nice things about the testthat package. Typically, in package
development, you would store all of your tests in the
`mypackage/tests/testthat` directory. Above, we placed all unit tests in
a single `run_tests()` function. This is for convenience and to allow
testing and function writing to happen in a single script.

<br />

Before we move on to writing a function, let’s take a step back and
think about all of the benefits of writing these tests. The simple act
of gathering some test cases made us think about the things that make
this ‘easy’ task hard: capitalization, spaces, punctuation, and empty
strings to name a few. I will confess, my first version of this function
would have failed on the of the 4 pitfalls I just mentioned. I’m glad I
finally took the time to step back and write good tests!

## **Function is_palindrome**

<br />

``` r
# Write a function to determine whether a particular word is a palindrome
is_palindrome <- function(word){
  # Check that a character input was provided
  if(!is.character(word)){
    stop('That is not valid input. Please try again.')
  }
  
  # Strip out non-alpha characters, convert to lower case, check equivalency
  newword <- tolower(gsub('\\W', '', word))
  rev_words <- do.call(c, 
                       lapply(newword, 
                              function(x) {
                                paste(rev(strsplit(x, NULL)[[1]]), 
                                      collapse = '')
                                }
                              ))
  out <- tolower(newword) == tolower(rev_words)
  out[which(newword == '')] <- FALSE
  return(out)
}


# Try it out on a few samples
is_palindrome(c('Jon', 'apple', 'sos'))
```

    ## [1] FALSE FALSE  TRUE

``` r
# And run our comprehensive testing function from above!
run_tests(is_palindrome)
```

    ## Test passed 😀
    ## Test passed 🥇
    ## Test passed 😸

<br />

And there you have it! A vectorized, flexible function to identify
palindromes, all ready to go. Well, almost…we forgot about characters
not in the English alphabet! I won’t pretend to know any foreign
languages (I’m barely literate in English and R), but it would at least
be nice for it to work in other languages in theory. Perhaps a new test
might look something like:

<br />

``` r
# A lazy example, I will admit
library(waldo) # For foreign characters
test_that('Non-english characters are okay',
          expect_true(is_palindrome('ää')))
```

    ## Test passed 😀

<br />

What else am I forgetting?! Let me know! Email <jon.d.downs@outlook.com>
with your ideas!
