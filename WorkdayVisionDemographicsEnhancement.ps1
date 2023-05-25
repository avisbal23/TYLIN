Start-Transcript -OutputDirectory "G:\HR Tech\Logs\PowerShell\"

$TyliWorkdaySFTPCred = Import-Clixml -Path "G:\HR Tech\Credentials\sftpCredentials_from_Svc.WorkdayTasks.xml"

## Start SFTP Session
$SFTPSession = New-SFTPSession -ComputerName 'sftp.tylin.com' -Credential $TyliWorkdaySFTPCred -ConnectionTimeout 300
If($null -eq $SFTPSession)
{
    Write-Warning "Session to sftp.tylin.com was not being created, exiting script"
    Return
}
## Get all files 
$FilesFound = Get-SFTPChildItem -SFTPSession $SFTPSession -Path /WorkdayVision/Production/Demographics

## select most recent file from list 
$LatestFile = ($FilesFound | Where {$_.Name -like "Vision_Demographics_Ful*.csv"} | Sort LastWriteTime -Descending)[0].FullName
Write-Information "Found $LatestFile to download from sftp site"
## Set Destination Directory
$Destination = 'G:\HR Tech\DemographicFiles\FromWorkday'

## Move most recent file to destination directory
try {
    Get-SFTPItem -SessionId $SFTPSession.SessionId -Path $LatestFile -Destination $Destination -ErrorAction Stop    
}
catch {
    Write-Warning "$_"
    Write-Information "Failed to retrieve file from sftp site, exiting script"
    Return
}
try {
    Write-Information "Removing $LatestFile from SFTP site"
    Remove-SFTPItem -SessionId $SFTPSession.SessionId -Path $LatestFile -ErrorAction Stop
    Write-Information "Removed file from sftp site"
}
catch {
    Write-Warning "$_"
    Write-Information "Failed to remove file from sftp site"
}

## Get file and decrypt 
$FilePathPrivate = 'G:\HR Tech\Keys\SECRET.asc'
$FilePath = (Get-ChildItem -Path $Destination -Filter "*.csv" | Sort-Object LastWriteTime -Descending)[0]
$OutputFolderPath = 'G:\HR Tech\DemographicFiles\FromWorkday\Decrypted'
Write-Information "Decrypting file to $OutputFolderPath with a name of $($FilePath.Name)"
try {
    Unprotect-PGP -FilePathPrivate $FilePathPrivate -FilePath $FilePath.FullName -OutFilePath "$OutputFolderPath\$($FilePath.Name)" -ErrorAction Stop 
}
catch {
    Write-Warning "$_"
    Write-Information "Failed to decrypt file, exiting script"
    Return
}

If(Test-Path "$OutputFolderPath\$($FilePath.Name)")
{
    Write-Information "Downloaded and encrypted file"
}
Else
{
    Write-Warning "Failed to get and encrypt file, exiting"
    Return
}
Write-Information "Removing downloaded encrypted file"
Remove-Item $FilePath.FullName -Force

## Run B R Program
Write-Information "Running BR Program to enhance file"
Start-Process "G:\HR Tech\BR Program\Tylin.Workday.CsvWorkerId.ConsoleApp\bin\Release\net6.0\Tylin.Workday.CsvWorkerId.ConsoleApp.exe" -Wait
Write-Information "BR Program finished running"
Write-Information "Removing decrypted file"
Remove-Item "$OutputFolderPath\$($FilePath.Name)" -Force
If(Test-Path "$OutputFolderPath\$($FilePath.Name)")
{
    Write-Warning "Failed to remove decrypted file"
} Else {
    Write-Information "Removed decrypted file"
}

## Upload encrypted file after B R Program
$newDemographics = (Get-ChildItem -Path "G:\HR Tech\DemographicFiles\ToOneDeltek" -File | Sort LastWriteTime -Descending)[0]
## Encrypt file 
Write-Information "Encrypting file"
Protect-PGP -FilePathPublic "G:\HR Tech\Keys\PUBLIC.asc" -FilePath $newDemographics.FullName -OutFilePath "G:\HR Tech\DemographicFiles\ToOneDeltek\Enrypted\$($NewDemographics.Name).pgp"

Write-Information "Removing decrypted file ($NewDemographics.FullName)"
# Delete Unencrypted File 
Remove-Item -Path $NewDemographics.FullName -Force

## Place file from DB server to SFTP server directory
Write-Information "Uploading G:\HR Tech\DemographicFiles\ToOneDeltek\Encrypted\$($NewDemographics.Name).pgp to sftp.tylin.com Destination: /WorkdayVision/Staging/Demographics/Outbound"
Set-SFTPItem -SFTPSession $SFTPSession -Destination '/WorkdayVision/Staging/Demographics/Outbound' -Path "G:\HR Tech\DemographicFiles\ToOneDeltek\Enrypted\$($NewDemographics.Name).pgp"
Remove-Item "G:\HR Tech\DemographicFiles\ToOneDeltek\Enrypted\$($NewDemographics.Name).pgp" -Force
Write-Information "Finished running process, please review log for WARNING, reach out to Mark.Ince@tylin.com or ServiceDesk@tylin.com if further assistance is required"
Stop-Transcript