# Load libraries
library(jsonlite)
library(rvest)
library(raster)
library(rasterVis)
library(rgdal)
library(sp)
library(tidyverse)
library(parallel)

# Set Year and batch size
year <- 2010
n_ras_to_csv <- 20

# Set up parallel runs
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

# Convert raster to CSV ---------------------------------------------------
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

# Run extraction in parallel, end by stopping cluster
addArgs <- list(funx = mean, varname = 'TMAX', shp = waCensus10_transform,
                outdir = csv_dir)
parallel::clusterMap(cl = cl,
                     fun = makePRISMcsv,
                     prismBil = paste0(download_dir, prismBils)[1:n_ras_to_csv],
                     outfn = outunzip_fns[1:n_ras_to_csv],
                     date = dates[1:n_ras_to_csv],
                     MoreArgs = addArgs)
stopCluster(cl)
