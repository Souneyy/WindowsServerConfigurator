# WindowsServerConfigurator

================================================================================
PROJECT: PowerShell Server & Client Automation
AUTEUR: Younes Saoudi
INSTELLING: AP Hogeschool - Systeem en Netwerkbeheer
================================================================================

BESCHRIJVING
Dit project bevat een reeks geautomatiseerde PowerShell-scripts voor de 
basisconfiguratie van Windows Server 2025 en Windows 11 clients. Het script 
handelt computernamen, IP-configuraties, Active Directory promoties, en het 
importeren van gebruikers, mappen en shares automatisch af op basis van 
externe databestanden.

VOORBEREIDING & VEREISTEN
1. Plaats de volledige projectmap in de root van een schijf, met de exacte 
   naam: \scripting (bijv. C:\scripting\).
2. Zorg dat alle databestanden (.xml, .csv, .json, .txt) aanwezig zijn in de 
   map \scripting\settings\.
3. Pas de bestanden 'computer.settings.xml' en 'Domain.Settings.xml' aan met 
   de juiste MAC-adressen en gewenste domeinnamen voor uw specifieke omgeving.
4. Maak ALTIJD een snapshot van uw virtuele machines (Hyper-V/VMware) voordat 
   u het script start.

GEBRUIKSAANWIJZING
1. Open PowerShell als Administrator.
2. Navigeer naar de scripting map: 
   cd C:\scripting
3. Start het hoofdmenu: 
   .\MenuYSa.ps1
4. Volg de instructies op het scherm. 

BELANGRIJKE AANDACHTSPUNTEN
- Automatische Herstarts: Bij functies zoals het wijzigen van de computernaam 
  of het promoveren tot Domain Controller, zal de computer automatisch 
  herstarten. Het script zal eenmalig om uw Administrator wachtwoord vragen om 
  dit proces zonder onderbreking te laten hervatten.
- Logboek: Elke actie wordt geregistreerd. U kunt de voortgang en eventuele 
  foutmeldingen nakijken in: \scripting\logs\InstallatieLogYSa.txt.
- Foutafhandeling: Bestaat een map, OU of gebruiker al? Het script zal dit 
  detecteren, een melding geven en veilig doorgaan zonder te crashen.
================================================================================
