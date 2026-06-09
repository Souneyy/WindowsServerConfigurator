<#
Naam: Younes Saoudi
Bestand: domainsettingsYSa.psm1
Doel: Module voor de Active Directory en domeinconfiguratie van Windows Server 2025 en de Windows 11 client.
#>

# ================================================================
# HELPER FUNCTIES (Herbruikbare bouwstenen)
# ================================================================

<#
.SYNOPSIS
Schrijft een bericht met datum en tijd naar het centrale logbestand.

.DESCRIPTION
Deze functie controleert of de logboek map aanwezig is, waarna deze map automatisch wordt aangemaakt indien deze ontbreekt. Vervolgens wordt het opgegeven bericht samen met een tijdsaanduiding veilig weggeschreven in het tekstbestand.

.PARAMETER Message
De tekst die in het logbestand moet worden genoteerd.

.PARAMETER ProjectPad
Het basispad naar de hoofdmap van het project, dit wordt standaard berekend.

.EXAMPLE
Write-LogYSa -Message "Start IP configuratie proces..." -ProjectPad $ScriptDir
#>
function Write-LogYSa {
    param(
        [string]$Message,
        [string]$ProjectPad = (Split-Path -Parent $PSScriptRoot)
    )
    
    $logDir = Join-Path $ProjectPad "logs"
    if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory -Force | Out-Null }
    
    $logPath = Join-Path $logDir "InstallatieLogYSa.txt"
    $timestamp = Get-Date -Format "dd-MM-yyyy HH:mm:ss"
    
    "$timestamp #### $Message ####" | Out-File -FilePath $logPath -Append
}

<#
.SYNOPSIS
Controleert een volledig netwerkpad en maakt alle ontbrekende mappen stapsgewijs aan.

.DESCRIPTION
Deze veiligheidsfunctie analyseert de locatienaam, filtert overbodige leestekens eruit en bouwt de mapstructuur van boven naar beneden op binnen de Active Directory omgeving.

.PARAMETER TargetDN
Het volledige pad van de gewenste doellocatie.

.EXAMPLE
$veiligPad = Assert-ADPathExistsYSa -TargetDN "OU=Infrastructuur,OU=Antwerpen,DC=domein,DC=local"
#>
function Assert-ADPathExistsYSa {
    param(
        [string]$TargetDN
    )
    
    if (($TargetDN -replace '\s', '') -eq '' -or $TargetDN -match "^CN=Users") {
        return $TargetDN
    }
    
    $domainDN = (Get-ADDomain).DistinguishedName
    $parts = $TargetDN -split ','
    
    $dcElement = $parts | Where-Object { $_ -match "^DC=" } | Select-Object -First 1
    
    $dcIndex = -1
    for ($i = 0; $i -lt $parts.Count; $i++) {
        if ($parts[$i] -eq $dcElement) {
            $dcIndex = $i
            break
        }
    }
 
    if ($dcIndex -lt 0) { return $domainDN }
    
    $currentPath = $parts[$dcIndex..($parts.Count - 1)] -join ','
    
    for ($i = $dcIndex - 1; $i -ge 0; $i--) {
        $currentPart = $parts[$i] -replace '^\s+|\s+$', ''
        if ($currentPart -match "^OU=(.+)$") {
            $ouName = $Matches[1] -replace '^\s+|\s+$', ''
            
            $checkDN = "$currentPart,$currentPath"
            
            $ouExists = $true
            try {
                $null = Get-ADOrganizationalUnit -Identity $checkDN -ErrorAction Stop
            } catch {
                $ouExists = $false
            }
            
            if (-not $ouExists) {
                try {
                    New-ADOrganizationalUnit -Name $ouName -Path $currentPath | Out-Null
                    Write-Host " -> Map automatisch aangemaakt: $ouName" -ForegroundColor Green
                    Write-LogYSa "Map automatisch aangemaakt: $checkDN"
                } catch {
                    Write-Warning " -> Kon map $ouName niet aanmaken op pad $currentPath."
                    Write-LogYSa "Fout bij aanmaken map: $checkDN"
                }
            }
            $currentPath = $checkDN
        }
    }
    return $currentPath
}

# ================================================================
# HOOFDFUNCTIES
# ================================================================

<#
.SYNOPSIS
Installeert de benodigde Active Directory serverrollen en beheertools.

.DESCRIPTION
De functie verifieert eerst of de functionaliteit al aanwezig is, waarna de servercomponenten automatisch en zonder verdere interactie worden geïnstalleerd.

.EXAMPLE
Install-ADRoleYSa
#>
function Install-ADRoleYSa {
    Clear-Host
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host "        ACTIVE DIRECTORY ROLLEN INSTALLEREN       " -ForegroundColor White
    Write-Host "==================================================" -ForegroundColor Cyan
    
    Write-Host " -> Controleer of AD DS al geïnstalleerd is..." -ForegroundColor Cyan
    $adRole = Get-WindowsFeature -Name AD-Domain-Services
    
    if ($adRole.Installed) {
        Write-Host " -> De Active Directory rol is al geïnstalleerd op deze server." -ForegroundColor Green
        Write-LogYSa "Controle: AD DS rol is reeds geïnstalleerd."
    } else {
        Write-Host " -> Start met de installatie van Active Directory Domain Services..." -ForegroundColor Yellow
        Write-LogYSa "Start installatie van AD DS rollen..."
        try {
            Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
            Write-Host " -> De installatie van de AD rollen is succesvol afgerond!" -ForegroundColor Green
            Write-LogYSa "Installatie van AD DS rollen succesvol voltooid."
        } catch {
            Write-Error " -> Er is een fout opgetreden tijdens de installatie: $_"
            Write-LogYSa "Fout tijdens installatie AD DS rollen: $_"
        }
    }
}

<#
.SYNOPSIS
Promoveert de server tot een actieve Domain Controller op het netwerk.

.DESCRIPTION
Via een voorgaande netwerkcontrole wordt bepaald of het netwerk al bestaat, waarna de server als toevoeging of als compleet nieuw netwerkhoofd wordt geconfigureerd.

.PARAMETER DomeinNaam
De gewenste domeinnaam van het netwerk.

.EXAMPLE
Promote-DomainControllerYSa -DomeinNaam "sveagles.local"
#>
function Promote-DomainControllerYSa {
    param([string]$DomeinNaam)
    
    Clear-Host
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host "      SERVER PROMOVEREN TOT DOMAIN CONTROLLER     " -ForegroundColor White
    Write-Host "==================================================" -ForegroundColor Cyan
    
    if (($DomeinNaam -replace '\s', '') -eq '') {
        Write-Warning " -> Er is geen domeinnaam doorgegeven. Promotie wordt geannuleerd."
        return
    }

    Write-Host " -> De server wordt gepromoveerd voor het domein: $DomeinNaam" -ForegroundColor Cyan
    Write-Host " -> LET OP: Je zult zo dadelijk een wachtwoord moeten ingeven voor de Directory Services Restore Mode." -ForegroundColor Yellow
    
    $domainExists = $false
    try {
        $dnsCheck = Resolve-DnsName -Name "_ldap._tcp.dc._msdcs.$DomeinNaam" -Type SRV -ErrorAction Stop
        if ($null -ne $dnsCheck) { $domainExists = $true }
    } catch {
        $domainExists = $false
    }

    try {
        if ($domainExists) {
            Write-Host " -> Het domein '$DomeinNaam' bestaat al. Server wordt toegevoegd als extra Domain Controller..." -ForegroundColor Yellow
            Write-LogYSa "Domein $DomeinNaam bestaat reeds. Start toevoegen extra Domain Controller..."
            Install-ADDSDomainController -DomainName $DomeinNaam -Force
        } else {
            Write-Host " -> Het domein '$DomeinNaam' bestaat nog niet. Een nieuw forest wordt aangemaakt..." -ForegroundColor Green
            Write-LogYSa "Domein $DomeinNaam bestaat niet. Start aanmaken van een nieuw forest..."
            Install-ADDSForest -DomainName $DomeinNaam -InstallDns -Force
        }
    } catch {
        Write-Error " -> Fout tijdens het promoveren van de server: $_"
        Write-LogYSa "Fout tijdens het promoveren: $_"
    }
}

<#
.SYNOPSIS
Importeert locatiemappen in Active Directory op basis van een gespecificeerd databestand.

.DESCRIPTION
De functie leest de gegevens uit het bestand, bouwt de juiste paden op en plaatst de organisatorische eenheden veilig in de Active Directory database.

.PARAMETER ProjectPad
Het basispad naar de projectmap.

.PARAMETER BestandsNaam
De naam van het bestand met de locatiegegevens.

.EXAMPLE
Import-ADOUsYSa -ProjectPad $ScriptDir -BestandsNaam "ous.csv"
#>
function Import-ADOUsYSa {
    param(
        [string]$ProjectPad = (Split-Path -Parent $PSScriptRoot),
        [string]$BestandsNaam = "ous.csv"
    )
    
    $file = Join-Path $ProjectPad "settings\$BestandsNaam"
    
    if (-not (Test-Path $file)) { Write-Warning " -> FOUTCATEGORIE: Kan $BestandsNaam niet vinden in de settings map!"; return }

    Write-Host " -> Start met het importeren van mappen..." -ForegroundColor Cyan
    Write-LogYSa "Start met het importeren van Organizational Units..."
    
    $domainDN = (Get-ADDomain).DistinguishedName
    
    Import-Csv $file -Delimiter ";" | ForEach-Object {
        $ouName = $_.Name
        $ouPathRaw = $_.Path
        
        if (($ouName -replace '\s', '') -ne '') {
            if (($ouPathRaw -replace '\s', '') -eq '') {
                $fullPath = "OU=$ouName,$domainDN"
            } elseif ($ouPathRaw -match "DC=") {
                $fullPath = "OU=$ouName,$ouPathRaw"
            } else {
                $ouParts = $ouPathRaw -split ',' | ForEach-Object { "OU=$($_ -replace '^\s+|\s+$', '')" }
                $ouString = $ouParts -join ','
                $fullPath = "OU=$ouName,$ouString,$domainDN"
            }
            
            $resultDN = Assert-ADPathExistsYSa -TargetDN $fullPath
            if ($null -ne $resultDN) {
                Write-Host " -> Map '$ouName' succesvol gecontroleerd of aangemaakt." -ForegroundColor Green
            }
        }
    }
}

<#
.SYNOPSIS
Importeert beveiligingsgroepen vanuit het gespecificeerde databestand.

.DESCRIPTION
De groepen worden ingelezen, gecontroleerd op locatie en automatisch ingedeeld met het juiste bereik binnen het Active Directory netwerk.

.PARAMETER ProjectPad
Het basispad naar de projectmap.

.PARAMETER BestandsNaam
De naam van het bestand met de beveiligingsgroepen.

.EXAMPLE
Import-ADGroupsYSa -ProjectPad $ScriptDir -BestandsNaam "securitygroups.csv"
#>
function Import-ADGroupsYSa {
    param(
        [string]$ProjectPad = (Split-Path -Parent $PSScriptRoot),
        [string]$BestandsNaam = "securitygroups.csv"
    )
    
    $file = Join-Path $ProjectPad "settings\$BestandsNaam"
    
    if (-not (Test-Path $file)) { Write-Warning " -> FOUTCATEGORIE: Kan $BestandsNaam niet vinden!"; return }

    Write-Host " -> Start met het importeren van Security Groepen..." -ForegroundColor Cyan
    Write-LogYSa "Start met het importeren van Security Groepen..."
    
    $domainDN = (Get-ADDomain).DistinguishedName

    Import-Csv $file -Delimiter ";" | ForEach-Object {
        $groupName = $_.GroepNaam  
        $ouName = $_.ou            
        
        if ($null -ne $groupName -and ($groupName -replace '\s', '') -ne '') {
            
            $groupPath = "OU=$ouName,$domainDN"
            $null = Assert-ADPathExistsYSa -TargetDN $groupPath
            
            $groupScope = "Global"
            if ($groupName -like "DL_*") { $groupScope = "DomainLocal" }

            try {
                if (-not (Get-ADGroup -Filter "Name -eq '$groupName'" -ErrorAction SilentlyContinue)) {
                    New-ADGroup -Name $groupName -Path $groupPath -GroupScope $groupScope -GroupCategory Security
                    Write-Host " -> Groep '$groupName' succesvol aangemaakt in $ouName." -ForegroundColor Green
                    Write-LogYSa "Security group aangemaakt: $groupName"
                } else {
                    Write-Host " -> Groep '$groupName' bestaat al." -ForegroundColor Yellow
                }
            } catch {
                Write-Warning " -> Fout bij het aanmaken van groep '$groupName'."
            }
        }
    }
}

<#
.SYNOPSIS
Importeert gebruikers en hun lidmaatschappen vanuit het gespecificeerde gegevensbestand.

.DESCRIPTION
Deze uitgebreide functie maakt de gebruikers aan, configureert hun persoonlijke mappen op de server, stelt een veilig standaardwachtwoord in en voegt hen direct toe aan de juiste beveiligingsgroepen.

.PARAMETER ProjectPad
Het basispad naar de projectmap.

.PARAMETER BestandsNaam
De naam van het bestand met de gebruikersgegevens.

.EXAMPLE
Import-ADUsersFromJsonYSa -ProjectPad $ScriptDir -BestandsNaam "users.json"
#>
function Import-ADUsersFromJsonYSa {
    param(
        [string]$ProjectPad = (Split-Path -Parent $PSScriptRoot),
        [string]$BestandsNaam = "users.json"
    )
    
    $jsonFile = Join-Path $ProjectPad "settings\$BestandsNaam"
    $xmlFile = Join-Path $ProjectPad "settings\Domain.Settings.xml"
    
    if (-not (Test-Path $jsonFile)) { Write-Warning " -> FOUTCATEGORIE: Kan $BestandsNaam niet vinden!"; return }
    if (-not (Test-Path $xmlFile)) { Write-Warning " -> FOUTCATEGORIE: Kan Domain.Settings.xml niet vinden!"; return }

    [xml]$domainXml = Get-Content -Path $xmlFile -Raw
    $domeinNaam = $domainXml.Settings.Domain.domainname
    $defaultPasswordText = $domainXml.Settings.UserSettings.defaultPassword
    $securePassword = ConvertTo-SecureString $defaultPasswordText -AsPlainText -Force
    
    $homeDrive = $domainXml.Settings.UserSettings.homedrive
    $homeDirectoryBase = $domainXml.Settings.UserSettings.homedirectory
    $profilePathBase = $domainXml.Settings.UserSettings.profilepath

    Write-Host " -> Start met het importeren van Gebruikers via JSON..." -ForegroundColor Cyan
    
    $jsonData = Get-Content -Path $jsonFile -Raw | ConvertFrom-Json
    $domainDN = (Get-ADDomain).DistinguishedName
    
    foreach ($user in $jsonData.users) {
        $samAccount = $user.login
        $firstName = $user.firstName
        $lastName = $user.lastName
        $ouName = $user.ou
        $upn = "$samAccount@$domeinNaam"
        
        if (($samAccount -replace '\s', '') -eq '') { continue }

        $userHome = ""
        $userProfile = ""
        
        if ($null -ne $homeDirectoryBase -and ($homeDirectoryBase -replace '\s', '') -ne '') {
            $userHome = Join-Path $homeDirectoryBase $samAccount
        }
        if ($null -ne $profilePathBase -and ($profilePathBase -replace '\s', '') -ne '') {
            $userProfile = Join-Path $profilePathBase $samAccount
        }

        $targetDN = "OU=$ouName,$domainDN"
        $fullPath = Assert-ADPathExistsYSa -TargetDN $targetDN
        
        if (-not (Get-ADUser -Filter "SamAccountName -eq '$samAccount'" -ErrorAction SilentlyContinue)) {
            
            $adUserParams = @{
                SamAccountName = $samAccount
                UserPrincipalName = $upn
                Name = "$firstName $lastName"
                GivenName = $firstName
                Surname = $lastName
                Path = $fullPath
                AccountPassword = $securePassword
                Enabled = $true
                PasswordNeverExpires = $true
            }
            
            if ($null -ne $homeDrive -and ($homeDrive -replace '\s', '') -ne '') { 
                $adUserParams.HomeDrive = $homeDrive 
            }
            if ($userHome -ne '') { 
                $adUserParams.HomeDirectory = $userHome
                if (-not (Test-Path $userHome)) { New-Item -Path $userHome -ItemType Directory -Force | Out-Null }
            }
            if ($userProfile -ne '') { 
                $adUserParams.ProfilePath = $userProfile
                if (-not (Test-Path $userProfile)) { New-Item -Path $userProfile -ItemType Directory -Force | Out-Null }
            }

            New-ADUser @adUserParams
            Write-Host " -> Gebruiker '$samAccount' succesvol aangemaakt in '$ouName'." -ForegroundColor Green
            
            if ($null -ne $user.securityGroups) {
                foreach ($group in $user.securityGroups) {
                    if ($null -eq $group -or ($group -replace '\s', '') -eq '') { continue }
                  
                    $checkGroup = Get-ADGroup -Filter "Name -eq '$group'" -ErrorAction SilentlyContinue
                    
                    if ($null -eq $checkGroup) {
                        Write-Host "    -> Groep '$group' bestond niet en wordt nu aangemaakt..." -ForegroundColor Yellow
                        
                        $scope = "Global"
                        if ($group -like "DL_*") { $scope = "DomainLocal" }
                        
                        New-ADGroup -Name $group -Path $domainDN -GroupScope $scope -GroupCategory Security
                    }

                    Add-ADGroupMember -Identity $group -Members $samAccount -ErrorAction SilentlyContinue
                    Write-Host "    -> Toegevoegd aan groep: $group" -ForegroundColor DarkGreen
                }
            }
        } else {
            Write-Host " -> Gebruiker '$samAccount' bestaat al." -ForegroundColor DarkYellow
        }
    }
}

<#
.SYNOPSIS
Koppelt de Windows computer aan het Active Directory domein.

.DESCRIPTION
De functie controleert eerst of het doeldomein bereikbaar is, waarna de computer met de juiste administratorrechten en zonder extra foutmeldingen in het domein wordt geplaatst.

.PARAMETER ProjectPad
Het basispad naar de projectmap.

.PARAMETER DomainCredential
Een beveiligd inlogobject met de administratorrechten.

.EXAMPLE
Join-DomainYSa -ProjectPad $ScriptDir -DomainCredential $script:SessionCred
#>
function Join-DomainYSa {
    param(
        [string]$ProjectPad = (Split-Path -Parent $PSScriptRoot),
        [System.Management.Automation.PSCredential]$DomainCredential
    )
    
    Clear-Host
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host "             KOPPELEN AAN HET DOMEIN              " -ForegroundColor White
    Write-Host "==================================================" -ForegroundColor Cyan
    
    $domainXmlPath = Join-Path $ProjectPad "settings\Domain.Settings.xml"
    
    if (Test-Path $domainXmlPath) {
        [xml]$domainXml = Get-Content -Path $domainXmlPath -Raw
        $domeinNaam = $domainXml.Settings.Domain.domainname
        
        Write-Host " -> Domeinnaam '$domeinNaam' succesvol ingelezen!" -ForegroundColor Green
        Write-Host " -> Controleer de netwerkverbinding met het domein..." -ForegroundColor Cyan
        
        if (-not (Test-Connection -ComputerName $domeinNaam -Count 1 -Quiet)) {
            Write-Warning " -> Kan het domein '$domeinNaam' niet bereiken. Controleer de DNS instellingen!"
            return
        }
        
        # Als er geen wachtwoord via de parameter komt, vraag het dan veilig lokaal op
        if ($null -eq $DomainCredential) {
            Write-Host " -> Het domein is bereikbaar. Voer de inloggegevens in van de Domain Admin." -ForegroundColor Green
            $DomainCredential = Get-Credential -UserName "Administrator" -Message "Domein administratie inloggegevens"
        }
        
        Write-LogYSa "Start met het koppelen van de client aan domein $domeinNaam..."
        
        try {
            Write-Host " -> Bezig met het joinen van het domein. De computer zal hierna automatisch herstarten!" -ForegroundColor Cyan
            Add-Computer -DomainName $domeinNaam -Credential $DomainCredential -Restart -Force
        } catch {
            Write-Error " -> Fout tijdens het toevoegen aan het domein: $_"
            Write-LogYSa "Fout tijdens domain join: $_"
        }
    } else {
        Write-Warning " -> KRITISCHE FOUT: Kan het configuratiebestand Domain.Settings.xml niet vinden."
    }
}