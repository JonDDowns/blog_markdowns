# SETUP
# Import standard packages
import os, importlib.machinery, http.client, json, pandas as pd, time
import sys
import sqlalchemy
import importlib, types # Only needed if loading custom module

# Read in Python config file
cfFn = os.path.join(os.environ["myconfig"], "nba.json")
with open(cfFn, "r") as f:
    cf = json.load(f)

# Source custom functions
myFunsFn = os.path.join(cf["nbaFunsDir"], "myFuns/__init__.py")
sys.path.append(cf["nbaFunsDir"])
from myFuns.cloud import secman

# Get NBA API key from Azure and connect to SQL db
seccli = secman.secretClient()
srNBAKey = seccli.get_secret("srNBAKey")
cnxn = secman.dbEngine(seccli)

# Specify directories for output
nbaDir = "D:/nbaBlog"
schedDir = os.path.join(nbaDir, "schedules")
# os.makedirs(schedDir)

# Get list of available seasons
conn = http.client.HTTPSConnection("api.sportradar.us", timeout = 10)
suffix = f"/nba/trial/v7/en/league/seasons.json?api_key={srNBAKey.value}"
conn.request("GET", suffix)
res = conn.getresponse()
data = res.read()
allSeasons = json.loads(data)['seasons']

# Turn a schedule retrieval into a fnxn
def getSchedule(year, seasonType, apiKey):
    conn = http.client.HTTPSConnection("api.sportradar.us", timeout = 10)    
    conn.request("GET", f"/nba/trial/v7/en/games/{year}/{seasonType}/schedule.json?api_key={apiKey}")
    res = conn.getresponse()
    data = res.read()    
    return json.loads(data.decode("utf8"))

# Download each season if its key is not yet in the database
# Template names based on season type and year
for season in allSeasons:         
    year = season["year"]
    type = season["type"]["code"]
    fileName = "sched" + type + str(year) + ".json"
    outpath = os.path.join(schedDir, fileName)

    # Only download file if we have not already    
    if not os.path.exists(outpath):
        print("downloading "+ fileName)
        time.sleep(1)
        seas = getSchedule(year = year, seasonType = type, apiKey = srNBAKey.value)
        with open(outpath, 'w') as f:               
            json.dump(seas, f)