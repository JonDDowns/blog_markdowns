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
                     'Dennis and Edna sinned.', 'Step on no pets!', 'ää')
    funx <- myfun
    expect_equal(myfun(palindromes), rep(TRUE, length(palindromes)))
  })
  
  # Ensure it returns False when it should
  test_that('Works on non-palindromes', {
    antipalindromes <- c('cat', 'dog', 'Mustard', '', character(0))
    expect_equal(is_palindrome(antipalindromes), rep(FALSE, length(antipalindromes)))
  })
  
  # Make sure error is thrown if non-character used
  test_that('Error if not character', {
    expect_error(myfun(12))
    expect_error(myfun(NULL))
    expect_error(myfun(FALSE))
    expect_error(myfun(Sys.Date()))
  })
}


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


run_tests(is_palindrome)


