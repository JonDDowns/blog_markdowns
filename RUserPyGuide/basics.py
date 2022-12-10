# 
import sqlalchemy as sa
import pandas as pd
import urllib

connection_string = "mssql+pyodbc://readAdvWorks:Plznohackme!123@jondowns.database.windows.net,1433/adventureworks?driver=ODBC+Driver+18+for+SQL+Server"
cnxn = sa.create_engine(connection_string)
pd.read_sql("SELECT GETDATE()", cnxn)

