# SolarWinds File Content Monitor
Use this script to monitor the content of log file(s), and create statistics to use for alerting.  Basically, create a SolarWinds PowerShell monitor, and copy-and-paste the entire script in.  Last, modify line 131 (the last line) to have the variables you need.

## Example:
If you need to monitor a directory that has a new log file written every day, maybe in the format YYYYMMDD.log, then you can use the below to monitor those files for the word "error".

```powershell
Search-FileContentForSolarWinds -FolderPath 'C:\Program Files (x86)\SomeLogDirectory' -FileNameRegularExpression "log" -ContentRegularExpression "error";
```

The above searches the folder specified, for any file with "log" somewhere in the name, and looks for a line in any of those files containing the word "error".  Output will emit the number of log files it searched, and will record any "NewMatches". 

The output for NewMatches will display only the new occurrences since the last time the script executed.  You'll want to keep that in mind as you setup alarms and thresholds.  A "statistics" file is written to the user's temp directory ($env:temp) to track how many occurrences occurred between the last execution and the current execution of the script.
