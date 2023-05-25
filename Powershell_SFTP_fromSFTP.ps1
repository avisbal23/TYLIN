## $UrlForStfpSite = 'sftp.tylin.com'
## $TyliWorkdaySFTPCred = Get-Credential
Start-Transcript -OutputDirectory "G:\HR Tech\Logs\PowerShell\"
## Load credential
$TyliWorkdaySFTPCred = Import-Clixml -Path "G:\HR Tech\Credentials\sftpCredentials_from_Svc.WorkdayTasks.xml"

## Start SFTP Session
$SFTPSession = New-SFTPSession -ComputerName 'sftp.tylin.com' -Credential $TyliWorkdaySFTPCred -ConnectionTimeout 300

## Get all files 
$FilesFound = Get-SFTPChildItem -SFTPSession $SFTPSession -Path /WorkdayVision/Staging/Demographics

## select most recent file from list 
$LatestFile = ($FilesFound | Where {$_.Name -like "*.csv"} | Sort LastWriteTime -Descending)[0].FullName
Write-Information "Found $LatestFile to download from sftp site"
## Set Destination Directory
$Destination = 'G:\HR Tech\DemographicFiles\FromWorkday'

## Move most recent file to destination directory
Get-SFTPItem -SessionId $SFTPSession.SessionId -Path $LatestFile -Destination $Destination

## Get file and decrypt 
$FilePathPrivate = 'G:\HR Tech\Keys\SECRET.asc'
$FilePath = (Get-ChildItem -Path $Destination -Filter "*.csv" | sort LastWriteTime -Descending)[0]
$OutputFolderPath = 'G:\HR Tech\DemographicFiles\FromWorkday\Decrypted'
Unprotect-PGP -FilePathPrivate $FilePathPrivate -FilePath $FilePath.FullName -OutFilePath "$OutputFolderPath\$($FilePath.Name)"
If(Test-Path "$OutputFolderPath\$($FilePath.Name)")
{
    Write-Information "Downloaded and encrypted file"
}
Else
{
    Write-Warning "Failed to get and encrypt file, exiting"
    Return
}

Remove-Item $FilePath.FullName -Force

## Run B R Program
Write-Information "Running BR Program to enhance file"
Start-Process "G:\HR Tech\BR Program\Tylin.Workday.CsvWorkerId.ConsoleApp\bin\Release\net6.0\Tylin.Workday.CsvWorkerId.ConsoleApp.exe" -Wait
Write-Information "BR Program finished running"
Remove-Item "$OutputFolderPath\$($FilePath.Name)" -Force
$FilesFromBR = Get-ChildItem "G:\HR Tech\DemographicFiles\ToOneDeltek" -Filter "*.csv"
# $FilesFromBR | For-EachObect {Remove-Item $_.FullName -Force}

## Upload encrypted file after B R Program
$newDemographics = (Get-ChildItem -Path "G:\HR Tech\DemographicFiles\ToOneDeltek" -File | Sort LastWriteTime -Descending)[0]

## Encrypt file 
Protect-PGP -FilePathPublic "G:\HR Tech\Keys\PUBLIC.asc" -FilePath $newDemographics.FullName -OutFilePath "G:\HR Tech\DemographicFiles\ToOneDeltek\Enrypted\$($NewDemographics.Name).pgp"
# Delete Unencrypted File 
Remove-Item -Path $NewDemographics.FullName -Force

## Place file from DB server to SFTP server directory
Set-SFTPItem -SFTPSession $SFTPSession -Destination '/WorkdayVision/Staging/Demographics/Outbound' -Path "G:\HR Tech\DemographicFiles\ToOneDeltek\Enrypted\$($NewDemographics.Name).pgp"
Stop-Transcript