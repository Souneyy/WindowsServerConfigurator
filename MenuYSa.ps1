<#
Naam: Younes Saoudi
Bestand: MenuYSa.ps1
Doel: Hoofdmenu voor server en client configuratie met perfecte logische volgorde en consistente opmaak.
#>

# ----------------------------------------------------------------
# 1. INITIALISATIE, BESTANDSNAMEN EN VEILIGE VARIABELEN
# ----------------------------------------------------------------
$ScriptDir = $PSScriptRoot
Set-Location -Path $ScriptDir

# CONFIGURATIE VAN BESTANDSNAMEN (Aanpasbaar per taal/gebruiker)
$NaamMappenBestand = "mappen.txt"
$NaamSharesBestand = "shares.csv"
$NaamRechtenBestand = "rechten.csv"
$NaamOUsBestand = "ous.csv"
$NaamGroepenBestand = "securitygroups.csv"
$NaamUsersBestand = "users.json"

# Veilige, script-scoped variabele voor inloggegevens.
# Omdat we $script: gebruiken, is deze variabele VOLLEDIG onzichtbaar 
# voor de globale PowerShell sessie en andere modules.
$script:SessionCred = $null

<#
.SYNOPSIS
Vraagt eenmalig om de inloggegevens en bewaart deze strikt lokaal in het script.

.DESCRIPTION
Door het wachtwoord veilig in de sessie te bewaren, hoeft de gebruiker zich niet meermaals te authenticeren tijdens lange installatiereeksen, wat het gebruiksgemak aanzienlijk verhoogt.

.EXAMPLE
$credential = Get-SecureMenuCredentialYSa
#>
function Get-SecureMenuCredentialYSa {
    if ($null -eq $script:SessionCred) {
        Write-Host "`n -> Beveiligingsverificatie vereist voor geautomatiseerde acties." -ForegroundColor Yellow
        $script:SessionCred = Get-Credential -UserName "Administrator" -Message "Eenmalige invoer (veilig lokaal opgeslagen)"
    }
    return $script:SessionCred
}

# ----------------------------------------------------------------
# 2. MODULES INLADEN MET FOUTCONTROLE
# ----------------------------------------------------------------
try {
    Import-Module (Join-Path $ScriptDir "modules\algemeenYSa.psm1") -Force -ErrorAction Stop
    Import-Module (Join-Path $ScriptDir "modules\domainsettingsYSa.psm1") -Force -ErrorAction Stop
} catch {
    Write-Warning "FATAAL: Een van de scriptmodules kon niet worden geladen!"
    Write-Error $_
    Write-Host "`nControleer de syntax van de psm1 bestanden." -ForegroundColor Yellow
    Pause
    exit
}

# ----------------------------------------------------------------
# RESUME SEQUENCES (Hervatten na herstart)
# ----------------------------------------------------------------

<#
.SYNOPSIS
Hervat de serverconfiguratie na de noodzakelijke herstart.

.DESCRIPTION
Deze hervattingsreeks importeert achter elkaar alle locatiemappen, groepen, gebruikers en bestandsshares, waarna de automatische login weer veilig wordt afgesloten.

.EXAMPLE
Resume-ServerConfigSequence
#>
function Resume-ServerConfigSequence {
    Clear-Host
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host "      HERVATTEN WINDOWS SERVER CONFIGURATIE       " -ForegroundColor White
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host " Server succesvol gepromoveerd. Starten met data imports..." -ForegroundColor Green
    
    Write-Host "`n [STAP 4/9] " -NoNewline -ForegroundColor Yellow; Write-Host "AD OUs importeren..." -ForegroundColor White
    Import-ADOUsYSa -ProjectPad $ScriptDir -BestandsNaam $NaamOUsBestand

    Write-Host "`n [STAP 5/9] " -NoNewline -ForegroundColor Yellow; Write-Host "AD Groepen importeren..." -ForegroundColor White
    Import-ADGroupsYSa -ProjectPad $ScriptDir -BestandsNaam $NaamGroepenBestand
    
    Write-Host "`n [STAP 6/9] " -NoNewline -ForegroundColor Yellow; Write-Host "AD Gebruikers importeren..." -ForegroundColor White
    Import-ADUsersFromJsonYSa -ProjectPad $ScriptDir -BestandsNaam $NaamUsersBestand

    Write-Host "`n [STAP 7/9] " -NoNewline -ForegroundColor Yellow; Write-Host "Mappenstructuur genereren..." -ForegroundColor White
    Create-FoldersYSa -ProjectPad $ScriptDir -BestandsNaam $NaamMappenBestand

    Write-Host "`n [STAP 8/9] " -NoNewline -ForegroundColor Yellow; Write-Host "Netwerkshares aanmaken..." -ForegroundColor White
    Create-SharesYSa -ProjectPad $ScriptDir -BestandsNaam $NaamSharesBestand

    Write-Host "`n [STAP 9/9] " -NoNewline -ForegroundColor Yellow; Write-Host "NTFS machtigingen toepassen..." -ForegroundColor White
    Set-NTFSPermissionsYSa -ProjectPad $ScriptDir -BestandsNaam $NaamRechtenBestand
    
    Disable-AutoLogonYSa
    
    Write-Host "`n -> Volledige serverconfiguratie is met succes afgerond!" -ForegroundColor Green
    Pause
    Show-MainMenuYSa
}


<#
.SYNOPSIS
Hervat de basiscomputer configuratie na de herstart.

.DESCRIPTION
Een korte veiligheidsfunctie die verifieert of de computer succesvol is herstart, om vervolgens de automatische aanmelding onmiddellijk te blokkeren.

.EXAMPLE
Resume-BasisRenameSequence
#>
function Resume-BasisRenameSequence {
    Clear-Host
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host "      HERVATTEN BASIS COMPUTER CONFIGURATIE       " -ForegroundColor White
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host " De computer is succesvol hernoemd en opnieuw opgestart!" -ForegroundColor Green

    Disable-AutoLogonYSa

    Write-Host "`n -> Automatische aanmelding is weer veilig uitgeschakeld." -ForegroundColor Green
    Pause
    Show-MainMenuYSa
}

<#
.SYNOPSIS
Hervat de Windows client configuratie na het koppelen aan het domein.

.DESCRIPTION
Deze functie sluit de installatiereeks van de client af en waarborgt dat er na de domeinkoppeling geen onveilige inloggegevens meer actief blijven op het systeem.

.EXAMPLE
Resume-ClientRenameSequence
#>
function Resume-ClientRenameSequence {
    Clear-Host
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host "      HERVATTEN WINDOWS CLIENT CONFIGURATIE       " -ForegroundColor White
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host " Client is succesvol aan het domein gekoppeld en de naam is gewijzigd!" -ForegroundColor Green
    
    Disable-AutoLogonYSa
    
    Write-Host "`n -> Volledige clientconfiguratie is met succes afgerond!" -ForegroundColor Green
    Pause
    Show-MainMenuYSa
}

# ----------------------------------------------------------------
# SUBMENU 1: BASIS CONFIGURATIE
# ----------------------------------------------------------------
<#
.SYNOPSIS
Toont het configuratiemenu voor de basiscomputer installatie.

.DESCRIPTION
Laadt het visuele menu met alle opties voor netwerkbeheer, bestandsbeheer en hardwarecontrole, waarna invoer van de gebruiker veilig wordt verwerkt.

.EXAMPLE
Show-SubMenuBasisYSa
#>
function Show-SubMenuBasisYSa {
    do {
        Clear-Host
        Write-Host "==================================================" -ForegroundColor Cyan
        Write-Host "           BASIS COMPUTER CONFIGURATIE            " -ForegroundColor White
        Write-Host "==================================================" -ForegroundColor Cyan
        
        Write-Host " [ Configuratie Opties ]" -ForegroundColor DarkCyan
        Write-Host "  1:" -NoNewline -ForegroundColor Yellow; Write-Host " Computernaam wijzigen (met herstart)"
        Write-Host "  2:" -NoNewline -ForegroundColor Yellow; Write-Host " Netwerkadapter handmatig hernoemen"
        Write-Host "  3:" -NoNewline -ForegroundColor Yellow; Write-Host " Netwerkadapter(s) automatisch hernoemen (via XML)"
        Write-Host "  4:" -NoNewline -ForegroundColor Yellow; Write-Host " Netwerkcomponent uitschakelen op netwerkadapter (IPv6)"
        Write-Host "  5:" -NoNewline -ForegroundColor Yellow; Write-Host " IP configuratie handmatig instellen (DHCP uitschakelen)"
        Write-Host "  6:" -NoNewline -ForegroundColor Yellow; Write-Host " IP configuratie automatisch instellen (via XML)"
        Write-Host "  7:" -NoNewline -ForegroundColor Yellow; Write-Host " Mappen aanmaken"
        Write-Host "  8:" -NoNewline -ForegroundColor Yellow; Write-Host " Shares aanmaken"
        Write-Host "--------------------------------------------------" -ForegroundColor Gray
        Write-Host "  9:" -NoNewline -ForegroundColor Green; Write-Host " Volledige basisconfiguratie achter elkaar uitvoeren" -ForegroundColor Green
        Write-Host "--------------------------------------------------" -ForegroundColor Gray
        
        Write-Host " [ Controle Opties ]" -ForegroundColor DarkCyan
        Write-Host " 10:" -NoNewline -ForegroundColor Yellow; Write-Host " Controleer computernaam"
        Write-Host " 30:" -NoNewline -ForegroundColor Yellow; Write-Host " Controleer netwerkadapter namen"
        Write-Host " 40:" -NoNewline -ForegroundColor Yellow; Write-Host " Controleer IPv6 status op adapters"
        Write-Host " 60:" -NoNewline -ForegroundColor Yellow; Write-Host " Controleer IP en DNS configuratie"
        Write-Host " 70:" -NoNewline -ForegroundColor Yellow; Write-Host " Controleer lokale mappen"
        Write-Host " 80:" -NoNewline -ForegroundColor Yellow; Write-Host " Controleer lokale netwerkshares"
        Write-Host "--------------------------------------------------" -ForegroundColor Gray
        
        Write-Host " [ Systeem Tools ]" -ForegroundColor DarkCyan
        Write-Host " 90:" -NoNewline -ForegroundColor Yellow; Write-Host " Computerinformatie weergeven"
        Write-Host " 99:" -NoNewline -ForegroundColor Yellow; Write-Host " Windows Server updaten"
        Write-Host "--------------------------------------------------" -ForegroundColor Gray
        Write-Host "  Q:" -NoNewline -ForegroundColor Red; Write-Host " Terugkeren naar het hoofdmenu"
        Write-Host "==================================================" -ForegroundColor Cyan
        Write-Host ""
        
        $keuze = Read-Host "Maak uw keuze a.u.b."
        
        switch ($keuze) {
            "1" { 
                $settings = Get-ComputerSettingsYSa -ProjectPad $ScriptDir
                $newName = ""

                if ($null -ne $settings) { 
                    $newName = $settings.Settings.name
                } else { 
                    Write-Host "Opmerking: Computer.settings.xml niet gevonden in de settings map." -ForegroundColor Yellow
                    $newName = Read-Host "Geef handmatig de nieuwe computernaam op"
                }

                if (($newName -replace '\s', '') -ne '') {
                    $credential = Get-SecureMenuCredentialYSa
                    $user = $credential.GetNetworkCredential().UserName
                    $pass = $credential.GetNetworkCredential().Password

                    Enable-AutoLogonYSa -UserName $user -Password $pass
                    Set-RunOnceScriptYSa -ScriptPath (Join-Path $ScriptDir "MenuYSa.ps1")

                    $stateDir = Join-Path $ScriptDir "logs"
                    if (-not (Test-Path $stateDir)) { New-Item -Path $stateDir -ItemType Directory -Force | Out-Null }
                    "ResumeBasisRename" | Out-File -FilePath (Join-Path $stateDir "InstallState.txt") -Force

                    Set-ComputerNameYSa -NewName $newName
                } else {
                    Write-Warning "Geen geldige computernaam opgegeven, de actie is geannuleerd."
                    Pause
                }
            }
            "2" {
                Clear-Host
                Write-Host "==================================================" -ForegroundColor Cyan
                Write-Host "           NETWERKADAPTER HERNOEMEN               " -ForegroundColor White
                Write-Host "==================================================" -ForegroundColor Cyan
                Get-NetAdapter | Select-Object Name, InterfaceDescription, MacAddress | Format-Table
                
                $oldName = Read-Host "Geef de huidige naam van de adapter"
                $newName = Read-Host "Geef de nieuwe naam voor de adapter"
                
                if (($oldName -replace '\s', '') -ne '' -and ($newName -replace '\s', '') -ne '') {
                    Rename-NetAdapter -Name $oldName -NewName $newName -ErrorAction SilentlyContinue
                    Write-Host "Adapter is succesvol hernoemd naar $newName (indien gevonden)." -ForegroundColor Green
                }
                Pause
            }
            "3" {
                Clear-Host
                Write-Host "==================================================" -ForegroundColor Cyan
                Write-Host "       NETWERKADAPTERS HERNOEMEN (VIA XML)        " -ForegroundColor White
                Write-Host "==================================================" -ForegroundColor Cyan
                $settings = Get-ComputerSettingsYSa -ProjectPad $ScriptDir
                if ($null -ne $settings) {
                    foreach ($adapter in $settings.Settings.networksettings.networkadapter) {
                        $mac = $adapter.macaddress
                        $newName = $adapter.name
                        $netAdapter = Get-NetAdapter | Where-Object { ($_.MacAddress -replace '-','') -eq ($mac -replace '-','') }
                        
                        if ($null -ne $netAdapter -and $netAdapter.Name -ne $newName) {
                            Rename-NetAdapter -Name $netAdapter.Name -NewName $newName -ErrorAction SilentlyContinue
                            Write-Host " -> Adapter met MAC $mac hernoemd naar $newName." -ForegroundColor Green
                        } elseif ($null -ne $netAdapter -and $netAdapter.Name -eq $newName) {
                            Write-Host " -> Adapter heet al $newName." -ForegroundColor Yellow
                        }
                    }
                }
                Pause
            }
            "4" {
                Clear-Host
                Write-Host "==================================================" -ForegroundColor Cyan
                Write-Host "                 IPV6 UITSCHAKELEN                " -ForegroundColor White
                Write-Host "==================================================" -ForegroundColor Cyan
                Disable-NetAdapterBinding -Name "*" -ComponentID ms_tcpip6 -ErrorAction SilentlyContinue
                Write-Host " -> IPv6 is succesvol uitgeschakeld op alle netwerkadapters." -ForegroundColor Green
                Pause
            }
            "5" {
                Clear-Host
                Write-Host "==================================================" -ForegroundColor Cyan
                Write-Host "            HANDMATIGE IP CONFIGURATIE            " -ForegroundColor White
                Write-Host "==================================================" -ForegroundColor Cyan
                Get-NetAdapter | Select-Object Name, MacAddress | Format-Table
                
                $adapterName = Read-Host "Geef de exacte naam van de adapter"
                $ip = Read-Host "Geef het statische IP adres in (bijv. 10.1.10.50)"
                $prefix = Read-Host "Geef de subnet prefix in (bijv. 24)"
                $gw = Read-Host "Geef de Default Gateway in"
                
                if (($adapterName -replace '\s', '') -ne '') {
                    Set-NetIPInterface -InterfaceAlias $adapterName -Dhcp Disabled -ErrorAction SilentlyContinue
                    Remove-NetIPAddress -InterfaceAlias $adapterName -Confirm:$false -ErrorAction SilentlyContinue
                    Remove-NetRoute -InterfaceAlias $adapterName -AddressFamily IPv4 -Confirm:$false -ErrorAction SilentlyContinue
                    
                    New-NetIPAddress -InterfaceAlias $adapterName -IPAddress $ip -PrefixLength $prefix -DefaultGateway $gw -AddressFamily IPv4 | Out-Null
                    Write-Host " -> Handmatige IP configuratie succesvol ingesteld." -ForegroundColor Green
                }
                Pause
            }
            "6" { Set-IPConfigurationYSa -ProjectPad $ScriptDir; Pause }
            "7" { Create-FoldersYSa -ProjectPad $ScriptDir -BestandsNaam $NaamMappenBestand; Pause }
            "8" { Create-SharesYSa -ProjectPad $ScriptDir -BestandsNaam $NaamSharesBestand; Pause }
            "9" {
                Clear-Host
                Write-Host "==================================================" -ForegroundColor Cyan
                Write-Host "       VOLLEDIGE BASISCOMPUTER CONFIGURATIE       " -ForegroundColor White
                Write-Host "==================================================" -ForegroundColor Cyan
                Write-Host " Starten van de geautomatiseerde installatiereeks..." -ForegroundColor Green
                
                Write-Host "`n [STAP 1/5] " -NoNewline -ForegroundColor Yellow; Write-Host "Netwerk configureren..." -ForegroundColor White
                Set-IPConfigurationYSa -ProjectPad $ScriptDir
                
                Write-Host "`n [STAP 2/5] " -NoNewline -ForegroundColor Yellow; Write-Host "Mappenstructuur genereren..." -ForegroundColor White
                $mappenPad = Join-Path $ScriptDir "settings\$NaamMappenBestand"
                if (Test-Path $mappenPad) {
                    Write-Host " -> Bestand $NaamMappenBestand is ingelezen, start de mapcreatie..." -ForegroundColor Gray
                    Create-FoldersYSa -ProjectPad $ScriptDir -BestandsNaam $NaamMappenBestand
                } else {
                    Write-Warning " -> FOUTCATEGORIE: Bestand $NaamMappenBestand is onvindbaar!"
                }
                
                Write-Host "`n [STAP 3/5] " -NoNewline -ForegroundColor Yellow; Write-Host "Netwerkshares publiceren..." -ForegroundColor White
                $sharesPad = Join-Path $ScriptDir "settings\$NaamSharesBestand"
                if (Test-Path $sharesPad) {
                    Write-Host " -> Bestand $NaamSharesBestand is ingelezen, start de configuratie..." -ForegroundColor Gray
                    Create-SharesYSa -ProjectPad $ScriptDir -BestandsNaam $NaamSharesBestand
                } else {
                    Write-Warning " -> FOUTCATEGORIE: Bestand $NaamSharesBestand is onvindbaar!"
                }
                
                Write-Host "`n [STAP 4/5] " -NoNewline -ForegroundColor Yellow; Write-Host "NTFS beveiliging toepassen..." -ForegroundColor White
                $rechtenPad = Join-Path $ScriptDir "settings\$NaamRechtenBestand"
                if (Test-Path $rechtenPad) {
                    Write-Host " -> Bestand $NaamRechtenBestand is ingelezen, start de validatie..." -ForegroundColor Gray
                    Set-NTFSPermissionsYSa -ProjectPad $ScriptDir -BestandsNaam $NaamRechtenBestand
                } else {
                    Write-Warning " -> FOUTCATEGORIE: Bestand $NaamRechtenBestand is onvindbaar!"
                }
                
                Write-Host "`n [STAP 5/5] " -NoNewline -ForegroundColor Yellow; Write-Host "Naam wijzigen en scriptherstart configureren..." -ForegroundColor White
                $settings = Get-ComputerSettingsYSa -ProjectPad $ScriptDir
                
                if ($null -ne $settings) {
                    $newName = $settings.Settings.name
                    Write-Host " -> De computernaam wordt straks gewijzigd naar: $newName" -ForegroundColor Green
                    Write-Host " -> Inloggegevens worden klaargezet voor de automatische start." -ForegroundColor Cyan
                    
                    $credential = Get-SecureMenuCredentialYSa
                    $user = $credential.GetNetworkCredential().UserName
                    $pass = $credential.GetNetworkCredential().Password
                    
                    Enable-AutoLogonYSa -UserName $user -Password $pass
                    Set-RunOnceScriptYSa -ScriptPath (Join-Path $ScriptDir "MenuYSa.ps1")
                    
                    $stateDir = Join-Path $ScriptDir "logs"
                    if (-not (Test-Path $stateDir)) { New-Item -Path $stateDir -ItemType Directory -Force | Out-Null }
                    "ResumeBasisRename" | Out-File -FilePath (Join-Path $stateDir "InstallState.txt") -Force
                    
                    Write-Host " -> Registerinstellingen voor de herstart zijn succesvol geplaatst." -ForegroundColor Green
                    Write-Host " -> Het systeem herstart binnen enkele seconden!" -ForegroundColor Cyan
                    
                    Start-Sleep -Seconds 3
                    Set-ComputerNameYSa -NewName $newName
                }
                Pause
            }
            
            "10" {
                Clear-Host
                Write-Host "==================================================" -ForegroundColor Cyan
                Write-Host "             CONTROLEER COMPUTERNAAM              " -ForegroundColor White
                Write-Host "==================================================" -ForegroundColor Cyan
                Write-Host " Huidige computernaam: $env:COMPUTERNAME" -ForegroundColor Green
                $settings = Get-ComputerSettingsYSa -ProjectPad $ScriptDir
                if ($null -ne $settings) {
                    $verwacht = $settings.Settings.name
                    if ($env:COMPUTERNAME -eq $verwacht) {
                        Write-Host " -> De naam komt perfect overeen met de XML instellingen ($verwacht)." -ForegroundColor Green
                    } else {
                        Write-Host " -> Let op: Volgens de XML zou de naam '$verwacht' moeten zijn." -ForegroundColor Yellow
                    }
                }
                Pause
            }
            "30" {
                Clear-Host
                Write-Host "==================================================" -ForegroundColor Cyan
                Write-Host "            OVERZICHT NETWERKADAPTERS             " -ForegroundColor White
                Write-Host "==================================================" -ForegroundColor Cyan
                Get-NetAdapter | Select-Object Name, Status, MacAddress, LinkSpeed | Format-Table -AutoSize
                Pause
            }
            "40" {
                Clear-Host
                Write-Host "==================================================" -ForegroundColor Cyan
                Write-Host "               IPV6 STATUS CONTROLE               " -ForegroundColor White
                Write-Host "==================================================" -ForegroundColor Cyan
                Get-NetAdapterBinding -ComponentID ms_tcpip6 | Select-Object Name, ComponentID, Enabled | Format-Table -AutoSize
                Write-Host " -> Als Enabled 'False' is, staat IPv6 correct uitgeschakeld." -ForegroundColor Yellow
                Pause
            }
            "60" {
                Clear-Host
                Write-Host "==================================================" -ForegroundColor Cyan
                Write-Host "        CONTROLEER IP EN DNS INSTELLINGEN         " -ForegroundColor White
                Write-Host "==================================================" -ForegroundColor Cyan
                Get-NetAdapter | Where-Object Status -eq 'Up' | ForEach-Object {
                    $ip = Get-NetIPAddress -InterfaceIndex $_.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
                    $dns = Get-DnsClientServerAddress -InterfaceIndex $_.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
                    
                    Write-Host " Adapter: $($_.Name)" -ForegroundColor Yellow
                    if ($ip) { Write-Host " IPv4 Adres: $($ip.IPAddress)" -ForegroundColor Green } 
                    else { Write-Host " IPv4 Adres: Geen (of DHCP)" -ForegroundColor Red }
                    
                    if ($dns -and $dns.ServerAddresses) { Write-Host " DNS Servers: $($dns.ServerAddresses -join ', ')" -ForegroundColor Green }
                    Write-Host "--------------------------------------------------" -ForegroundColor Gray
                }
                Pause
            }
            "70" {
                Clear-Host
                Write-Host "==================================================" -ForegroundColor Cyan
                Write-Host "             CONTROLEER LOKALE MAPPEN             " -ForegroundColor White
                Write-Host "==================================================" -ForegroundColor Cyan
                $file = Join-Path $ScriptDir "settings\$NaamMappenBestand"
                
                if (Test-Path $file) {
                    Get-Content $file | ForEach-Object {
                        $line = $_ -replace '^\s+|\s+$', ''
                        if (($line -replace '\s', '') -ne '') {
                            if (Test-Path $line) {
                                Write-Host " [OK] Map is aanwezig  : $line" -ForegroundColor Green
                            } else {
                                Write-Host " [X]  Map ontbreekt    : $line" -ForegroundColor Red
                            }
                        }
                    }
                } else {
                    Write-Warning "Kan $NaamMappenBestand niet inlezen."
                }
                Pause
            }
            "80" {
                Clear-Host
                Write-Host "==================================================" -ForegroundColor Cyan
                Write-Host "             OVERZICHT NETWERKSHARES              " -ForegroundColor White
                Write-Host "==================================================" -ForegroundColor Cyan
                $shares = Get-SmbShare | Where-Object { $_.Name -notmatch "\`$" -and $_.Name -ne "SYSVOL" -and $_.Name -ne "NETLOGON" -and $_.Name -ne "IPC\`$" }
                if ($shares) {
                    $shares | Select-Object Name, Path, Description | Format-Table -AutoSize
                } else {
                    Write-Host " -> Er zijn nog geen shares gevonden." -ForegroundColor Yellow
                }
                Pause
            }
            "90" { 
                Clear-Host
                Write-Host "==================================================" -ForegroundColor Cyan
                Write-Host "                SYSTEEM INFORMATIE                " -ForegroundColor White
                Write-Host "==================================================" -ForegroundColor Cyan
                Get-ComputerInfo | Select-Object CsName, OsName, OsArchitecture, WindowsVersion | Format-List
                
                Write-Host "==================================================" -ForegroundColor Cyan
                Write-Host "                NETWERK INFORMATIE                " -ForegroundColor White
                Write-Host "==================================================" -ForegroundColor Cyan
                Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -ne "Loopback Pseudo-Interface 1" } | Select-Object InterfaceAlias, IPAddress | Format-Table
                Pause
            }
            "99" { 
                Clear-Host
                Write-Host "==================================================" -ForegroundColor Cyan
                Write-Host "              WINDOWS SERVER UPDATEN              " -ForegroundColor White
                Write-Host "==================================================" -ForegroundColor Cyan
                Write-Host " Zoeken naar beschikbare Windows Updates..." -ForegroundColor Yellow
                $updateSession = New-Object -ComObject "Microsoft.Update.Session"
                $updateSearcher = $updateSession.CreateUpdateSearcher()
                $searchResult = $updateSearcher.Search("IsInstalled=0 and Type='Software'")
                
                if ($searchResult.Updates.Count -eq 0) {
                    Write-Host " -> Het systeem is volledig up-to-date. Geen updates gevonden." -ForegroundColor Green
                    Pause
                    break
                }
                
                Write-Host " -> Er zijn $($searchResult.Updates.Count) updates gevonden. Downloaden starten..." -ForegroundColor Cyan
                $updatesToDownload = New-Object -ComObject "Microsoft.Update.UpdateColl"
                foreach ($update in $searchResult.Updates) { $null = $updatesToDownload.Add($update) }
                
                $downloader = $updateSession.CreateUpdateDownloader()
                $downloader.Updates = $updatesToDownload
                $null = $downloader.Download()
                
                Write-Host " -> Updates succesvol gedownload. Installatie starten..." -ForegroundColor Cyan
                $updatesToInstall = New-Object -ComObject "Microsoft.Update.UpdateColl"
                foreach ($update in $searchResult.Updates) {
                    if ($update.IsDownloaded) { $null = $updatesToInstall.Add($update) }
                }
                
                $installer = $updateSession.CreateUpdateInstaller()
                $installer.Updates = $updatesToInstall
                $installationResult = $installer.Install()
                
                Write-Host " -> Installatie afgerond met statuscode: $($installationResult.ResultCode)" -ForegroundColor Green
                
                if ($installationResult.RebootRequired) {
                    Write-Host " -> Een herstart is vereist. Systeem start over 5 seconden opnieuw op..." -ForegroundColor Yellow
                    Start-Sleep -Seconds 5
                    Restart-Computer -Force
                } else {
                    Write-Host " -> Geen herstart vereist." -ForegroundColor Green
                    Pause
                }
            }
            "Q" { break }
            "q" { break }
            default { Write-Host "Ongeldige keuze."; Start-Sleep -Seconds 2 }
        }
    } while ($keuze -ne "Q" -and $keuze -ne "q")
}

# ----------------------------------------------------------------
# SUBMENU 2: WINDOWS SERVER CONFIGURATIE
# ----------------------------------------------------------------
<#
.SYNOPSIS
Toont het configuratiemenu voor de Windows Server beheerder.

.DESCRIPTION
Presenteert alle stappen om een server te promoveren en de Active Directory in te stellen, inclusief de uitgebreide controleopties voor de beheerder.

.EXAMPLE
Show-SubMenuServerYSa
#>
function Show-SubMenuServerYSa {
    do {
        Clear-Host
        Write-Host "==================================================" -ForegroundColor Cyan
        Write-Host "           WINDOWS SERVER CONFIGURATIE            " -ForegroundColor White
        Write-Host "==================================================" -ForegroundColor Cyan
        
        Write-Host " [ Configuratie Opties ]" -ForegroundColor DarkCyan
        Write-Host "  1:" -NoNewline -ForegroundColor Yellow; Write-Host " Active Directory Domain Services rollen installeren"
        Write-Host "  2:" -NoNewline -ForegroundColor Yellow; Write-Host " Server promoveren tot Domain Controller"
        Write-Host "  3:" -NoNewline -ForegroundColor Yellow; Write-Host " Organizational Units aanmaken (CSV)"
        Write-Host "  4:" -NoNewline -ForegroundColor Yellow; Write-Host " Active Directory beveiligingsgroepen importeren (CSV)"
        Write-Host "  5:" -NoNewline -ForegroundColor Yellow; Write-Host " Domeingebruikers importeren en toewijzen (JSON)"
        Write-Host "  6:" -NoNewline -ForegroundColor Yellow; Write-Host " Mappen, netwerkshares en NTFS machtigingen toepassen"
        Write-Host "--------------------------------------------------" -ForegroundColor Gray
        Write-Host "  7:" -NoNewline -ForegroundColor Green; Write-Host " Volledige serverconfiguratie achter elkaar uitvoeren" -ForegroundColor Green
        Write-Host "--------------------------------------------------" -ForegroundColor Gray
        
        Write-Host " [ Controle Opties ]" -ForegroundColor DarkCyan
        Write-Host " 10:" -NoNewline -ForegroundColor Yellow; Write-Host " Controleer Active Directory installatie en versie"
        Write-Host " 20:" -NoNewline -ForegroundColor Yellow; Write-Host " Controleer Domain Controller status"
        Write-Host " 30:" -NoNewline -ForegroundColor Yellow; Write-Host " Toon Organizational Units"
        Write-Host " 40:" -NoNewline -ForegroundColor Yellow; Write-Host " Toon Active Directory beveiligingsgroepen"
        Write-Host " 50:" -NoNewline -ForegroundColor Yellow; Write-Host " Toon Domeingebruikers"
        Write-Host " 60:" -NoNewline -ForegroundColor Yellow; Write-Host " Controleer netwerkshares"
        Write-Host "--------------------------------------------------" -ForegroundColor Gray
        Write-Host "  Q:" -NoNewline -ForegroundColor Red; Write-Host " Terugkeren naar het hoofdmenu"
        Write-Host "==================================================" -ForegroundColor Cyan
        Write-Host ""
        
        $keuze = Read-Host "Maak uw keuze a.u.b."
        
        switch ($keuze) {
            "1" { Install-ADRoleYSa ; Pause }
            "2" { 
                $domainXmlPath = Join-Path $ScriptDir "settings\Domain.Settings.xml"
                if (Test-Path $domainXmlPath) {
                    try {
                        [xml]$domainXml = Get-Content -Path $domainXmlPath -Raw -ErrorAction Stop
                        $domein = $domainXml.Settings.Domain.domainname
                        Promote-DomainControllerYSa -DomeinNaam $domein
                    } catch { Write-Warning "Fout bij het inlezen van het XML bestand." }
                } else { Write-Warning "KRITISCHE FOUT: Kan Domain.Settings.xml niet vinden." }
                Pause 
            }
            "3" { 
                Clear-Host
                Write-Host "==================================================" -ForegroundColor Cyan
                Write-Host "        AD ORGANIZATIONAL UNITS IMPORTEREN        " -ForegroundColor White
                Write-Host "==================================================" -ForegroundColor Cyan
                Import-ADOUsYSa -ProjectPad $ScriptDir -BestandsNaam $NaamOUsBestand
                Pause 
            }
            "4" { 
                Clear-Host
                Write-Host "==================================================" -ForegroundColor Cyan
                Write-Host "         AD BEVEILIGINGSGROEPEN IMPORTEREN        " -ForegroundColor White
                Write-Host "==================================================" -ForegroundColor Cyan
                Import-ADGroupsYSa -ProjectPad $ScriptDir -BestandsNaam $NaamGroepenBestand
                Pause 
            }
            "5" { 
                Clear-Host
                Write-Host "==================================================" -ForegroundColor Cyan
                Write-Host "          AD GEBRUIKERS IMPORTEREN (JSON)         " -ForegroundColor White
                Write-Host "==================================================" -ForegroundColor Cyan
                Import-ADUsersFromJsonYSa -ProjectPad $ScriptDir -BestandsNaam $NaamUsersBestand
                Pause 
            }
            "6" { 
                Clear-Host
                Write-Host "==================================================" -ForegroundColor Cyan
                Write-Host "           BESTANDSSERVER CONFIGURATIE            " -ForegroundColor White
                Write-Host "==================================================" -ForegroundColor Cyan
                Write-Host "`n [STAP 1/3] " -NoNewline -ForegroundColor Yellow; Write-Host "Mappenstructuur genereren..." -ForegroundColor White
                Create-FoldersYSa -ProjectPad $ScriptDir -BestandsNaam $NaamMappenBestand
                Write-Host "`n [STAP 2/3] " -NoNewline -ForegroundColor Yellow; Write-Host "Netwerkshares aanmaken..." -ForegroundColor White
                Create-SharesYSa -ProjectPad $ScriptDir -BestandsNaam $NaamSharesBestand
                Write-Host "`n [STAP 3/3] " -NoNewline -ForegroundColor Yellow; Write-Host "NTFS machtigingen toepassen..." -ForegroundColor White
                Set-NTFSPermissionsYSa -ProjectPad $ScriptDir -BestandsNaam $NaamRechtenBestand
                Pause 
            }
            "7" {
                Clear-Host
                Write-Host "==================================================" -ForegroundColor Cyan
                Write-Host "          VOLLEDIGE SERVER CONFIGURATIE           " -ForegroundColor White
                Write-Host "==================================================" -ForegroundColor Cyan
                Write-Host " Starten van de geautomatiseerde installatiereeks..." -ForegroundColor Green
                
                Write-Host "`n [STAP 1/3] " -NoNewline -ForegroundColor Yellow; Write-Host "Voorbereiding: IP configureren..." -ForegroundColor White
                Set-IPConfigurationYSa -ProjectPad $ScriptDir
                
                Write-Host "`n [STAP 2/3] " -NoNewline -ForegroundColor Yellow; Write-Host "Active Directory rollen installeren..." -ForegroundColor White
                Install-ADRoleYSa
                
                Write-Host "`n [STAP 3/3] " -NoNewline -ForegroundColor Yellow; Write-Host "Promoveren tot Domain Controller..." -ForegroundColor White
                $domainXmlPath = Join-Path $ScriptDir "settings\Domain.Settings.xml"
                if (Test-Path $domainXmlPath) {
                    try {
                        [xml]$domainXml = Get-Content -Path $domainXmlPath -Raw -ErrorAction Stop
                        $domein = $domainXml.Settings.Domain.domainname
                        
                        Write-Host " -> De server wordt gepromoveerd voor domein: $domein" -ForegroundColor Green
                        Write-Host " -> Inloggegevens worden klaargezet voor de automatische herstart." -ForegroundColor Cyan
                        
                        $credential = Get-SecureMenuCredentialYSa
                        $user = $credential.GetNetworkCredential().UserName
                        $pass = $credential.GetNetworkCredential().Password
                        
                        Enable-AutoLogonYSa -UserName $user -Password $pass
                        Set-RunOnceScriptYSa -ScriptPath (Join-Path $ScriptDir "MenuYSa.ps1")
                        
                        $stateDir = Join-Path $ScriptDir "logs"
                        if (-not (Test-Path $stateDir)) { New-Item -Path $stateDir -ItemType Directory -Force | Out-Null }
                        "ResumeServerConfig" | Out-File -FilePath (Join-Path $stateDir "InstallState.txt") -Force
                        
                        Write-Host " -> Registerinstellingen voor de herstart zijn succesvol geplaatst." -ForegroundColor Green
                        Write-Host " -> Het systeem begint nu met de promotie!" -ForegroundColor Cyan
                        
                        Start-Sleep -Seconds 3
                        Promote-DomainControllerYSa -DomeinNaam $domein
                    } catch { Write-Warning "Fout bij de DC promotie." }
                } else {
                    Write-Warning " -> FOUTCATEGORIE: Bestand Domain.Settings.xml is onvindbaar!"
                }
                Pause
            }
            
            "10" {
                Clear-Host
                Write-Host "==================================================" -ForegroundColor Cyan
                Write-Host "      CONTROLEER ACTIVE DIRECTORY INSTALLATIE     " -ForegroundColor White
                Write-Host "==================================================" -ForegroundColor Cyan
                $adRole = Get-WindowsFeature -Name AD-Domain-Services
                if ($adRole.Installed) {
                    Write-Host " -> Active Directory Domain Services is succesvol geïnstalleerd." -ForegroundColor Green
                    $osInfo = Get-ComputerInfo | Select-Object -ExpandProperty OsName
                    Write-Host " -> Windows Versie: $osInfo" -ForegroundColor Green
                } else {
                    Write-Host " -> Active Directory Domain Services is momenteel NIET geïnstalleerd." -ForegroundColor Red
                }
                Pause
            }
            "20" {
                Clear-Host
                Write-Host "==================================================" -ForegroundColor Cyan
                Write-Host "        CONTROLEER DOMAIN CONTROLLER STATUS       " -ForegroundColor White
                Write-Host "==================================================" -ForegroundColor Cyan
                try {
                    $dc = Get-ADDomainController -ErrorAction Stop
                    Write-Host " -> Deze server functioneert als actieve Domain Controller!" -ForegroundColor Green
                    Write-Host " Domeinnaam: $($dc.Domain)" -ForegroundColor Green
                    Write-Host " Forestnaam: $($dc.Forest)" -ForegroundColor Green
                    Write-Host " IPv4 Adres: $($dc.IPv4Address)" -ForegroundColor Green
                } catch {
                    Write-Host " -> Deze server is nog geen actieve Domain Controller." -ForegroundColor Red
                }
                Pause
            }
            "30" {
                Clear-Host
                Write-Host "==================================================" -ForegroundColor Cyan
                Write-Host "         OVERZICHT ORGANIZATIONAL UNITS           " -ForegroundColor White
                Write-Host "==================================================" -ForegroundColor Cyan
                try {
                    Get-ADOrganizationalUnit -Filter * | Select-Object Name, DistinguishedName | Format-Table -AutoSize
                } catch {
                    Write-Host " -> Kan de mappen niet ophalen. Is Active Directory bereikbaar?" -ForegroundColor Red
                }
                Pause
            }
            "40" {
                Clear-Host
                Write-Host "==================================================" -ForegroundColor Cyan
                Write-Host "       OVERZICHT ACTIVE DIRECTORY GROEPEN         " -ForegroundColor White
                Write-Host "==================================================" -ForegroundColor Cyan
                try {
                    Get-ADGroup -Filter * | Where-Object { $_.DistinguishedName -notmatch "CN=Users|CN=Builtin" } | Select-Object Name, GroupScope, GroupCategory | Format-Table -AutoSize
                } catch {
                    Write-Host " -> Kan de groepen niet ophalen. Is Active Directory bereikbaar?" -ForegroundColor Red
                }
                Pause
            }
            "50" {
                Clear-Host
                Write-Host "==================================================" -ForegroundColor Cyan
                Write-Host "            OVERZICHT DOMEINGEBRUIKERS            " -ForegroundColor White
                Write-Host "==================================================" -ForegroundColor Cyan
                try {
                    Get-ADUser -Filter * | Where-Object { $_.DistinguishedName -notmatch "CN=Users" -and $_.Name -ne "Administrator" -and $_.Name -ne "Guest" } | Select-Object SamAccountName, Name, UserPrincipalName, Enabled | Format-Table -AutoSize
                } catch {
                    Write-Host " -> Kan de gebruikers niet ophalen. Is Active Directory bereikbaar?" -ForegroundColor Red
                }
                Pause
            }
            "60" {
                Clear-Host
                Write-Host "==================================================" -ForegroundColor Cyan
                Write-Host "             OVERZICHT NETWERKSHARES              " -ForegroundColor White
                Write-Host "==================================================" -ForegroundColor Cyan
                $shares = Get-SmbShare | Where-Object { $_.Name -notmatch "\`$" -and $_.Name -ne "SYSVOL" -and $_.Name -ne "NETLOGON" -and $_.Name -ne "IPC\`$" }
                if ($shares) {
                    $shares | Select-Object Name, Path | Format-Table -AutoSize
                } else {
                    Write-Host " -> Er zijn nog geen handmatige shares geconfigureerd op deze server." -ForegroundColor Yellow
                }
                Pause
            }
            "Q" { break }
            "q" { break }
            default { Write-Host "Ongeldige keuze." ; Start-Sleep -Seconds 2 }
        }
    } while ($keuze -ne "Q" -and $keuze -ne "q")
}

# ----------------------------------------------------------------
# SUBMENU 3: WINDOWS CLIENT CONFIGURATIE
# ----------------------------------------------------------------
<#
.SYNOPSIS
Toont het configuratiemenu voor het koppelen van de Windows client.

.DESCRIPTION
Geeft een overzicht van de stappen die nodig zijn om een client netwerk gereed te maken, en stuurt de onderliggende functies aan voor een vlotte installatie.

.EXAMPLE
Show-SubMenuClientYSa
#>
function Show-SubMenuClientYSa {
    do {
        Clear-Host
        Write-Host "==================================================" -ForegroundColor Cyan
        Write-Host "           WINDOWS CLIENT CONFIGURATIE            " -ForegroundColor White
        Write-Host "==================================================" -ForegroundColor Cyan
        
        Write-Host " [ Configuratie Opties ]" -ForegroundColor DarkCyan
        Write-Host "  1:" -NoNewline -ForegroundColor Yellow; Write-Host " Netwerkinstellingen configureren (via XML)"
        Write-Host "  2:" -NoNewline -ForegroundColor Yellow; Write-Host " Client computer koppelen aan het Active Directory domein"
        Write-Host "  3:" -NoNewline -ForegroundColor Yellow; Write-Host " Computernaam wijzigen (met automatische herstart)"
        Write-Host "--------------------------------------------------" -ForegroundColor Gray
        Write-Host "  4:" -NoNewline -ForegroundColor Green; Write-Host " Volledige clientconfiguratie achter elkaar uitvoeren" -ForegroundColor Green
        Write-Host "--------------------------------------------------" -ForegroundColor Gray
        
        Write-Host " [ Controle Opties ]" -ForegroundColor DarkCyan
        Write-Host " 10:" -NoNewline -ForegroundColor Yellow; Write-Host " Controleer IP en Netwerkinstellingen"
        Write-Host " 20:" -NoNewline -ForegroundColor Yellow; Write-Host " Controleer Active Directory domeinkoppeling"
        Write-Host " 30:" -NoNewline -ForegroundColor Yellow; Write-Host " Controleer huidige computernaam"
        Write-Host "--------------------------------------------------" -ForegroundColor Gray
        Write-Host "  Q:" -NoNewline -ForegroundColor Red; Write-Host " Terugkeren naar het hoofdmenu"
        Write-Host "==================================================" -ForegroundColor Cyan
        Write-Host ""
        
        $keuze = Read-Host "Maak uw keuze a.u.b."
        
        switch ($keuze) {
            "1" { Set-IPConfigurationYSa -ProjectPad $ScriptDir; Pause }
            "2" { Join-DomainYSa -ProjectPad $ScriptDir; Pause }
            "3" { 
                $settings = Get-ComputerSettingsYSa -ProjectPad $ScriptDir
                if ($null -ne $settings) { Set-ComputerNameYSa -NewName $settings.Settings.name }
                Pause 
            }
            "4" {
                Clear-Host
                Write-Host "==================================================" -ForegroundColor Cyan
                Write-Host "          VOLLEDIGE CLIENT CONFIGURATIE           " -ForegroundColor White
                Write-Host "==================================================" -ForegroundColor Cyan
                Write-Host " Starten van de geautomatiseerde installatiereeks..." -ForegroundColor Green
                
                Write-Host "`n [STAP 1/3] " -NoNewline -ForegroundColor Yellow; Write-Host "IP configuratie instellen..." -ForegroundColor White
                Set-IPConfigurationYSa -ProjectPad $ScriptDir
                
                Write-Host "`n [STAP 2/3] " -NoNewline -ForegroundColor Yellow; Write-Host "Computernaam wijzigen (zonder herstart)..." -ForegroundColor White
                $settings = Get-ComputerSettingsYSa -ProjectPad $ScriptDir
                if ($null -ne $settings) {
                    $newName = $settings.Settings.name
                    Set-ComputerNameYSa -NewName $newName -NoRestart
                }
                
                Write-Host "`n [STAP 3/3] " -NoNewline -ForegroundColor Yellow; Write-Host "Koppelen aan het domein en herstarten..." -ForegroundColor White
                Write-Host " -> Inloggegevens worden klaargezet voor de domeinkoppeling en AutoLogon." -ForegroundColor Cyan
                
                $credential = Get-SecureMenuCredentialYSa
                $user = $credential.GetNetworkCredential().UserName
                $pass = $credential.GetNetworkCredential().Password
                
                Enable-AutoLogonYSa -UserName $user -Password $pass
                Set-RunOnceScriptYSa -ScriptPath (Join-Path $ScriptDir "MenuYSa.ps1")
                
                $stateDir = Join-Path $ScriptDir "logs"
                if (-not (Test-Path $stateDir)) { New-Item -Path $stateDir -ItemType Directory -Force | Out-Null }
                "ResumeClientRename" | Out-File -FilePath (Join-Path $stateDir "InstallState.txt") -Force
                
                Write-Host " -> Registerinstellingen voor de herstart zijn succesvol geplaatst." -ForegroundColor Green
                Write-Host " -> Het systeem begint nu met de domeinkoppeling en herstart direct daarna!" -ForegroundColor Cyan
                
                Start-Sleep -Seconds 3
                
                Join-DomainYSa -ProjectPad $ScriptDir -DomainCredential $credential
                Pause
            }
            
            "10" {
                Clear-Host
                Write-Host "==================================================" -ForegroundColor Cyan
                Write-Host "       CONTROLEER IP EN NETWERKINSTELLINGEN       " -ForegroundColor White
                Write-Host "==================================================" -ForegroundColor Cyan
                Get-NetAdapter | Where-Object Status -eq 'Up' | ForEach-Object {
                    $ip = Get-NetIPAddress -InterfaceIndex $_.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
                    $dns = Get-DnsClientServerAddress -InterfaceIndex $_.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
                    
                    Write-Host " Adapter:" -NoNewline; Write-Host " $($_.Name)" -ForegroundColor Yellow
                    Write-Host " MAC Adres: $($_.MacAddress)"
                    
                    if ($ip) { Write-Host " IPv4 Adres: $($ip.IPAddress)" -ForegroundColor Green } 
                    else { Write-Host " IPv4 Adres: Geen (of DHCP)" -ForegroundColor Red }
                    
                    if ($dns -and $dns.ServerAddresses) { Write-Host " DNS Servers: $($dns.ServerAddresses -join ', ')" -ForegroundColor Green }
                    Write-Host "--------------------------------------------------" -ForegroundColor Gray
                }
                Pause
            }
            "20" {
                Clear-Host
                Write-Host "==================================================" -ForegroundColor Cyan
                Write-Host "       CONTROLEER ACTIVE DIRECTORY KOPPELING      " -ForegroundColor White
                Write-Host "==================================================" -ForegroundColor Cyan
                $sysInfo = Get-CimInstance Win32_ComputerSystem
                if ($sysInfo.PartOfDomain) {
                    Write-Host " -> Deze computer is succesvol gekoppeld aan het domein!" -ForegroundColor Green
                    Write-Host " -> Domeinnaam: $($sysInfo.Domain)" -ForegroundColor Green
                } else {
                    Write-Host " -> Deze computer is NIET gekoppeld aan een Active Directory domein." -ForegroundColor Red
                    Write-Host " -> Huidige status: Werkgroep ($($sysInfo.Domain))" -ForegroundColor Yellow
                }
                Pause
            }
            "30" {
                Clear-Host
                Write-Host "==================================================" -ForegroundColor Cyan
                Write-Host "             CONTROLEER COMPUTERNAAM              " -ForegroundColor White
                Write-Host "==================================================" -ForegroundColor Cyan
                Write-Host " De huidige computernaam is:" -NoNewline; Write-Host " $env:COMPUTERNAME" -ForegroundColor Green
                
                $settings = Get-ComputerSettingsYSa -ProjectPad $ScriptDir
                if ($null -ne $settings) {
                    $verwachteNaam = $settings.Settings.name
                    if ($env:COMPUTERNAME -eq $verwachteNaam) {
                        Write-Host " -> Dit komt perfect overeen met de instellingen in Computer.settings.xml." -ForegroundColor Green
                    } else {
                        Write-Host " -> Let op: Volgens de XML zou de naam '$verwachteNaam' moeten zijn. (Is een herstart nog vereist?)" -ForegroundColor Yellow
                    }
                }
                Pause
            }
            "Q" { break }
            "q" { break }
            default { Write-Host "Ongeldige keuze."; Start-Sleep -Seconds 2 }
        }
    } while ($keuze -ne "Q" -and $keuze -ne "q")
}

# ----------------------------------------------------------------
# HOOFDMENU
# ----------------------------------------------------------------
<#
.SYNOPSIS
Toont het centrale hoofdmenu van de PowerShell applicatie.

.DESCRIPTION
Dit is het startpunt van het programma, waarvandaan de gebruiker kan navigeren naar de specifieke submenu locaties voor verdere installaties en controles.

.EXAMPLE
Show-MainMenuYSa
#>
function Show-MainMenuYSa {
    do {
        Clear-Host
        Write-Host "==================================================" -ForegroundColor Cyan
        Write-Host "          Younes PowerShell Admin Tools           " -ForegroundColor White
        Write-Host "==================================================" -ForegroundColor Cyan
        Write-Host " [ Hoofdmenu Opties ]" -ForegroundColor DarkCyan
        Write-Host "  1:" -NoNewline -ForegroundColor Yellow; Write-Host " Basis computer configuratie"
        Write-Host "  2:" -NoNewline -ForegroundColor Yellow; Write-Host " Windows server configuratie"
        Write-Host "  3:" -NoNewline -ForegroundColor Yellow; Write-Host " Windows client configuratie"
        Write-Host "--------------------------------------------------" -ForegroundColor Gray
        Write-Host "  Q:" -NoNewline -ForegroundColor Red; Write-Host " Programma afsluiten"
        Write-Host "==================================================" -ForegroundColor Cyan
        Write-Host ""
        
        $choice = Read-Host "Maak uw keuze a.u.b."
        
        switch ($choice) {
            "1" { Show-SubMenuBasisYSa }
            "2" { Show-SubMenuServerYSa }
            "3" { Show-SubMenuClientYSa }
            "Q" { 
                Write-Host "Programma wordt afgesloten..." -ForegroundColor Green
                break
            }
            "q" { 
                Write-Host "Programma wordt afgesloten..." -ForegroundColor Green
                break
            }
            default { Write-Host "Ongeldige keuze."; Start-Sleep -Seconds 2 }
        }
    } while ($choice -ne "Q" -and $choice -ne "q")
}

# ----------------------------------------------------------------
# CONTROLE OP ADMINISTRATOR RECHTEN EN START / STATUSCONTROLE
# ----------------------------------------------------------------
net session *>$null 2>&1
if ($LASTEXITCODE -ne 0) { 
    Write-Warning "Start PowerShell als Administrator!"
    Pause
    exit
}

$StateFile = Join-Path $ScriptDir "logs\InstallState.txt"
if (Test-Path $StateFile) {
    $State = (Get-Content -Path $StateFile -Raw).Trim()
    Remove-Item -Path $StateFile -Force -ErrorAction SilentlyContinue
    
    if ($State -eq "ResumeServerConfig") {
        Resume-ServerConfigSequence
    }
    elseif ($State -eq "ResumeClientRename") {
        Resume-ClientRenameSequence
    }
    elseif ($State -eq "ResumeBasisRename") {
        Resume-BasisRenameSequence
    }
} else {
    Show-MainMenuYSa
}