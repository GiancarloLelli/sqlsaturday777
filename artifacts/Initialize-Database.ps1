param(
    [Parameter(Mandatory=$true)]
    [string] $sa_password,

    [Parameter(Mandatory=$true)]
    [string] $data_path,

    [Parameter(Mandatory=$true)]
    [string] $db_name,

    [Parameter(Mandatory=$true)]
    [string] $dac_name
)

# start the service
if ($sa_password -ne "_") 
{
	Write-Verbose 'Changing SA login credentials'
    $sqlcmd = "ALTER LOGIN sa with password='$sa_password'; ALTER LOGIN sa ENABLE;"
    Invoke-SqlCmd -Query $sqlcmd -ServerInstance "localhost" 
}

$mdfName = "$db_name.mdf"
$ldfName = "$db_nameLog.ldf"
$mdfPath = "$data_path\$db_name.mdf"
$ldfPath = "$data_path\$db_nameLog.ldf"

# attach data files if they exist: 
if ((Test-Path $mdfPath) -eq $true) 
{
    $sqlcmd = "IF DB_ID('$db_name') IS NULL BEGIN CREATE DATABASE $db_name ON (FILENAME = N'$mdfPath')"

    if ((Test-Path $ldfPath) -eq $true) 
    {
        $sqlcmd =  "$sqlcmd, (FILENAME = N'$ldfPath')"
    }

    $sqlcmd = "$sqlcmd FOR ATTACH GO"
    Write-Verbose 'Data files exist - will attach and upgrade database'
    Invoke-Sqlcmd -Query $sqlcmd -ServerInstance "localhost"
}
else 
{
     Write-Verbose 'No data files - will create new database'
     $sqlcmd = "CREATE DATABASE $db_name ON (NAME = N'$mdfName', FILENAME = N'$mdfPath'), (NAME = N'$ldfName', FILENAME = N'$ldfPath')"
}

# deploy or upgrade the database:
$SqlPackagePath = 'C:\Program Files (x86)\Microsoft SQL Server\140\DAC\bin\SqlPackage.exe'
& $SqlPackagePath  `
    /sf:$dac_name.dacpac `
    /a:Publish `
    /tsn:localhost /tdn:$db_name /tu:sa /tp:$sa_password 

Write-Verbose "Deployed $db_name database, data files at: $data_path"

# data seed
$seed_location = "C:\Data_Seed.sql"
Invoke-SqlCmd -InputFile $seed_location -ServerInstance "localhost" 

$lastCheck = (Get-Date).AddSeconds(-2) 
while ($true) { 
    Get-EventLog -LogName Application -Source "MSSQL*" -After $lastCheck | Select-Object TimeGenerated, EntryType, Message	 
    $lastCheck = Get-Date 
    Start-Sleep -Seconds 2 
}