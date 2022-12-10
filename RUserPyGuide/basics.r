##################################################################
# Package/module management
##################################################################
# Installing packages
# install.packages("RColorBrewer")

# R is more 'functional': most operations happen via a function
# More on how Python is different later

# As long as an R package is installed, you can access its functions
# like this:
RColorBrewer::display.brewer.all()

# Alternatively, you can load the package to avoid using
# package::function() notation
library(RColorBrewer)
display.brewer.all()
# This is typically convention, though there are cases
# where it is good to be specific

# Now, let's load the packages we use for the rest of the code demo
library(odbc)
library(DBI)
library(tidyverse)

##################################################################
# Get help!
##################################################################
?mutate # Documentation for a specific function
browseVignettes("DBI") # Long form, tutorial-style documentation

##################################################################
# Explore your file systems
##################################################################
# Some notation common across R and Python (and, really, coding in general)
# "." is the working directory

# Note that, if you do not assign an object, it is printed (not saved)
list.files(".")
myFiles <- list.files(".")

# ".." is the PARENT of the working directory
list.files("..")

# "~" is the HOME directory
list.files("~")
list.files("~", pattern = "^Do*") # Use regex to search

# Get environmental variables using Sys.getenv()
Sys.getenv("HOME")

##################################################################
# Working with databases
##################################################################
# Connect to database
# Need a driver, server, username, and password
# database is optional
cnxn <- DBI::dbConnect(
    drv = odbc::odbc(),
    Driver = "{ODBC Driver 18 for SQL Server}",
    server = Sys.getenv("dbAddress"),
    database = "adventureworks",
    uid = "readAdvWorks",
    pwd = "Plznohackme!123") # Please don't do this

# List tables in a schema
dbListTables(cnxn, schema_name = "SalesLT")

# Query database
cust <- DBI::dbGetQuery(cnxn, "SELECT * FROM SalesLt.Customer")
custAdd <- DBI::dbGetQuery(
    cnxn,
    "SELECT a.CustomerID
    , a.AddressType
    , b.AddressLine1
    , b.AddressLine2
    , b.City
    , b.StateProvince
    , b.CountryRegion
    , b.PostalCode
    , b.ModifiedDate
    FROM SalesLt.CustomerAddress AS a
    LEFT JOIN SalesLT.Address AS b ON a.AddressID = b.AddressID")

##################################################################
# Explore and subset data
##################################################################
# Use dim, nrow, and ncol to get rows/columns, and both
dim(cust) # Rows x columns
nrow(cust) == dim(cust)[1] # Number of rows (equivalent to dim[1])
ncol(cust) == dim(cust)[2] # Number of columns (equivalent to dim[2])

# Print out row and column names
colnames(cust) # Most common
rownames(cust) # Less common

# Subset data- use brackets!
# For lists, object[1] would select the first object
colnames(cust)[1]

# Pick the columns you want to keep/reorder columns
keepCols <- c(
    "CustomerID", "FirstName", "LastName",
    "CompanyName", "SalesPerson", "Phone",
    "EmailAddress")
cust2 <- cust[, keepCols]

# Preview data using head()
head(cust2)

# For dataframes and matrices, use Object[row, column]
cust2[1, ] # First row
cust2[, 4] # Fourth column
cust2[1:5, 4] # Fourth column for first 5 rows

##################################################################
# Manipulate data (base and tidy)
##################################################################
# "Base R" (R + packages that don't have to be installed)
# works great for people who have coding background
custBase <- within(
    cust2,
    LNAME5 <- substring(LastName, 1, 5)
    )
head(custBase)

# For SAS converts, the tidyverse feels more familiar
# tidyverse is a universe of packages and functions with a very
# active and well-known community
# One of the key concepts in the tidyverse is the pipe "%>%" operator
# It reminds me of SAS because data are manipulated in "blocks"
custTidy <- cust2 %>%
    mutate(
        LNAME5 = substring(LastName, 1, 5)
    ) 
identical(custTidy, custBase)

# Another options is data.table, which I'm less of an expert on
# It looks a lot like base R, except:
# 1) it is faster
# 2) It has special operations for summarizing data/working by groups

########################################################
# Regular expressions/text manipulation
########################################################
# Search for strings containing pattern
grep("^Do", cust$LastName) # Returns index (row numbers)
grep("^Do", cust$LastName, value = TRUE) # Returns full string

# Get the part of the string that matched only
strIdxs <- regexpr("^Do", cust$LastName) # Index of match

# Frequency table
table(
    substring(cust$LastName, strIdxs,
    attr(strIdxs, "match.length"))
)

########################################################
# Joining data
########################################################
# Inner/left/right/full joins using tidyverse
# Remember: %>% passes the object as first arg to next fxn
left_join(cust2, custAdd, by = "CustomerID") %>% head
anti_join(cust2, custAdd) %>% length()
anti_join(custAdd, cust2) %>% length()

# Now, let's actually save the records that are in both
custNameAdd <- inner_join(cust2, custAdd)
head(custNameAdd)

########################################################
# Grouping and summarizing data
########################################################
# Let's get the count of addresses for each customer
custNameAdd %>% count(CustomerID, sort = TRUE) %>% head(10)

# Pull all data for any customers with 2+ addresses
custNameAdd %>%
    count(CustomerID) %>%
    filter(n > 1) %>%
    left_join(custNameAdd) %>%
    head(10)

# Number of customers by salesperson
custNameAdd %>%
    group_by(SalesPerson) %>%
    summarize(nCust = n_distinct(CustomerID)) %>%
    arrange(nCust)
