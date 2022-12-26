INSERT INTO [dbo].[Blog] (Title, Author, Description, Content, ReleaseDate, IsPublished, IsDeleted)
VALUES ('Using the Sportradar API to create an NBA database',
        'Jon Downs', 
        'A Python tutorial on accessing and parsing JSON data from an NBA API', 
        'https://cs410032000ad584321.blob.core.windows.net/mydata/nbainit.html', 
        GETDATE(), 1, 0)
