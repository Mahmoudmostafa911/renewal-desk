USE RenewalDesk;
GO
-- Write only the question; SQL maps a known topic and chooses a default text term.
EXEC renewal.SearchCases @Question=N'Why does the fleet vehicle battery fail after charging?';
GO
EXEC renewal.SearchCases @Question=N'Why does my invoice have a duplicate charge?',@Keyword=N'invoice',@Top=5;
GO
-- After testing, edit the question and run again:
EXEC renewal.SearchCases @Question=N'The dashboard is slow',@Keyword=N'dashboard';
