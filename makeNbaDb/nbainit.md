## **Use Sportradar's NBA API to build your own database**

<br/>

### **Introduction**

<br/>

My disovery of advanced statistics in sports is one of the things that led me to data science. Watching sports on TV usually means putting up with a slew of tired observations and adages of questionable accuracy. It was fresh and interesting to learn about concepts like value over replacement and points per possession. No one number can capture a player's impact, but advanced statistics are much more useful than the other information available. 

<br/>

The NBA is my favorite league and it would be very fun to explore its data. Before that, I must do the less glamorous task of preparing the data. Which, according to [some estimates](https://www.anaconda.com/state-of-data-science-2020), is 45% of a data scientist's working hours. I identified the [sportradar API](https://developer.sportradar.com/docs/read/basketball/NBA_v7) as an option for data. However, a SQL database would be much more appealing for the data combinations, custom statistics, and other work that would require the data in tabular format. Additionally, we have to consider the cost of requesting data from an API so frequently.

<br/>

Currently, I have been able to create two tables in my NBA database: the schedules table and the seasons table. In this post, I will show how I:

<br/>

1. Connected to the sportradar API
2. Downloaded NBA season and schedule data
3. Flattened the data and loaded it into a relational database
4. Developed procedures for updates that only download what is necessary

<br/>

Oh, and a final personal note: this is my first Python post! I will be doing more of these moving forward.

<br/>

### **Pre-requisites**

<br/>

1. A [sportradar API](https://developer.sportradar.com/docs/read/basketball/NBA_v7) key
2. A SQL database that you have successfully connected to and can modify. A tutorial to create and connect to an Azure SQL database in Python can be found [here](https://docs.microsoft.com/en-us/azure/azure-sql/database/connect-query-python?view=azuresql). 
3. Python and all packages used in the post
4. (Optional) Some familiarity with environment variables
5. (Optional) An Azure KeyVault account. See how to get set up and interact with Azure KeyVault via Python [here](https://docs.microsoft.com/en-us/azure/key-vault/secrets/quick-create-python?tabs=azure-cli).

<br/>

### **Getting set up**

<br/>

To begin, let's load the packages and specify the folder paths we will be using. Like previous posts, I will be using a JSON configuration file and environment variables to define many of these things. It keeps information private while still letting me share the fun parts. Additionally, there are a few custom functions from my main development project. Functions from that module connect to the database and my key vault account.

<br/>

The calls to `importlib` and `types` allow me to import the `myFuns` module I have been coding in my main project folder. It is appropriately named: myFuns has all of the functions I have been using to build the database, including connections and secret handling. If you'd prefer not mess with those sorts of things, define the following variables to proceed: 

<br/>

1. An object `srNBAKey` that is your sportsradar API key for the NBA v7 API
2. An object `cnxn` that is your connection to the SQL database engine
3. An object `nbaDir` that will house the downloaded JSON files

<br/>

Now, let's run the code to set up our session:

<br/>

```python
# SETUP
# Import standard packages
import os, importlib.machinery, http.client, json, pandas as pd, time
import sqlalchemy, sys
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
```

<br/>

Wonderful! We have our API key ready to go and we are connected to our database. Now, let's explore the sportradar API.

<br/>

### **Explore the API**

<br/>

When you navigate to the [API main page](https://developer.sportradar.com/docs/read/basketball/NBA_v7#nba-api-map), you will be greeted with this image:

<br/>

![sportradar API diagram](https://developer.sportradar.com/files/NBAv7SVG.svg)

<br/>

Quite helpful! Today, we will be working with the Schedule and Seasons endpoints. Let's take a peek at the data. We will start an https connection, send a get request with our API key, and load the JSON payload.

<br/>

```python
# Get list of available seasons
conn = http.client.HTTPSConnection("api.sportradar.us", timeout = 10)
suffix = f"/nba/trial/v7/en/league/seasons.json?api_key={srNBAKey.value}"
conn.request("GET", suffix)
res = conn.getresponse()
data = res.read()
allSeasons = json.loads(data)['seasons']
print(json.dumps(allSeasons[0:2], indent = 2))
```
<br/>

    [
      {
        "id": "5b8b57d1-7290-44f8-b29c-353e865c139e",
        "year": 2012,
        "type": {
          "code": "PRE",
          "name": "Pre-season"
        }
      },
      {
        "id": "5f45c666-ba68-48d6-a905-f19702ab7e4c",
        "year": 2012,
        "type": {
          "code": "PST",
          "name": "Post-season"
        }
      }
    ]
<br/>

The schedule has games for the pre-season, post-season, and regular season. Each season has a unique ID and year. Next, let's pull one of these seasons and look at its schedule. We will need the year and type of a season to pull it's schedule.

<br/>

```python
# Get year and season type for first listed
year = allSeasons[1]["year"]
seasonType = allSeasons[1]["type"]["code"]

# Pull the data, convert to JSON object
# Add some rests to prevent errors
time.sleep(1)
conn = http.client.HTTPSConnection("api.sportradar.us", timeout = 10)
conn.request("GET", f"/nba/trial/v7/en/games/{year}/{seasonType}/schedule.json?api_key={srNBAKey.value}")
res = conn.getresponse()
data = res.read()
testSched = json.loads(data.decode("utf8"))
```
<br/>

### **Design the database tables**

<br/>

Now that we have our two file formats, we can start to think through a database design. Reading through the docs, it seems the table design is not [normalized](https://docs.microsoft.com/en-us/office/troubleshoot/access/database-normalization-description). For example, there is a team profile API endpoint containing most of the team information included in the `home` and `away` entries, so the same information is being presented multiple times. This makes sense: it likely reduces the number of API calls for most users. Still, this underscores the point that the optimal database design is not the same as the optimal API design. We are not working with a particularly sizable dataset, so it should be easy to rebuild the database if we want to change the design later. 

<br/>

After some initial experimentation, I decided that these were the variables I wanted:

<br/>

```python
cnxn.execute("""
DROP TABLE IF EXISTS scheduleBLOG;
CREATE TABLE scheduleBLOG (
    schedId varchar(100) PRIMARY KEY        
    , srMatchId varchar(100)
    , schedDt DATETIME
    , homePoints int
    , awayPoints int
    , coverage varchar(50)
    , status varchar(50)    
    , trackOnCourt varchar(20)
    , IdHome varchar(100)
    , srIdHome varchar(100)
    , nameHome varchar(100)
    , aliasHome varchar(100)
    , IdAway varchar(100)
    , srIdAway varchar(100)
    , nameAway varchar(100)
    , aliasAway varchar(100)
    , seasonId VARCHAR(100) NOT NULL 
    , createDt DATETIME DEFAULT CURRENT_TIMESTAMP
    , updatedDt DATETIME     
);

DROP TABLE IF EXISTS seasonBLOG;
CREATE TABLE seasonBLOG (
    seasonId VARCHAR(100) NOT NULL PRIMARY KEY
    , seasonType varchar(10) NOT NULL
    , seasonYear int NOT NULL
    , createDt DATETIME DEFAULT CURRENT_TIMESTAMP
    , updatedDt DATETIME
);

ALTER TABLE scheduleBLOG
ADD CONSTRAINT FK_seasonIdBLOG
FOREIGN KEY (seasonId) REFERENCES seasonBLOG(seasonId)
""")
```

<br/>

We will use the sportradar identifiers as our primary keys in the database for now. We will allow some missing data in the schedule table. After we ingest all of the data, we can think more thoroughly about other constraints to add.

<br/>

The [foreign key](https://www.techopedia.com/definition/7272/foreign-key#:~:text=A%20foreign%20key%20is%20a,establishing%20a%20link%20between%20them.) constraint lets our database know that the schedule and season tables share a common identifier, `seasonId`. That adds some built-in data quality checks. For example, it would not allow you to enter a `seasonId` in the `schedules` table unless that ID were in the `season` table. Formalizing these sorts of relationships help others quickly understand how your database is designed.

<br/>

### **Download Data**

<br/>

Now that we have explored the data and created our database tables, we will write code to download all data in JSON format and save it in an organized fashion. All files will be named by the convention `schedTYPEYYYY.json` (e.g. `schedPRE2022`). We also want to avoid re-downloading data and making unnecessary API calls. The `os.path.exists` function comes in quite handy. I have already downloaded most of the data, but for the sake of this blog I will delete a few schedules and run the function. 

<br/>

```python
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
```

    downloading schedPRE2012.json
    downloading schedPRE2013.json
    downloading schedPRE2014.json
    downloading schedREG2016.json
    downloading schedREG2017.json
    
<br/>

### **Upload Data**

<br/>

Now, we put the data we just downloaded into our database. It will be easiest to rename the JSON data elements to match their SQL-database counterparts. To do that, we use our trustry old friend, the JSON file. The dictionary keys will be the SR API names, and the values our desired values. The JSON file looks like this:

<br/>

```python
# JSON file with schedionaries for renaming raw to SQL column names
with open("renameVars.json", "r") as f:
    renames = json.load(f)

print(json.dumps(renames, indent = 2))
```

    {
      "schedule": {
        "id": "schedId",
        "sr_id": "srMatchId",
        "scheduled": "schedDt",
        "home_points": "homePoints",
        "away_points": "awayPoints",
        "coverage": "coverage",
        "status": "status",
        "track_on_court": "trackOnCourt",
        "idHome": "idHome",
        "sr_idHome": "srIdHome",
        "nameHome": "nameHome",
        "aliasHome": "aliasHome",
        "idAway": "idAway",
        "sr_idAway": "srIdAway",
        "nameAway": "nameAway",
        "aliasAway": "aliasAway"
      },
      "season": {
        "id": "seasonId",
        "type": "seasonType",
        "year": "seasonYear"
      }
    }
    
<br/>

And with that, we should have everything we need to populate our database tables! For both games and seasons, we will want to make sure the record has not been entered before. It also seems there are some seasons with no data available, so the case where the JSON file is empty will need to be handled.

<br/>

```python
games = pd.read_sql("SELECT DISTINCT schedId FROM scheduleBLOG", cnxn)
seasons = pd.read_sql("SELECT DISTINCT seasonId FROM seasonBLOG", cnxn)

####################################################
# MAKE ROWS
####################################################
# Get all of our schedule JSON files
fns = os.listdir(schedDir)

# Loop through each schedule year and add to db
for fn in fns:     
    # Open file, determine year
    with open(os.path.join(schedDir, fn)) as f:
        sched = json.load(f)
    seas = {renames["season"].get(k, k): v for k, v in sched['season'].items()}    
    season = pd.DataFrame(seas, index = [0])

    # Have we loaded this season before?
    newseason = not season['seasonId'].values[0] in seasons['seasonId'].tolist()
    if newseason:
        print("Adding Season " + fn)
        season.to_sql('seasonBLOG', con = cnxn, if_exists = 'append', index = False)

    # If no games, skip
    if len(sched['games']) == 0:
        print("No games in list " + fn)
        pass

    # Loop through games, extract values into dictionary
    out = []    
    for game in sched['games']:
        newgame = not game['id'] in games['schedId'].tolist()
        if newgame:
            # Variables of interest from parent values
            parentKeep = {'id', 'sr_id', 'status', 'coverage', 'scheduled', \
                'track_on_court', 'home_points', 'away_points'}
            parentValues = {x: game[x] for x in parentKeep if x in game}

            # We want the same values from "home" and "away" subdicts
            teamKeep = {"id", "sr_id", "name", "alias"}
            homeValues = {x + 'Home': game['home'][x] for x in teamKeep \
                if x in game['home']}
            awayValues = {x + 'Away': game['away'][x] for x in teamKeep \
                if x in game['away']}

            # Combine all dicts, rename according to renaming dictionary
            # Use None-type if variable is not present
            comb = {**parentValues, **homeValues, **awayValues}
            res = {renames["schedule"].get(k, k): v for k, v in comb.items()}
            notIn = [x for x in renames['schedule'].values() if x not in res]
            for n in notIn:
                res[n] = None
            out.append(res)
        else: 
            pass

    # Convert all of our dicts to a DF, then load to DB
    print("loading " + fn)
    toLoad = pd.DataFrame.from_dict(out)
    if not toLoad.empty:
        toLoad['schedDt'] = pd.to_datetime(toLoad['schedDt'])
        toLoad['seasonId'] = season['seasonId'].values[0]        
        toLoad.to_sql('scheduleBLOG', con = cnxn, if_exists = 'append', index = False, \
            dtype = {"schedDt": sqlalchemy.DateTime})
    else:
        print("skipping " + fn + "due to no new records")
```

    Adding Season schedREG2012.json
    No games in list schedREG2012.json
    loading schedREG2012.json
    skipping schedREG2012.jsondue to no new records
    Adding Season schedREG2013.json
    loading schedREG2013.json
    Adding Season schedREG2014.json
    loading schedREG2014.json
    Adding Season schedPRE2015.json
    loading schedPRE2015.json
    Adding Season schedREG2015.json
    loading schedREG2015.json
    Adding Season schedPRE2016.json
    loading schedPRE2016.json
    Adding Season schedPRE2017.json
    loading schedPRE2017.json
    Adding Season schedPST2017.json
    loading schedPST2017.json
    Adding Season schedPST2018.json
    loading schedPST2018.json
    Adding Season schedREG2018.json
    loading schedREG2018.json
    Adding Season schedPIT2019.json
    loading schedPIT2019.json
    Adding Season schedREG2019.json
    loading schedREG2019.json
    Adding Season schedPRE2020.json
    loading schedPRE2020.json
    Adding Season schedPIT2020.json
    loading schedPIT2020.json
    Adding Season schedREG2020.json
    loading schedREG2020.json
    Adding Season schedPRE2021.json
    loading schedPRE2021.json
    Adding Season schedPST2021.json
    loading schedPST2021.json
    Adding Season schedPIT2021.json
    loading schedPIT2021.json
    Adding Season schedREG2021.json
    loading schedREG2021.json
    Adding Season schedPST2022.json
    No games in list schedPST2022.json
    loading schedPST2022.json
    skipping schedPST2022.jsondue to no new records
    Adding Season schedPIT2022.json
    No games in list schedPIT2022.json
    loading schedPIT2022.json
    skipping schedPIT2022.jsondue to no new records
    Adding Season schedREG2022.json
    loading schedREG2022.json
    Adding Season schedPST2012.json
    loading schedPST2012.json
    Adding Season schedPRE2018.json
    loading schedPRE2018.json
    Adding Season schedPST2019.json
    loading schedPST2019.json
    Adding Season schedPST2013.json
    loading schedPST2013.json
    Adding Season schedPRE2019.json
    loading schedPRE2019.json
    Adding Season schedPST2020.json
    loading schedPST2020.json
    Adding Season schedPST2014.json
    loading schedPST2014.json
    Adding Season schedPST2015.json
    loading schedPST2015.json
    Adding Season schedPST2016.json
    loading schedPST2016.json
    Adding Season schedPRE2022.json
    loading schedPRE2022.json
    Adding Season schedPRE2012.json
    No games in list schedPRE2012.json
    loading schedPRE2012.json
    skipping schedPRE2012.jsondue to no new records
    Adding Season schedPRE2013.json
    loading schedPRE2013.json
    Adding Season schedPRE2014.json
    loading schedPRE2014.json
    Adding Season schedREG2016.json
    loading schedREG2016.json
    Adding Season schedREG2017.json
    loading schedREG2017.json
    
<br/>

Let's make sure that worked. We will query the tables we loaded to and print out a few rows. Did it work? Did it fail? The suspense! The intrigue!

<br/>

```python
# Read in our newly loaded data
games = pd.read_sql("SELECT TOP 10 * FROM scheduleBLOG", cnxn)
seasons = pd.read_sql("SELECT TOP 10 * FROM seasonBLOG", cnxn)

# Print a few games out
print(games)
# And a few seasons
print(seasons)
```

                                    schedId          srMatchId  \
    0  000193f7-3433-461a-b562-7f7c69e8023f               None   
    1  000477ca-9053-4bdf-857b-629ebc8e670e  sr:match:24750712   
    2  00096a31-9afb-4d89-957f-2ca5741f813c  sr:match:12233334   
    3  000bee26-0d7f-451e-b2c3-b52f24581c7f   sr:match:7790366   
    4  000e7d9f-7fa0-4273-a419-e02a95cd6101   sr:match:9956289   
    5  0010abb3-bf15-401a-97fd-a20d7f45ef3b               None   
    6  00189aa2-fe36-420e-b3a1-7d9dbd8846a1  sr:match:28808730   
    7  001b86bd-1891-462f-8d0b-c373434d4f14  sr:match:15327444   
    8  001da480-f3ad-4da4-a72b-9899f2394672  sr:match:28809934   
    9  001eaa7b-4a2d-4077-b590-1f288a42a8a2   sr:match:4194739   
    
                  schedDt  homePoints  awayPoints coverage     status  \
    0 2023-04-08 00:30:00         NaN         NaN     full  scheduled   
    1 2021-02-27 03:00:00       130.0       121.0     full     closed   
    2 2017-12-14 00:00:00        95.0       106.0     full     closed   
    3 2015-10-31 00:00:00       113.0       118.0     full     closed   
    4 2017-01-21 01:00:00       107.0        91.0     full     closed   
    5 2023-02-04 02:00:00         NaN         NaN     full  scheduled   
    6 2022-01-03 00:00:00        99.0       133.0     full     closed   
    7 2018-11-01 00:00:00       128.0       125.0     full     closed   
    8 2022-02-17 00:30:00       113.0       108.0     full     closed   
    9 2014-02-09 20:30:00        86.0        92.0     full     closed   
    
      trackOnCourt                                IdHome      srIdHome  \
    0            1  583ecf50-fb46-11e1-82cb-f4ce4684ea4c  sr:team:3411   
    1            1  583ec825-fb46-11e1-82cb-f4ce4684ea4c  sr:team:3428   
    2            1  583ed157-fb46-11e1-82cb-f4ce4684ea4c  sr:team:3437   
    3         None  583ecefd-fb46-11e1-82cb-f4ce4684ea4c  sr:team:3410   
    4         None  583eca88-fb46-11e1-82cb-f4ce4684ea4c  sr:team:3415   
    5            1  583ece50-fb46-11e1-82cb-f4ce4684ea4c  sr:team:3434   
    6            1  583ec97e-fb46-11e1-82cb-f4ce4684ea4c  sr:team:3430   
    7            1  583eca2f-fb46-11e1-82cb-f4ce4684ea4c  sr:team:3426   
    8            1  583ec7cd-fb46-11e1-82cb-f4ce4684ea4c  sr:team:3419   
    9         None  583ecae2-fb46-11e1-82cb-f4ce4684ea4c  sr:team:3427   
    
                     nameHome aliasHome                                IdAway  \
    0        Dallas Mavericks       DAL  583ec5fd-fb46-11e1-82cb-f4ce4684ea4c   
    1   Golden State Warriors       GSW  583ec97e-fb46-11e1-82cb-f4ce4684ea4c   
    2           Orlando Magic       ORL  583ecdfb-fb46-11e1-82cb-f4ce4684ea4c   
    3         Milwaukee Bucks       MIL  583ec8d4-fb46-11e1-82cb-f4ce4684ea4c   
    4       Memphis Grizzlies       MEM  583ed0ac-fb46-11e1-82cb-f4ce4684ea4c   
    5               Utah Jazz       UTA  583ecb8f-fb46-11e1-82cb-f4ce4684ea4c   
    6       Charlotte Hornets       CHA  583ecfa8-fb46-11e1-82cb-f4ce4684ea4c   
    7  Minnesota Timberwolves       MIN  583ece50-fb46-11e1-82cb-f4ce4684ea4c   
    8          Indiana Pacers       IND  583ec8d4-fb46-11e1-82cb-f4ce4684ea4c   
    9      Los Angeles Lakers       LAL  583ec5fd-fb46-11e1-82cb-f4ce4684ea4c   
    
           srIdAway              nameAway aliasAway  \
    0  sr:team:3409         Chicago Bulls       CHI   
    1  sr:team:3430     Charlotte Hornets       CHA   
    2  sr:team:3425  Los Angeles Clippers       LAC   
    3  sr:team:3431    Washington Wizards       WAS   
    4  sr:team:3413      Sacramento Kings       SAC   
    5  sr:team:3423         Atlanta Hawks       ATL   
    6  sr:team:3416          Phoenix Suns       PHX   
    7  sr:team:3434             Utah Jazz       UTA   
    8  sr:team:3431    Washington Wizards       WAS   
    9  sr:team:3409         Chicago Bulls       CHI   
    
                                   seasonId                createDt updatedDt  
    0  5027b6ac-731c-4622-8d69-d863ae7c626b 2022-08-27 17:21:55.940      None  
    1  feb33381-9dbf-45b6-82c1-3c50c9a2b5ce 2022-08-27 17:17:14.453      None  
    2  7dcb5184-ab33-49fe-bd18-c4ca2b1cfc08 2022-08-27 17:26:16.447      None  
    3  698590c2-3579-4d4e-a931-3d6dff427ee2 2022-08-27 17:10:28.640      None  
    4  03241c9e-731b-40d0-a36f-bcc9932d055b 2022-08-27 17:24:53.857      None  
    5  5027b6ac-731c-4622-8d69-d863ae7c626b 2022-08-27 17:21:21.700      None  
    6  16d6292c-25c6-4487-aa90-912c1e09170b 2022-08-27 17:19:10.247      None  
    7  47c9979e-5c3f-453d-ac75-734d17412e3f 2022-08-27 17:12:56.880      None  
    8  16d6292c-25c6-4487-aa90-912c1e09170b 2022-08-27 17:19:37.590      None  
    9  5ddc217a-a958-4616-9bdf-e081022c440b 2022-08-27 17:07:53.323      None  
                                   seasonId seasonType  seasonYear  \
    0  03241c9e-731b-40d0-a36f-bcc9932d055b        REG        2016   
    1  16d6292c-25c6-4487-aa90-912c1e09170b        REG        2021   
    2  191e5d0e-ad55-43ef-995c-317ae9ea1213        REG        2019   
    3  1e20b802-0e4c-49f2-8045-f02a8105a71e        REG        2012   
    4  22ae1aa6-d28a-452f-b6ce-c120e03c6b7d        PST        2013   
    5  269501e2-f4fa-4328-ab65-4bafa7889f29        PRE        2017   
    6  31dbd74e-7b42-4b97-ae0f-a4e71a4221c4        PST        2018   
    7  47c9979e-5c3f-453d-ac75-734d17412e3f        REG        2018   
    8  5027b6ac-731c-4622-8d69-d863ae7c626b        REG        2022   
    9  529bed34-5a8d-46d4-9eef-114bd1340867        PST        2015   
    
                     createDt updatedDt  
    0 2022-08-27 17:24:00.327      None  
    1 2022-08-27 17:18:24.313      None  
    2 2022-08-27 17:14:32.230      None  
    3 2022-08-27 17:06:49.897      None  
    4 2022-08-27 17:22:24.387      None  
    5 2022-08-27 17:12:18.893      None  
    6 2022-08-27 17:12:37.240      None  
    7 2022-08-27 17:12:47.427      None  
    8 2022-08-27 17:20:15.720      None  
    9 2022-08-27 17:23:03.153      None  
    
<br/>

Looks to have worked. Eventually, a custom primary key that sorts chronologically would be nice. But, we have a good prototype to work with. We can now download some game/season statistic data and start having some real fun in the coming weeks and months. At least it will give me something to do this NBA season while I nervously wait for Chet Holmgren to [heal from his severe foot injury](https://theathletic.com/3535418/2022/08/24/thunder-chet-holmgren-out-for-season-lisfranc-injury/). Feel better soon, Chet!

<br/>

That is it for this week. I hope you check back in for more! Email me at [jon.d.downs@outlook.com](jon.d.downs@outlook.com) with questions and comments.
