<#
  Check W32 Time Source and Configuration Report

  This script will test the connection to each servers and allows for
  the following errors:
  - Access is denied
  - The procedure number is out of range
  - The RPC server is unavailable

  Release 1.0 Written by Jeremy@jhouseconsulting.com 20th November 2013
#>

#-------------------------------------------------------------
# Get the script path
$ScriptPath = { Split-Path $MyInvocation.ScriptName }
$OnlineFile = $(&$ScriptPath) + "\W32TimeSource-online.csv"
$OfflineFile = $(&$ScriptPath) + "\W32TimeSource-offline.csv"

#-------------------------------------------------------------

Import-Module ActiveDirectory 

# Get Domain Controllers
#$Computers = Get-ADDomainController -Filter * | Sort-Object Name

# Get All Servers
$Computers = Get-ADComputer -Filter * -Properties Name, Operatingsystem | Where-Object { $_.Operatingsystem -like "*server*" } | Sort-Object Name

#-------------------------------------------------------------

$onlinearray = @()
$offlinearray = @()

ForEach ($Computer in $Computers) {
    $ComputerError = "$false"
    if (Test-Connection -Cn $Computer.Name -BufferSize 16 -Count 1 -ea 0 -quiet) {
        Write-Host -ForegroundColor Green "Checking time source and configuration of"($Computer.Name)

        $TimeSource = w32tm /query /computer:$($Computer.Name) /source
        If ($TimeSource -notmatch "The following error occurred") {
            $TimeSource = $TimeSource.Trim()
        }
        Else {
            $ComputerError = "$true"
            $ErrorDescription = $TimeSource
            Write-Host -ForegroundColor Red "There was an error contacting"($Computer.Name)
        }
        $TimeConfiguration = w32tm /query /computer:$($Computer.Name) /configuration /verbose
        If ($TimeConfiguration -notmatch "The following error occurred") {
            $AnnounceFlags = $TimeConfiguration | Select-String -pattern "AnnounceFlags:"
            $AnnounceFlags = $AnnounceFlags.ToString().Split("(")
            $AnnounceFlags = $AnnounceFlags[0].ToString().Split(":")
            $AnnounceFlags = $AnnounceFlags[1].Trim()
            $Type = $TimeConfiguration | Select-String -pattern "Type:"
            $Type = $Type.ToString().Split("(")
            $Type = $Type[0].ToString().Split(":")
            $Type = $Type[1].Trim()
            $NtpServer = $TimeConfiguration | Select-String -pattern "NtpServer:"
            $NtpServer = $NtpServer.ToString().Split("(")
            $NtpServer = $NtpServer[0].ToString().Split(":")
            $NtpServer = $NtpServer[1].Trim()
            If ($NtpServer -eq "") { $NtpServer = "Undefined or NotUsed" }

            $output = New-Object PSObject
            $output | Add-Member NoteProperty -Name "ComputerName" $Computer.Name
            $output | Add-Member NoteProperty -Name "TimeSource" $TimeSource
            $output | Add-Member NoteProperty -Name "Type" $Type
            $output | Add-Member NoteProperty -Name "AnnounceFlags" $AnnounceFlags
            $output | Add-Member NoteProperty -Name "NtpServer" $NtpServer
            $onlinearray += $output
        }
        Else {
            $ComputerError = "$true"
            $ErrorDescription = $TimeConfiguration
            Write-Host -ForegroundColor Red "There was an error contacting"($Computer.Name)
        }
    }
    Else {
        $ComputerError = "$true"
        $ErrorDescription = "Unable to ping server"
        Write-Host -ForegroundColor Red ($Computer.Name)"is offline"
    }
    if ($ComputerError -eq $true) {
        $outputbad = New-Object PSObject
        $outputbad | Add-Member NoteProperty ComputerName $Computer.Name
        $outputbad | Add-Member NoteProperty ErrorDescription $ErrorDescription
        $offlinearray += $outputbad
    }
}
$onlinearray | Export-Csv -notype "$OnlineFile" -Delimiter ';'
$offlinearray | Export-Csv -notype "$OfflineFile"

# Remove the quotes
(Get-Content "$OnlineFile") | ForEach-Object { $_ -replace '"', "" } | Out-File "$OnlineFile" -Force -Encoding ascii
(Get-Content "$OfflineFile") | ForEach-Object { $_ -replace '"', "" } | out-file "$OfflineFile" -Force -Encoding ascii
