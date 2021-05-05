-Command “Set-ExecutionPolicy Unrestricted -Force” >> “%TEMP%\StartupLog.txt” 2>&1



Param
(
    [string]$User,
    [switch]$Update = $False
)

# Email defaults
# TODO Put real info in here
$SMTPServer = "server"
$EmailFrom = "noreply@company.com"
$EmailTo = "myemail@company.com"
$EmailSubject = "MFA Check"
$EmailBody = ""

# See if we have an active connection
$Connections = Get-PSSession | Where-Object {$_.State -eq 'Opened'} | Measure-Object
If ($Connections.Count -eq 0)
{
    C:\Scripts\Connect.ps1
}



If ($User -Ne "")
{
    $Users = Get-MSolUser -UserPrincipalName $User
    $EmailBody += "Single user requested"
}
# checks authentication etc etc
Else
{
    $Users = Get-MsolUser -EnabledFilter EnabledOnly -All | `
            Where-Object {$_.UserType -eq "Member" -And ($_.SignInName -Like "*@domain1.com" -Or `
                            $_.SignInName -Like "*@domain2.com") `
                        -And $_.SignInName -NotLike "admins*@company.com" `
                        -And $_.StrongAuthenticationRequirements.State -EQ 'Enforced'
                        }
    $EmailBody += "Number of enforced users: "
    $EmailBody += $Users.Count
}

$EmailBody += "`n`n"

# If we are updating, change back to 'enabled' not 'enforced'
If (!$Update)
{
    $Users | Select-Object DisplayName, UserPrincipalName, @{N="MFA Status"; E={ $_.StrongAuthenticationRequirements.State}}
    $EmailBody += $Users.DisplayName
}
Else
{

    $AuthenticationRequirements = New-Object "Microsoft.Online.Administration.StrongAuthenticationRequirement"
    $AuthenticationRequirements.RelyingParty = "*"
    $AuthenticationRequirements.State = "Enabled"

    $Users | Set-MSOLUser -StrongAuthenticationRequirements $AuthenticationRequirements

    $EmailBody += $Users.DisplayName

}

# If we found users, fire off the email
If ($Users.Count -GT 0)
{
    Send-MailMessage -SmtpServer $SMTPServer `
                        -From $EmailFrom `
                        -To $EmailTo `
                        -Subject "$EmailSubject" `
                        -Body "$EmailBody" `
                        -BodyAsHtml
    Write-Host Email Sent
}

C:\Scripts\Disconnect.ps1

# lol don't ask..................... :)

# ask for credentials
$cred = Get-Credential
$pass = $cred.Password
$user = $cred.UserName




$from = "example@mail.com" 
$to = "example@mail.com" 
$smtp = "smtpAddress.com" 
$sub = "hi" 
$body = "test mail"
$secpasswd = ConvertTo-SecureString "yourpassword" -AsPlainText -Force
$mycreds = New-Object System.Management.Automation.PSCredential($from, $secpasswd)
Send-MailMessage -To $to -From $from -Subject $sub -Body $body -Credential $mycreds -SmtpServer $smtp -DeliveryNotificationOption Never -BodyAsHtml

shutdown /r 

echo 60

