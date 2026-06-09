<#
Naam: Younes Saoudi
Bestand: algemeenYSa.psm1
Doel: Module voor de basisconfiguratie van Windows Server 2025 en Windows 11.
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
Activeert de automatische aanmelding via het register voor Winlogon.

.DESCRIPTION
Door het aanpassen van specifieke registersleutels zorgt deze functie ervoor dat de computer na een herstart automatisch inlogt met het opgegeven account, wat cruciaal is voor een ononderbroken installatieproces.

.PARAMETER UserName
De gebruikersnaam voor de automatische aanmelding.

.PARAMETER Password
Het bijbehorende wachtwoord dat in het register wordt opgeslagen.

.EXAMPLE
Enable-AutoLogonYSa -UserName "Administrator" -Password "GeheimWachtwoord"
#>
function Enable-AutoLogonYSa {
    param(
        [string]$UserName,
        [string]$Password
    )
    $regWinLogon = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
    Set-ItemProperty -Path $regWinLogon -Name "DefaultUserName" -Value $UserName
    Set-ItemProperty -Path $regWinLogon -Name "DefaultPassword" -Value $Password
    Set-ItemProperty -Path $regWinLogon -Name "AutoAdminLogon" -Value "1"
    
    Write-LogYSa "Automatische aanmelding geconfigureerd voor gebruiker $UserName."
}

<#
.SYNOPSIS
Schakelt de automatische aanmelding uit via het register en wist het wachtwoord uit veiligheid.

.DESCRIPTION
Deze functie verwijdert het opgeslagen wachtwoord uit het register en zet de automatische aanmelding uit, zodat de computer onmiddellijk weer veilig is afgeschermd na afronding van de taken.

.EXAMPLE
Disable-AutoLogonYSa
#>
function Disable-AutoLogonYSa {
    try {
        $regWinLogon = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
        Set-ItemProperty -Path $regWinLogon -Name "AutoAdminLogon" -Value "0"
        Remove-ItemProperty -Path $regWinLogon -Name "DefaultPassword" -ErrorAction SilentlyContinue
        Write-LogYSa "Automatische aanmelding is succesvol en veilig uitgeschakeld."
    } catch {
        Write-LogYSa "Fout bij het uitschakelen van automatische aanmelding: $_"
    }
}

<#
.SYNOPSIS
Stelt een eenmalige taak in via RunOnce om een script na de herstart te hervatten.

.DESCRIPTION
Deze functie plaatst een verwijzing naar het hoofdscript in de RunOnce registersleutel, hierdoor opent PowerShell automatisch opnieuw zodra de Windows sessie na een herstart is geladen.

.PARAMETER ScriptPath
Het volledige pad naar het bestand MenuYSa.ps1.

.EXAMPLE
Set-RunOnceScriptYSa -ScriptPath "C:\scripting\MenuYSa.ps1"
#>
function Set-RunOnceScriptYSa {
    param(
        [string]$ScriptPath
    )
    $runOnceValue = "powershell.exe -ExecutionPolicy Bypass -NoExit -File `"$ScriptPath`""
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" -Name "ResumeScript" -Value $runOnceValue
    
    Write-LogYSa "RunOnce succesvol ingesteld om het script te hervatten na een herstart."
}

<#
.SYNOPSIS
Maakt een nieuwe map aan en controleert of deze al bestaat.

.DESCRIPTION
Er wordt geverifieerd of een specifiek mappad al aanwezig is op de lokale schijf, waarna de map alleen wordt aangemaakt als deze daadwerkelijk ontbreekt om overschrijving te voorkomen.

.PARAMETER FolderPath
Het volledige doellocatie pad voor de nieuwe map.

.EXAMPLE
New-DirectoryYSa -FolderPath "C:\Infrastructuur\Data"
#>
function New-DirectoryYSa {
    param(
        [string]$FolderPath
    )
    if (-not (Test-Path $FolderPath)) {
        New-Item -Path $FolderPath -ItemType Directory -Force | Out-Null
        Write-Host " -> Map succesvol aangemaakt: $FolderPath" -ForegroundColor Green
        Write-LogYSa "Map aangemaakt: $FolderPath"
    } else {
        Write-Host " -> Map bestaat reeds: $FolderPath" -ForegroundColor Yellow
        Write-LogYSa "Map bestond al: $FolderPath"
    }
}

# ================================================================
# HOOFDFUNCTIES
# ================================================================

<#
.SYNOPSIS
Leest de computerinstellingen in vanuit het configuratiebestand.

.DESCRIPTION
Deze functie zoekt het XML bestand in de instellingen map, waarna de gegevens worden gevalideerd en ingeladen voor verder gebruik in het hoofdscript.

.PARAMETER ProjectPad
Het basispad naar de projectmap.

.EXAMPLE
$xmlData = Get-ComputerSettingsYSa -ProjectPad $ScriptDir
#>
function Get-ComputerSettingsYSa {
    param(
        [string]$ProjectPad = (Split-Path -Parent $PSScriptRoot)
    )
    
    $xmlPath = Join-Path $ProjectPad "settings\Computer.settings.xml"
    
    if (Test-Path $xmlPath) {
        [xml]$settings = Get-Content -Path $xmlPath -Raw
        Write-LogYSa "XML instellingen succesvol geladen."
        return $settings
    } else {
        Write-Error "KRITISCHE FOUT: Kan het instellingenbestand niet vinden op pad: $xmlPath"
        return $null
    }
}

<#
.SYNOPSIS
Wijzigt de computernaam en kan de herstart overslaan met een specifieke optie.

.DESCRIPTION
De lokale computernaam wordt vergeleken met de gewenste nieuwe naam, waarna de naamswijziging wordt doorgevoerd. De functie forceert standaard een herstart, tenzij dit expliciet wordt geblokkeerd.

.PARAMETER NewName
De gewenste nieuwe naam voor de computer.

.PARAMETER NoRestart
Een vlag die voorkomt dat de computer direct na de naamswijziging opnieuw opstart.

.EXAMPLE
Set-ComputerNameYSa -NewName "ClientYSa" -NoRestart
#>
function Set-ComputerNameYSa {
    param(
        [string]$NewName,
        [switch]$NoRestart
    )
    
    $currentName = $env:COMPUTERNAME
    if ($currentName -eq $NewName) {
        Write-Host " -> De computer heet al $NewName." -ForegroundColor Green
        return
    }

    Write-Host " -> Computernaam wordt gewijzigd van $currentName naar $NewName..." -ForegroundColor Cyan
    Write-LogYSa "Start renaming computer van $currentName naar $NewName..."

    Rename-Computer -NewName $NewName -Force
    Write-LogYSa "Computer hernoemd naar $NewName."
    
    if (-not $NoRestart) {
        Write-Host " -> Herstarten in 3 seconden..." -ForegroundColor Green
        Start-Sleep -Seconds 3
        Restart-Computer -Force
    } else {
        Write-Host " -> Computernaam is lokaal gewijzigd. (Wordt pas actief na de domeinkoppeling en herstart!)" -ForegroundColor Yellow
    }
}

<#
.SYNOPSIS
Stelt de netwerkconfiguratie in op basis van het hardware adres uit de instellingen.

.DESCRIPTION
Deze functie configureert statische IP adressen, subnet prefixen, gateways en DNS servers op de netwerkkaart die perfect overeenkomt met het opgegeven hardware adres.

.PARAMETER ProjectPad
Het basispad naar de projectmap.

.EXAMPLE
Set-IPConfigurationYSa -ProjectPad $ScriptDir
#>
function Set-IPConfigurationYSa {
    param(
        [string]$ProjectPad = (Split-Path -Parent $PSScriptRoot)
    )
    
    $settings = Get-ComputerSettingsYSa -ProjectPad $ProjectPad
    if ($null -eq $settings) { return }
    
    Write-Host " -> Start met het instellen van de IP configuratie..." -ForegroundColor Cyan
    Write-LogYSa "Start IP configuratie proces..."

    foreach ($adapter in $settings.Settings.networksettings.networkadapter) {
        if ($adapter.dhcpenabled -eq 'false') {
            $mac = $adapter.macaddress
            $ip = $adapter.ip
            $prefix = $adapter.prefixlength
            $gw = $adapter.gateway
            $dns = $adapter.dns
            
            $netAdapter = Get-NetAdapter | Where-Object { ($_.MacAddress -replace '-','') -eq ($mac -replace '-','') }
            
            if ($null -ne $netAdapter) {
                Write-Host " -> Netwerkkaart $($netAdapter.Name) gevonden. IP $ip wordt ingesteld..." -ForegroundColor Green
                
                Set-NetIPInterface -InterfaceAlias $netAdapter.Name -Dhcp Disabled
                Remove-NetIPAddress -InterfaceAlias $netAdapter.Name -Confirm:$false -ErrorAction SilentlyContinue
                Remove-NetRoute -InterfaceAlias $netAdapter.Name -AddressFamily IPv4 -Confirm:$false -ErrorAction SilentlyContinue
                
                New-NetIPAddress -InterfaceAlias $netAdapter.Name -IPAddress $ip -PrefixLength $prefix -DefaultGateway $gw -AddressFamily IPv4 | Out-Null
                Set-DnsClientServerAddress -InterfaceAlias $netAdapter.Name -ServerAddresses $dns
                
                Write-LogYSa "Statisch IP en DNS ingesteld voor netwerkkaart $($netAdapter.Name)."
            } else {
                Write-Warning " -> Geen netwerkkaart gevonden met MAC adres $mac."
                Write-LogYSa "Fout: MAC adres $mac niet gevonden."
            }
        }
    }
    Write-Host " -> Netwerkconfiguratie afgerond." -ForegroundColor Green
    Write-LogYSa "IP configuratie voltooid."
}

<#
.SYNOPSIS
Genereert automatisch de lokale mappenstructuur op basis van een tekstbestand.

.DESCRIPTION
De functie leest het opgegeven tekstbestand regel voor regel uit, waarna alle lege ruimtes worden verwijderd en de mappen op de lokale schijf worden opgebouwd.

.PARAMETER ProjectPad
Het basispad naar de projectmap.

.PARAMETER BestandsNaam
De naam van het tekstbestand met de mapnamen.

.EXAMPLE
Create-FoldersYSa -ProjectPad $ScriptDir -BestandsNaam "mappen.txt"
#>
function Create-FoldersYSa {
    param(
        [string]$ProjectPad = (Split-Path -Parent $PSScriptRoot),
        [string]$BestandsNaam = "mappen.txt"
    )
    
    $file = Join-Path $ProjectPad "settings\$BestandsNaam"
    
    if (-not (Test-Path $file)) { Write-Warning " -> FOUTCATEGORIE: Kan $BestandsNaam niet vinden op pad: $file"; return }

    Write-LogYSa "Start met het inlezen van de mapstructuur..."
    
    Get-Content $file | ForEach-Object {
        $line = $_ -replace '^\s+|\s+$', ''
        if (($line -replace '\s', '') -ne '') {
            New-DirectoryYSa -FolderPath $line
        }
    }
}

<#
.SYNOPSIS
Maakt de gedeelde netwerkmappen aan op basis van een databestand.

.DESCRIPTION
Deze functie controleert eerst of de computer al lid is van een domein, waarna de mappen worden gepubliceerd als gedeelde shares met de juiste netwerktoegang.

.PARAMETER ProjectPad
Het basispad naar de projectmap.

.PARAMETER BestandsNaam
De naam van het databestand met de share gegevens.

.EXAMPLE
Create-SharesYSa -ProjectPad $ScriptDir -BestandsNaam "shares.csv"
#>
function Create-SharesYSa {
    param(
        [string]$ProjectPad = (Split-Path -Parent $PSScriptRoot),
        [string]$BestandsNaam = "shares.csv"
    )
    
    $file = Join-Path $ProjectPad "settings\$BestandsNaam"
    
    if (-not (Test-Path $file)) { Write-Warning " -> FOUTCATEGORIE: Kan $BestandsNaam niet vinden op pad: $file"; return }

    Write-LogYSa "Start met het configureren van de shares..."
    
    $sysInfo = Get-CimInstance Win32_ComputerSystem
    if (-not $sysInfo.PartOfDomain) {
        Write-Warning " -> [GEANNULEERD] Deze server is nog geen Domain Controller, mist de AD tools, of de computer behoort niet tot een domein!"
        Write-Warning " -> Netwerkshares worden veilig overgeslagen in de basisconfiguratie."
        Write-LogYSa "Shares aanmaken overgeslagen omdat het systeem in een werkgroep zit."
        return
    }
    
    Import-Csv $file -Delimiter ";" | ForEach-Object {
        $path = $_.map        
        $shareName = $_.share 
        
        if ($null -eq $shareName -or ($shareName -replace '\s', '') -eq '' -or $null -eq $path -or ($path -replace '\s', '') -eq '') { return }
        
        New-DirectoryYSa -FolderPath $path
        
        if (-not (Get-SmbShare -Name $shareName -ErrorAction SilentlyContinue)) {
            New-SmbShare -Name $shareName -Path $path -FullAccess "Everyone" | Out-Null
            Write-Host " -> Share aangemaakt: $shareName" -ForegroundColor Green
            Write-LogYSa "Nieuwe share aangemaakt met de naam $shareName."
        } else {
            Write-Host " -> Share $shareName bestaat al." -ForegroundColor Yellow
        }
    }
    Write-Host " -> Alle netwerkshares zijn succesvol gedeeld!" -ForegroundColor Green
}

<#
.SYNOPSIS
Stelt de beveiligingsrechten in op de gecreëerde bestanden en mappen.

.DESCRIPTION
Na een controle op de beschikbaarheid van de Active Directory omgeving, leest de functie het bestand uit en wijst het de vereiste leesrechten of schrijfrechten toe aan de domeingroepen.

.PARAMETER ProjectPad
Het basispad naar de projectmap.

.PARAMETER BestandsNaam
De naam van het databestand met de rechten.

.EXAMPLE
Set-NTFSPermissionsYSa -ProjectPad $ScriptDir -BestandsNaam "rechten.csv"
#>
function Set-NTFSPermissionsYSa {
    param(
        [string]$ProjectPad = (Split-Path -Parent $PSScriptRoot),
        [string]$BestandsNaam = "rechten.csv"
    )
    
    $file = Join-Path $ProjectPad "settings\$BestandsNaam"
    
    if (-not (Test-Path $file)) { Write-Warning " -> FOUTCATEGORIE: Kan $BestandsNaam niet vinden op pad: $file"; return }

    Write-LogYSa "Start met het toekennen van de toegangsrechten..."
    
    try {
        $domainDN = (Get-ADDomain -ErrorAction Stop).DistinguishedName
    } catch {
        Write-Warning " -> [GEANNULEERD] Deze server is nog geen Domain Controller, mist de AD tools, of de computer behoort niet tot een domein!"
        Write-Warning " -> NTFS rechten voor domeingroepen worden veilig overgeslagen in de basisconfiguratie."
        Write-LogYSa "Rechten instellen overgeslagen: Active Directory is niet beschikbaar."
        return
    }
    
    Import-Csv $file -Delimiter ";" | ForEach-Object {
        $path = $_.map
        $group = $_.Groep
        $rightsRaw = $_.NTFS_permission
        
        if ($null -eq $path -or ($path -replace '\s', '') -eq '') { return }
        
        if (Test-Path $path) {
            $checkGroup = Get-ADGroup -Filter "Name -eq '$group'" -ErrorAction SilentlyContinue
            
            if ($null -eq $checkGroup) {
                Write-Host " -> Groep '$group' bestond niet! Deze wordt nu automatisch aangemaakt..." -ForegroundColor Yellow
                
                $scope = "Global"
                if ($group -like "DL_*") { $scope = "DomainLocal" }
                
                try {
                    New-ADGroup -Name $group -Path $domainDN -GroupScope $scope -GroupCategory Security
                    Write-LogYSa "Ontbrekende groep '$group' automatisch aangemaakt."
                } catch {
                    Write-Warning " -> Kon groep '$group' niet aanmaken. Rechten instellen zal waarschijnlijk falen."
                }
            }

            $ntfsRight = "ReadAndExecute"
            if ($rightsRaw -eq "modify") { $ntfsRight = "Modify" }

            try {
                $acl = Get-Acl -Path $path
                $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($group, $ntfsRight, "ContainerInherit,ObjectInherit", "None", "Allow")
                $acl.SetAccessRule($rule)
                Set-Acl -Path $path -AclObject $acl
                
                Write-Host " -> Rechten toegekend voor $group op $path ($ntfsRight)" -ForegroundColor Green
                Write-LogYSa "Rechten succesvol toegepast voor $group op map $path."
            } catch {
                Write-Warning " -> Fout bij het toepassen van rechten voor de groep '$group'."
            }
        } else {
            Write-Warning " -> Kan de rechten niet instellen omdat map $path niet bestaat."
        }
    }
    Write-Host " -> NTFS rechten zijn succesvol toegepast!" -ForegroundColor Green
}