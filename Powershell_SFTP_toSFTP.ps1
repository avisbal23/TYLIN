## $UrlForStfpSite = 'sftp.tylin.com'
## $TyliWorkdaySFTPCred = Get-Credential

## Load credential
$TyliWorkdaySFTPCred = Import-Clixml -Path "G:\HR Tech\Credentials\sftpCredentials_from_Svc.WorkdayTasks.xml"

## Start SFTP Session
$SFTPSession = New-SFTPSession -ComputerName 'sftp.tylin.com' -Credential $TyliWorkdaySFTPCred -ConnectionTimeout 300

## Get file from DB server
$newDemographics = (Get-ChildItem -Path "G:\HR Tech\DemographicFiles\ToOneDeltek" -File | Sort LastWriteTime -Descending)[0]

## Encrypt file 
Protect-PGP -FilePathPublic "G:\HR Tech\Keys\PUBLIC.asc" -FilePath $newDemographics.FullName -OutFilePath "G:\HR Tech\DemographicFiles\ToOneDeltek\Enrypted\$($NewDemographics.Name).pgp"
# Delete Unencrypted File 
Remove-Item -Path $NewDemographics.FullName -Force

## Place file from DB server to SFTP server directory
Set-SFTPItem -SFTPSession $SFTPSession -Destination '/WorkdayVision/Staging/Demographics/Outbound' -Path "G:\HR Tech\DemographicFiles\ToOneDeltek\Enrypted\$($NewDemographics.Name).pgp"
