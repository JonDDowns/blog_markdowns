##################################################################
# Package/module management
##################################################################
# Modules = Python packages
# Installing packages - use PIP or anaconda (demo of pip)

# Any modules need to be explicitly loaded
import sqlalchemy as sa
import pandas as pd # Note the "pd" ref here
import os
import re
import glob

# You can also import specific subsets of a package
from urllib import request

# Using functions from a package -------------------
# must reference the import specifically for new functions

# Doesn't work because the package reference is required
DataFrame({"mycol": range(0,9)}).head()

# Call DataFrame function from pandas
pd.DataFrame({"mycol": range(0,9)})

# This is on purpose-- Python prides it self on readable, well-
# specified code. Part of this means enforcing formatting.
# Another effect of this is that there is typically a single

##################################################################
# Get help!
##################################################################
help(pd) # Package-wide help
help(pd.DataFrame) # Documentation for a specific function

##################################################################
# Explore your file systems
##################################################################
# Some notation common across R and Python (and, really, coding in general)
# "." is the working directory

# Note that, if you do not assign an object, it is printed (not saved)
os.listdir(".")
os.listdir("..")
myFiles = os.listdir(".")

# Use glob to do string searches on a path with regex
glob.glob("./*.py")

# Access environment variables
os.getenv("PATH")

##################################################################
# Working with databases
##################################################################
### IMPORTANT!!! FIRST EXAMPLE IS NOT SECURE

# Connect using connection string
# Get database address from environment variable
dbAddress = os.getenv("dbAddress")
connection_string = "mssql+pyodbc://readAdvWorks:Plznohackme!123@%s/adventureworks?driver=ODBC+Driver+17+for+SQL+Server" % (dbAddress)
cnxn = sa.create_engine(connection_string)

# PLEASE!!!
# Consider keyring, etc. etc. to store secrets once it is working

# For most DOH work, you should really be using ODBC
# It will connect you while putting the server name behind a password-prompt
cnxn = sa.create_engine("mssql://?dsn=dqss")

# Reference a specific schema
pd.read_sql(    
    """
    SELECT *
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'Customer' """, cnxn)
   
# Query database
cust = pd.read_sql("SELECT * FROM SalesLt.Customer", cnxn)
custAdd = pd.read_sql(
    """
    SELECT a.CustomerID
    , a.AddressType
    , b.AddressLine1
    , b.AddressLine2
    , b.City
    , b.StateProvince
    , b.CountryRegion
    , b.PostalCode
    , b.ModifiedDate
    FROM SalesLt.CustomerAddress AS a
    LEFT JOIN SalesLT.Address AS b ON a.AddressID = b.AddressID
    """, cnxn)

##################################################################
# Explore and subset data
##################################################################
# Use dim, nrow, and ncol to get rows/columns, and both
cust.shape # Rows x columns
cust.shape[0] # I will never get used to the first index being 0
cust.shape[1]

# Note the syntax-- this DOES NOT work
# shape(cust)

# Shape is an *attribute* of the dataframe: it is explicitly associated
# with an object of the dataframe type. In R, there is a basic "head"
# function, where objects of certain types may have their own method.
# In theory, both languages can do the same thing as the other here,
# but 1) the syntax is different 2) attributes are much more 
# visible to users in Python

# Print out row and column names
cust.columns
cust.index

# Subset data- use brackets!
# For lists, object[1] would select the first object
cust.columns[0]

# Pick the columns you want to keep/reorder columns
keepCols = ["CustomerID", "FirstName", "LastName",
    "CompanyName", "SalesPerson", "Phone",
    "EmailAddress"]
cust2 = cust[keepCols]

# Preview data using head()
cust2.head()

# Search by row index
cust2.iloc[0]

# Search rows by condition
# Note how the nested attributes allow for "chaining"
cust2[cust2["LastName"].str.startswith("D")] # If logic is supplied, pd filters by row
type(cust2["LastName"])

# Columns are typically subsetted by strings (or lists or strings)
cust2[cust2.columns[4]] # Fourth column
cust2["SalesPerson"]

# Subset by both rows and columns-- use pd.DataFrame.loc()
cust2.loc[cust2["LastName"].str.startswith("D"), "SalesPerson"]

##################################################################
# Manipulate data
##################################################################
# Syntax is similar to base r here
custBase = cust2
custBase["LNAME5"] = custBase["LastName"].str.slice(0, 5)
custBase.head

########################################################
# Regular expressions/text manipulation
########################################################
# Again, the Series.str.[ATTR] family works best for DFs

# Gets T/F
custBase["LastName"].str.contains("^Do").value_counts()

# Return only thep patterns that were matches
custBase["LastName"].str.extract("(^Do[a-d]?)").dropna()

# Re is the go-to for non-dataframe operations
myStr = "HEY LOOK A STRING"
re.findall("(HEY LOOK) (A STRING)", myStr)[0][0]

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
