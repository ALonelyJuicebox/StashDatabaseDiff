<#
---Stash Database Diff PoSH Script---

AUTHOR
    JuiceBox
URL 
    https://github.com/ALonelyJuicebox/StashDatabaseDiff

DESCRIPTION
    Given two database files, this script will tell you which one is newer, and what the schema differences are between them. No files are modified with this script, it is read-only

REQUIREMENTS
    - The Powershell module "PSSQLite" must be installed https://github.com/RamblingCookieMonster/PSSQLite
       Download a zip of the PSSQlite folder in that repo, extract it, run an Admin window of Powershell
       in that directory then run 'install-module pssqlite' followed by the command 'import-module pssqlite'
 #>

# Given two database files, this script will tell you which one is newer, and what the schema differences are between them.



clear-host
write-host "           - Stash Database Diff PoSH Script -"
write-host "`n- Given two database files, this script will tell you which`n  one is newer, and what the schema differences are between them.`n`n- No files are modified with this script, it is read-only."

$PathToDatabase1 = read-host "`n`nPlease enter the path to the first Stash database you'd like to compare against`n"
if (!(test-path $PathToDatabase1)){
    write-host "Invalid path. Press [Enter] to exit"
    exit
}

$PathToDatabase2 = read-host "`nPlease enter the path to the second Stash database you'd like to compare against`n"
if (!(test-path $PathToDatabase2)){
    write-host "Invalid path. Press [Enter] to exit"
    exit
}


#First let's sort out which database is newer
$Query = "SELECT version FROM schema_migrations"
$SchemaVersion1 = Invoke-SqliteQuery -Query $Query -DataSource $PathToDatabase1
$SchemaVersion1 = $SchemaVersion1.version

$Query = "SELECT version FROM schema_migrations"
$SchemaVersion2 = Invoke-SqliteQuery -Query $Query -DataSource $PathToDatabase2 
$SchemaVersion2 = $SchemaVersion2.version

if($SchemaVersion1 -eq $SchemaVersion2){
    write-host "`nThese two Stash databases have the same database Schema Version (version $SchemaVersion1)"
    read-host "There are no schema differences. Press [Enter] to exit"
    exit
}
elseif($SchemaVersion1 -gt $SchemaVersion2){
    $Path_To_Newer_Stash_Database = $PathToDatabase1
    $Path_To_Older_Stash_Database = $PathToDatabase2
    write-host "`nThis database is newer and is running schema version $SchemaVersion1"-ForegroundColor Green
    write-host "- $Path_To_Newer_Stash_Database" 
    write-host "`nThis database is older and is running schema version $SchemaVersion2" -ForegroundColor red
    write-host "- $Path_To_Older_Stash_Database" 
}
else{
    $Path_To_Newer_Stash_Database = $PathToDatabase2
    $Path_To_Older_Stash_Database = $PathToDatabase1
    write-host "`nThis database is newer and is running schema version $SchemaVersion2"-ForegroundColor Green
    write-host "- $Path_To_Newer_Stash_Database" 
    write-host "`nThis database is older and is running schema version $SchemaVersion1" -ForegroundColor red
    write-host "- $Path_To_Older_Stash_Database" 
}

read-host "`nPress [Enter] to begin schema comparison"

#Get all tables from the new database
$Query = "SELECT name FROM sqlite_master WHERE type ='table' AND name NOT LIKE 'sqlite_%'"
$Stash_Tables = Invoke-SqliteQuery -Query $Query -DataSource $Path_To_Newer_Stash_Database

#Array of unmodified tables
$arrUnmodifiedTables = @()

foreach ($Stash_Table in $Stash_Tables){
    $Stash_Table_Name = $Stash_Table.name
    
    #Check to see if this table exists in the older Stash DB
    $Query = "SELECT name FROM sqlite_master WHERE type ='table' AND name NOT LIKE 'sqlite_%' AND name = '"+$Stash_Table_Name+"'"
    $TableExistance = Invoke-SqliteQuery -Query $Query -DataSource $Path_To_Older_Stash_Database

    
    #If the table exists in the older Stash DB, let's check each column and ensure we have matches
    if ($null -ne $TableExistance){
        
        

        #These two queries returns all columns from a given table name. We grab all columns from both the new and old dbs for comparison purposes
        $Query = "PRAGMA table_info($Stash_Table_Name)"
        $NewerColumns = Invoke-SqliteQuery -Query $Query -DataSource $Path_To_Newer_Stash_Database

        $Query = "PRAGMA table_info($Stash_Table_Name)"
        $OlderColumns = Invoke-SqliteQuery -Query $Query -DataSource $Path_To_Older_Stash_Database

        #We only want to show a table name if the table has been modified, so we have a boolean value to flip based on the condition that there's something for the user to see
        $DisplayTableName = $false

        #We also want to track the tables that do not get modified
        $TableWasModified = $false

        #Now we iterate through the columns of the newer database and see if there's any columns that cannot be found in this table.
        foreach($column in $NewerColumns.name) {
            if ($olderColumns.name -notcontains $column) {

                #Flip the bool so that we know that this table has been modified
                $TableWasModified = $true

                #Flip the bool so that a table name is shown 
                if($DisplayTableName -eq $false){
                    write-host "`nTable '$Stash_Table_Name'" -ForegroundColor cyan
                    $DisplayTableName = $true
                }
                    write-host "- New Column: The '$Stash_Table_Name' table now contains the new '$column' column"
                    
            }
        } 
        #Now we check to see if there are columns in the older database that no longer exist in the new table
        foreach($column in $OlderColumns.name) {
            if ($newerColumns.name -notcontains $column) {
                
                #Flip the bool so that we know that this table has been modified
                $TableWasModified = $true

                #Flip the bool so that a table name is shown 
                if($DisplayTableName -eq $false){
                    write-host "`nTable '$Stash_Table_Name'" -ForegroundColor cyan
                    $DisplayTableName = $true
                }

                write-host "- Modified Table: The '$Stash_Table_Name' table no longer contains the '$column' column" -ForegroundColor red
            }
        } 

        #Add to the unmodified tables array
        if ($TableWasModified -eq $false){
            $arrUnmodifiedTables += $Stash_Table_Name
        }
    }
    else{
        write-host "`nTable '$Stash_Table_Name'" -ForegroundColor cyan
        write-host "- New Table: The '$Stash_Table_Name' table is a new table for this schema"
    }
}

write-host "`nUnmodified Tables:" -ForegroundColor Cyan
$arrUnmodifiedTables | sort-object | write-host

write-host "`n...Complete!"

