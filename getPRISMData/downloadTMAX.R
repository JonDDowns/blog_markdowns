# Load libraries
library(jsonlite)
library(rvest)
library(raster)
library(rgdal)
library(sp)
library(tidyverse)
library(raster)
library(rgdal)
library(parallel)

# Load configuration settings
config <- jsonlite::read_json('C:/Users/jondo/OneDrive/Documents/DEV/config/extractPRISM.json')

# Path to where all BIL files will download (make if necessary)
bil_dir <- paste0(config$dirPRISM, 'TMAX/BIL/')
dir.create(bil_dir, recursive = TRUE)

# Create a download directory for 2010 TMAX data (make if necessary)
download_dir <- paste0(bil_dir, '2010/')
dir.create(download_dir)

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

# Get TMAX files for 2010
files <- listPRISMFiles(var = 'tmax', year = '2010')

# Check for already downloaded files (we don't want to download twice)
already_downloaded <- list.files(download_dir, pattern = '.zip')
files$files <- files$files[!(files$files %in% already_downloaded)]

# Download all of the files specified
dlPRISMDaily <- function(baselnk, file, outdir){
  fn <- paste0(baselnk, '/', file)
  download.file(fn, destfile = paste0(outdir, file))
}
dlPRISMDaily(baselnk = files$lnk, file = files$files, outdir = download_dir)

# UNZIP FILES -------------------------------------------------------------
# Identify all of the .zip files in the directory we just created
unzip_fns <- list.files(download_dir, pattern = ".zip")

# Identify already-unzipped versions of these files, remove from list
already_unzipped <- basename(list.dirs(download_dir))
unzip_fns <- unzip_fns[!(gsub('.zip', '', unzip_fns) %in% already_unzipped)]

# Unzip the files that need it
lapply(unzip_fns, function(x) 
  unzip(x, exdir = paste0(download_dir, '/', gsub(".zip", '', x))))

# Convert raster to CSV ---------------------------------------------------
# Load libraries


# Load configuration settings
config <- jsonlite::read_json('C:/Jon/cfig/extractPRISM.json')

# Directories used
bil_dir <- paste0(config$dirPRISM, 'BILS/TMAX/')
dirs <- list.dirs(bil_dir, recursive = TRUE)
dirs <- dirs[grepl('PRISM_tmax', dirs)]

# Get the list of output directories and filenames, identify already-made CSVs
prismBils <- paste0(dirs, '/', basename(dirs), '.bil')
outdirs <- paste0(config$dirPRISM, 'CSV/', basename(dirname(dirname(prismBils))), '/')
outunzip_fns <- basename(dirname(prismBils))
excludes <- which(file.exists(paste0(outdirs, outunzip_fns, '.csv')))

# Now subset each of the lists
prismBils <- prismBils[-excludes]
outdirs <- outdirs[-excludes]
outunzip_fns <- outunzip_fns[-excludes]

# Date column to add to each entry
dates <- as.Date(
  sub(".*([0-9.]{8}).*", "\\1", basename(prismBils)), 
  format = "%Y%m%d")

# Read in OGR file
waCensus10 <- readOGR("C:/Jon/tract10/tract10.shp")

# Function to make a single PRISM csv file
makePRISMcsv <- function(prismBil, outdir, outfn, shp, varname, funx, date){
  prismRast <- raster::raster(prismBil)
  extr <- raster::extract(prismRast, shp, fun = funx)
  out <- data.frame(shp@data$GEOID10, date, extr)
  colnames(out) <- c('GEOID10', 'DATE', varname)
  dir.create(outdir)
  data.table::fwrite(out, paste0(outdir, outfn, '.csv'))
  return(out)
}

# Set up parallel runs
nc <- detectCores() - 2
cl <- makeCluster(nc)
parallel::clusterMap(cl = cl,
                     fun = makePRISMcsv,
                     prismBil = prismBils,
                     outdir = outdirs,
                     outfn = outunzip_fns,
                     date = dates,
                     MoreArgs = list(funx = mean, varname = 'TMAX', shp = waCensus10))
