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
list.files(".")

# ".." is the PARENT of the working directory
list.files("..")

# "~" is the HOME directory
list.files("~")
list.files("~", pattern = "^Do*") # Use regex to search

##################################################################
# Working with databases
##################################################################
# Connect to database
# Need a driver, server, username, and password
# database is optional
cnxn <- DBI::dbConnect(
    drv = odbc::odbc(),
    Driver = "{ODBC Driver 18 for SQL Server}",
    server = "jondowns.database.windows.net,1433",
    database = "adventureworks",
    uid = "readAdvWorks",
    pwd = "Plznohackme!123") # Please don't do this

# Query database
cust <- DBI::dbGetQuery(cnxn, "SELECT * FROM SalesLt.Customer")
custAdd <- DBI::dbGetQuery(cnxn, "SELECT * FROM SalesLt.CustomerAddress")

# Add parameters to your queries!
# use glue SQL- useful helpers that are language specific
qryWithParams <- glue::glue_sql(
    .con = cnxn,
    "SELECT TABLE_NAME, COLUMN_NAME
    FROM INFORMATION_SCHEMA.COLUMNS 
    WHERE TABLE_SCHEMA = {scheme}",
    scheme = "SalesLt")
DBI::dbGetQuery(cnxn, qryWithParams)

# My preference: read SQL queries from file
qry <- readr::read_file("qry.sql") %>%
    DBI::dbGetQuery(con = cnxn)

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

# Preview data using head()
head(cust)

# For dataframes and matrices, use Object[row, column]
cust[1, ] # First row
cust[, 4] # Fourth column
cust[1:5, 4] # Fourth column for first 5 rows

##################################################################
# Manipulate data
##################################################################
# "Base R" (R + packages that don't have to be installed)
# works great for people who have coding background
keepCols <- c("LastName", "LNAME5")
custBase <- within(
    cust,
    LNAME5 <- substring(LastName, 1, 5)
    )[, keepCols]

# For SAS converts, the tidyverse feels more familiar
# tidyverse is a universe of packages and functions with a very
# active and well-known community
# One of the key concepts in the tidyverse is the pipe "%>%" operator
# It reminds me of SAS because data are manipulated in "blocks"
custTidy <- cust %>%
    mutate(
        LNAME5 = substring(LastName, 1, 5)
    ) %>%
    select(LastName, LNAME5)

identical(custTidy, custBase)

# Another options is data.table, which I'm less of an expert on
# It looks a lot like base R, except:
# 1) it is faster
# 2) It has special operations for summarizing data/working by groups
# More in a minute


