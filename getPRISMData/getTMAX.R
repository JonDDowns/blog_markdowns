# Load libraries
library(raster)
library(sp)
library(rgdal)
library(tidyverse)
library(parallel)

# Load configuration settings
config <- jsonlite::read_json('C:/Jon/cfig/extractPRISM.json')

# Directories used
tmax_dir <- paste0(config$dirPRISM, 'BILS/TMAX/')
dirs <- list.dirs(tmax_dir, recursive = TRUE)
dirs <- dirs[grepl('PRISM_tmax', dirs)]

# Get the list of output directories and filenames, identify already-made CSVs
prismBils <- paste0(dirs, '/', basename(dirs), '.bil')
outdirs <- paste0(config$dirPRISM, 'CSV/', basename(dirname(dirname(prismBils))), '/')
outfns <- basename(dirname(prismBils))
excludes <- which(file.exists(paste0(outdirs, outfns, '.csv')))

# Now subset each of the lists
prismBils <- prismBils[-excludes]
outdirs <- outdirs[-excludes]
outfns <- outfns[-excludes]

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
                     outfn = outfns,
                     date = dates,
                     MoreArgs = list(funx = mean, varname = 'TMAX', shp = waCensus10))
