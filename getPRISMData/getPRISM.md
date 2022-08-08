## **How to get a year of daily census tract level temperature data in 122 lines of R code.**
<br />

### **Introduction**

<br />

For a recent project, I was interested in temperature-level data at the
census tract level. I came across [the PRISM Climate
Group](https://prism.oregonstate.edu/) at Oregon State. I needed data in
tabular format, but their data are in raster format. I wrote a simple
yet powerful R script that downloads a year’s worth of daily temperature
data and converts them to CSV files with tract-level weather data for
the state of Washington. This article will walk through how to:

<br />

1.  Download multiple .zip files
2.  Unzip multiple .zip files
3.  Use parallel processing in R
4.  Convert raster data into CSV

<br />

And, at the end, I will provide a link to an R script on GitHub that you
can use to make your own!

<br />

### **Getting set up**

<br />

First, I encourage you to click on that link above and read a bit about
[the PRISM Climate Group](https://prism.oregonstate.edu/), perhaps even
their [citizen science
program](https://prism.oregonstate.edu/participate/). Eventually, you
might find your way to their [FTP
site](https://ftp.prism.oregonstate.edu/daily/). That is what we are
interested in today. Before we download the data though, let’s get our R
session set up properly:

<br />

``` r
# Load libraries
library(jsonlite)
library(rvest)
library(raster)
library(rgdal)
library(sp)
library(tidyverse)
library(parallel)

# Set year
year <- 2011

# Set up parallel runs (save 2 cores)
nc <- detectCores() - 2
cl <- makeCluster(nc)

# Load configuration settings (using hidden environmental variable)
# TO USE: make a .JSON file a variable called dirPRISM where all this data
#         will be stored
cfig_file <- paste0(Sys.getenv('myrconfig'), 'extractPRISM.json')
config <- jsonlite::read_json(cfig_file)

# Path to where all BIL files will download (make if necessary)
bil_dir <- paste0(config$dirPRISM, 'TMAX/BIL/')
dir.create(bil_dir, recursive = TRUE)

# Create a download directory for year TMAX data (make if necessary)
download_dir <- paste0(bil_dir, year, '/')
dir.create(download_dir)

# Where our final CSV files will go
csv_dir <- paste0(config$dirPRISM, 'TMAX/CSV/', year, '/')
dir.create(csv_dir, recursive = TRUE)

tract10_fn <- paste0(config$tract10dir, "tract10.shp")
```

<br />

Let’s walk through all of that. First, we load rvest, the tidyverse, and
other libraries we will be using. Then, we set the year of data we want.
The very last step of this exercise is fairly power hungry, so we set up
parallel processing. In this example, we are saving two cores. I also
wanted to specify some directories for all of my downloads and final
files. I use a JSON config file to keep the code organized and portable.
A config file is a good place to store variables that would need to
change to run your code on another system. I also stored the path to my
config files in an environmental variable, mostly for privacy reasons.
My config file looks like this:

<br />

``` json
{
  "dirPRISM": "C:/YOUR/FILE/PATH/HERE/",
  "tract10dir":  "Z:/NONE/OF/YOUR/BUSINESS/"
}
```

<br />

Those two directories are the main directory where you want all the
PRISM data (raw and transformed) as well as the directory for your
census tract data file (more on that in a minute). From there, the
script names and creates the sub-directories needed to run the script.

<br />

### **Download data**

<br />

Next, we download a
[bil](https://www.loc.gov/preservation/digital/formats/fdd/fdd000283.shtml)
file. A bil is a type of
[raster](https://www.bu.edu/tech/support/research/training-consulting/online-tutorials/imagefiles/image101/#:~:text=A%20raster%20image%20file%20is,pixel%20should%20be%20displayed%20in.)
file. In overly simple terms, a raster file is a combination of an image
that is color-coded by some variable and a metadata file that explains
the values associated with each color. The data are stored as one raster
per day of the year and measure (maximum temperature, minimum
temperature, etc.). The below chunk of code will download all bil files
for a given year at once, so allow a few minutes for it to complete. If
downloads fail, the script is designed to re-try any files that it may
have missed on the second run. The code:

<br />

``` r
# DOWNLOAD FILES ----------------------------------------------------------
# List all of the PRISM files on an FTP site
listPRISMFiles <- function(var, year){
  var <- tolower(var)
  lnk <- glue::glue("https://ftp.prism.oregonstate.edu/daily/{var}/{year}")
  ftp_txt <- read_html(lnk)
  ftp_files <- html_attr(html_nodes(ftp_txt, 'a'), 'href')
  ftp_files <- ftp_files[grepl('PRISM', ftp_files)]
  return(list(lnk = lnk, files = ftp_files))
}

# Get TMAX files for year
files <- listPRISMFiles(var = 'tmax', year = year)

# Check for already downloaded files (we don't want to download twice)
already_downloaded <- list.files(download_dir, pattern = '.zip')
files$files <- files$files[!(files$files %in% already_downloaded)]

# Download all of the files specified
dlPRISMDaily <- function(baselnk, file, outdir){
  fn <- paste0(baselnk, '/', file)
  download.file(fn, destfile = paste0(outdir, file))
}
dlPRISMDaily(baselnk = files$lnk, file = files$files, outdir = download_dir)
```

<br />

We start by writing a function, `listPRISMfiles`. We are interested in
the PRISM varaible TMAX, or max temperature. We also provide the year.
These are used to populate the correct path to the resource on the FTP
website. The function will then search for all links on the page, and
pull the reference. It will keep any references that contain the string
‘PRISM’, because that is a common pattern among the .bil files. The
function will return the base name of the hyperlink for all of the files
and a list of files available at the base link. After we write the
function, we run it and store it’s results in the ‘files’ variable.
These are the files we might want to download. To avoid re-downloading
old data, a second step removes any files names already in our downloads
folder. If there are no new files, the script will throw a soft warning
about a non-zero exit status.

<br />

### **Download some data!**

<br />

Next, we unzip the new data. We start by finding files with the .zip
pattern in our download folder. Similar to above, we also remove any
files that have previously been unzipped before we start. A quick helper
function is used to make the output directory name the same as the
zipped folder (minus the .zip).

``` r
# UNZIP FILES -------------------------------------------------------------
# Identify all of the .zip files in the directory we just created
unzip_fns <- list.files(download_dir, pattern = ".zip")

# Identify already-unzipped versions of these files, remove from list
already_unzipped <- basename(list.dirs(download_dir))
unzip_fns <- unzip_fns[!(gsub('.zip', '', unzip_fns) %in% already_unzipped)]

# Unzip the files that need it
lapply(unzip_fns, function(x) 
  unzip(paste0(download_dir, x), 
        exdir = paste0(download_dir, '/', gsub(".zip", '', x))))
```

<br />

### **Explore the data!**

<br />

Okay, we have some data! Now, let’s read it in and take a peek.

<br />

``` r
# Identify the first .bil file
myBilFile <- list.files(download_dir, pattern = '.bil$', recursive = TRUE)[1]
myRast <- raster::raster(paste0(download_dir, myBilFile)[[1]])
plot(myRast)
```
![](https://raw.githubusercontent.com/JonDDowns/blog_markdowns/main/getPRISMData/getPRISM_files/figure-commonmark/unnamed-chunk-4-1.png)

<br />

Voila! A color-coded heat map of max US temperatures on 1/1/2011. As
mentioned, our desired format is tabular data with maximum temperature
by the census tract level. To accomplish this, we will add a shape file
that includes census tract boundaries. Then, we can use a function to
extract the average maximum temperature value across that entire
geography, and report that as the maximum temperature for the area. Our
shapefile comes from the [Washington Office of Financial Management’s
(OFM)](https://ofm.wa.gov/washington-data-research/population-demographics/gis-data/census-geographic-files)
shape files for Washington State. Download those files, unzip them, and
point to them with the ‘tract10dir’ variable in your configuration file.
Next, we look at the shape file and raster image on the same plot. This
requires them to be in the same projection:

<br />

``` r
# Read in shapefile, convert to new CRS
waCensus10 <- readOGR(tract10_fn)
```

    ## Warning in OGRSpatialRef(dsn, layer, morphFromESRI = morphFromESRI, dumpSRS = dumpSRS, : Discarded datum NAD83_High_Accuracy_Reference_Network
    ## in Proj4 definition: +proj=lcc +lat_0=45.3333333333333 +lon_0=-120.5 +lat_1=45.8333333333333 +lat_2=47.3333333333333 +x_0=500000 +y_0=0
    ## +ellps=GRS80 +units=us-ft +no_defs

    ## OGR data source with driver: ESRI Shapefile 
    ## Source: "D:\PRISM\tract10\tract10.shp", layer: "tract10"
    ## with 1458 features
    ## It has 34 fields
    ## Integer64 fields read as strings:  ALANDM AWATERM

``` r
shp_reproj <- sp::spTransform(waCensus10, crs(myRast))

# Plot raster and overlay shapefile
plot(myRast)
plot(shp_reproj, bg = 'transparent', add = TRUE)
```

![](https://raw.githubusercontent.com/JonDDowns/blog_markdowns/main/getPRISMData/getPRISM_files/figure-commonmark/unnamed-chunk-5-1.png)

<br />

The scale appears to be correct, but there is one problem: the area
covered by the raster (background image) is much larger than our census
tract borders. Having extra raster data would slow down a future step in
our process, so we will use the crop function to take a Washington-sized
slice of the raster file.

<br />

``` r
# Subset the raster image to speed things up
myRast2 <- crop(myRast, shp_reproj)
plot(myRast2)
plot(shp_reproj, bg = 'transparent', add = TRUE)
```

![](https://raw.githubusercontent.com/JonDDowns/blog_markdowns/main/getPRISMData/getPRISM_files/figure-commonmark/unnamed-chunk-6-1.png)<!-- -->

<br />

### **Extract the data **

<br />

Now, we use our correctly projected shape file and our cropped raster
file to extract the average maximum temperature over each census tract
for the day. We are working with 1/1/2011 in this example.

<br />

``` r
# Get mean temp across each boundary
myExtract <- raster::extract(myRast2, shp_reproj, fun = mean)

# Put in dataframe format, add date and tract identifiers
myOutputData <- data.frame('GEOID10' = shp_reproj@data$GEOID10, 
                           date = as.Date('2011-01-01'), 
                           TMAX = myExtract)

# Take a peek at the data
head(myOutputData)
```

    ##       GEOID10       date      TMAX
    ## 1 53001950100 2011-01-01 -7.456779
    ## 2 53001950200 2011-01-01 -6.259750
    ## 3 53001950300 2011-01-01 -5.479644
    ## 4 53001950400 2011-01-01 -5.475000
    ## 5 53001950500 2011-01-01 -5.326000
    ## 6 53003960100 2011-01-01 -5.268149

<br />

And there you go! A single raster file, turned into a data frame.
But….we have 365 raster files. Thankfully, we are all set up to do
parallel processing. Let’s turn our shape file re-project -\> crop
raster -\> extract data process into a function. It will take some more
work up front, because we need to programmatically figure out the date
instead of hard-coding it. However, it is possible: each file contains
the date as an 8 digit string. I also want to save each result to file.
For now, it will be useful to have a CSV file for each raster image. It
will help us stay organized and quickly identify which files have
already been converted in case we spread the work out over multiple
script runs.

<br />

``` r
# Convert raster to CSV ---------------------------------------------------
# Only do 10 files for demonstration purposes. 
n_ras_to_csv <- 10

# Identify all files ending with .bil (no zip)
prismBils <- list.files(download_dir, pattern = '.bil$', 
                        recursive = TRUE)

outunzip_fns <- basename(dirname(prismBils))
excludes <- which(file.exists(paste0(csv_dir, outunzip_fns, '.csv')))

# If CSVs already exist, we don't need to run this script on them again
if(!identical(excludes, integer(0))){
  prismBils <- prismBils[-excludes]
  outunzip_fns <- outunzip_fns[-excludes]
}

# Date column to add to each entry
dates <- as.Date(
  sub(".*([0-9.]{8}).*", "\\1", basename(prismBils)), 
  format = "%Y%m%d")

# Read in CT shapefile file and a single BIL. Reproject shapefile.
waCensus10 <- readOGR(tract10_fn)
```

    ## Warning in OGRSpatialRef(dsn, layer, morphFromESRI = morphFromESRI, dumpSRS = dumpSRS, : Discarded datum NAD83_High_Accuracy_Reference_Network
    ## in Proj4 definition: +proj=lcc +lat_0=45.3333333333333 +lon_0=-120.5 +lat_1=45.8333333333333 +lat_2=47.3333333333333 +x_0=500000 +y_0=0
    ## +ellps=GRS80 +units=us-ft +no_defs

    ## OGR data source with driver: ESRI Shapefile 
    ## Source: "D:\PRISM\tract10\tract10.shp", layer: "tract10"
    ## with 1458 features
    ## It has 34 fields
    ## Integer64 fields read as strings:  ALANDM AWATERM

``` r
myBilFile <- list.files(download_dir, pattern = '.bil$', recursive = TRUE)[1]
myRast <- raster::raster(paste0(download_dir, myBilFile)[[1]])
waCensus10_transform <- spTransform(waCensus10, crs(myRast))

# Function to make a single PRISM csv file
makePRISMcsv <- function(prismBil, outdir, outfn, shp, varname, funx, date){
  prismRast <- raster::raster(prismBil)
  prismRast_crop <- raster::crop(prismRast, shp)
  extr <- raster::extract(prismRast_crop, shp, fun = funx)
  out <- data.frame(shp@data$GEOID10, date, extr)
  colnames(out) <- c('GEOID10', 'DATE', varname)
  dir.create(outdir)
  data.table::fwrite(out, paste0(outdir, outfn, '.csv'))
  return(out)
}

# Run script in parallel, stop when finished.
addArgs <- list(funx = mean, varname = 'TMAX', shp = waCensus10_transform,
                outdir = csv_dir)
parallel::clusterMap(cl = cl,
                     fun = makePRISMcsv,
                     prismBil = paste0(download_dir, prismBils)[1:n_ras_to_csv],
                     outfn = outunzip_fns[1:n_ras_to_csv],
                     date = dates[1:n_ras_to_csv],
                     MoreArgs = addArgs)
```

    ## $`C:/YOURFILEPATH/PRISM/TMAX/BIL/2011/PRISM_tmax_stable_4kmD2_20110121_bil/PRISM_tmax_stable_4kmD2_20110121_bil.bil`
    ##         GEOID10       DATE      TMAX
    ## 1   53001950100 2011-01-21  1.686708
    ## 2   53001950200 2011-01-21  2.760489
    ## 3   53001950300 2011-01-21  3.439578
    ## 4   53001950400 2011-01-21  3.581000
    ## 5   53001950500 2011-01-21  3.602333
    ## 6   53003960100 2011-01-21  2.815904
    ## 7   53003960200 2011-01-21  3.601333
    ## 8   53003960300 2011-01-21  3.194000
    ## 9   53003960400 2011-01-21  3.142500
    ## 10  53003960500 2011-01-21  3.194000
    ## 11  53003960600 2011-01-21  3.067500
    ## 12  53005010100 2011-01-21  7.329250
    ## 13  53005010201 2011-01-21  7.319000
    ## 14  53005010202 2011-01-21  7.364000
    ## 15  53005010300 2011-01-21  7.638000
    ## 16  53005010400 2011-01-21  7.554000
    ## 17  53005010500 2011-01-21  7.554000
    ## 18  53005010600 2011-01-21  7.803000
    ## 19  53005010701 2011-01-21  6.926500
    ## 20  53005010703 2011-01-21  7.241000
    ## 21  53005010705 2011-01-21  7.132750
    ## 22  53005010707 2011-01-21  7.023667
    ## 23  53005010708 2011-01-21  7.357500
    ## 24  53005010803 2011-01-21  7.128000
    ## 25  53005010805 2011-01-21  8.038000
    ## 26  53005010807 2011-01-21  6.401000
    ## 27  53005010809 2011-01-21  8.334500
    ## 28  53005010810 2011-01-21  8.539000
    
    ....
    Output manually truncated for this blog post.
    ....
    
    ##  [ reached 'max' / getOption("max.print") -- omitted 1125 rows ]

``` r
stopCluster(cl)
```

<br /> 

### **Conclusion**

<br />

First, as promised: [the Github code for the
script](https://github.com/JonDDowns/blog_markdowns/tree/main/getPRISMData).

<br />

To recap, we wrote R code that downloaded data, unzipped them, and
extracted data from a raster file. We kept organized by using a logical
file structure, and had mechanisms in place to identify files that had
already been processed. We used data subsets and parallel processing to
speed up the script’s performance. Not too bad for 122 lines of code!
