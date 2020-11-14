function Connect-O365Session {
    $Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $Credentials -Authentication Basic -AllowRedirection
    Import-PSSession $Session
}

function Remove-O365Session {
    Get-PSSession | Remove-PSSession
}
