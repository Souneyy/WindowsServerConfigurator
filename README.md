PowerShell Infrastructure Automation
Toolkit
This project contains an automated framework of PowerShell scripts and modules for the
complete basic configuration and Active Directory setup of a Windows Server 2025 and a
Windows 11 client. The system is designed to eliminate repetitive system administration tasks
by dynamically loading configurations from structured XML, JSON, CSV, and text files.
This project was developed as an exam assignment for the Scripting course within the System
and Network Management program at AP Hogeschool Antwerpen for the academic year
2025-2026.
Table of Contents
1. Project Structure
2. Features
3. Configuration Files
4. Prerequisites and Requirements
5. Installation and Usage
6. Automatic Restart and State Management
7. Logging
8. Author
Project Structure
The files must be placed strictly in the \scripting folder to ensure flawless operation, regardless
of the drive letter.
\scripting
│ MenuYSa.ps1 # The central main menu and status controller
│ README.md # This GitHub documentation
│
├───logs
│ InstallatieLogYSa.txt # Central log file (automatically generated)
│
├───modules
│ algemeenYSa.psm1 # Module for basic configuration of OS and network
│ domainsettingsYSa.psm1 # Module for Active Directory and domain setup

│
└───settings
computer.settings.xml # Hardware and IP parameters for server and client
Domain.Settings.xml # Domain name, passwords, and profile paths
mappen.txt # Local folder structure (plain text)
ous.csv # Organizational Units for Active Directory
rechten.csv # Group permissions for NTFS folder security
securitygroups.csv # Security groups with scopes (Global or Local)
shares.csv # Network shares and corresponding system paths
users.json # User accounts including group memberships

Features
The framework is divided into logical, modular building blocks:
1. Basic Computer Configuration (algemeenYSa.psm1)
● Changing Computer Name: Changes the local hostname based on the XML
configuration file and initiates a safe reboot cycle.
● Automating IP Configuration: Finds the correct physical network adapter via the MAC
address, deactivates DHCP, disables IPv6, and configures static IP addresses, subnet
prefixes, gateways, and DNS servers.
● Folders and Network Shares: Automatically creates the local folder structure and
publishes these as SMB network shares with universal access for Everyone.
2. Active Directory and Domain Management
(domainsettingsYSa.psm1)
● AD DS Installation and Promotion: Installs the Active Directory Domain Services server
role including management tools. Checks via DNS if a domain already exists, adds the
server as an additional Domain Controller, or creates a completely new forest.
● Recursive Path Validation: Analyzes Distinguished Names (DN) and builds missing
parent and child Organizational Units (OUs) step-by-step from top to bottom.
● Bulk Import of Groups and Users:
○ Imports OUs and security groups (automatically assigns DomainLocal to groups
starting with DL_, otherwise Global).
○ Creates users from a JSON structure, generates secure passwords, configures
HomeDrives, HomeDirectories, and ProfilePaths, and directly assigns users to their

respective groups.
● NTFS Permissions Management: Applies Access Control Lists (ACLs) to folders for
specific domain groups with the defined permissions (ReadAndExecute or Modify)
including inheritance.
Configuration Files
The data in the settings folder dictates the behavior of the scripts. The structure must be
preserved exactly.
XML Settings (Example computer.settings.xml)
<Settings>
<name>ServerYSa</name>
<networksettings>
<networkadapter>
<name>LAN-Adapter</name>
<macaddress>00-15-5D-00-04-1A</macaddress>
<dhcpenabled>false</dhcpenabled>
<ip>10.1.10.10</ip>
<prefixlength>24</prefixlength>
<gateway>10.1.10.1</gateway>
<dns>10.1.10.10</dns>
</networkadapter>
</networksettings>
</Settings>

JSON Users (Example users.json)
{
"users": [
{
"login": "jdoe",
"firstName": "John",
"lastName": "Doe",
"ou": "Gedeeld/Personeel",
"securityGroups": ["GL_Kantoor", "DL_DataLezers"]
}

]
}

Prerequisites and Requirements
1. Permissions: Always start PowerShell as Administrator. The script checks this at startup
via an active network session test.
2. File Management: Ensure all files are located in the correct folder structure
(C:\scripting\).
3. Virtual Environment: Take snapshots of the Windows Server 2025 and Windows 11
virtual machines beforehand, so you can immediately roll back in case of configuration
errors.
Installation and Usage
1. Open PowerShell with administrator privileges.
2. Navigate to the root folder of the project:
Set-Location -Path "C:\scripting"
3. Start the application via the main menu script:
.\MenuYSa.ps1
4. Make a choice from the interactive menu:
○ Option 1: Basic computer configuration (Network, IP, local folders, shares)
○ Option 2: Windows server configuration (AD DS roles, DC promotion, imports of
OUs, groups, users, and NTFS permissions)
○ Option 3: Windows client configuration (IP configuration, hostname setup, and
domain join)

Automatic Restart and State Management
To guarantee an uninterrupted and fully automated installation, the script uses a built-in state
controller:
1. Secure Authentication: The administrator enters credentials once. These are kept
strictly within the script scope via $script:SessionCred.
2. Winlogon Registry Modification: Before a reboot, the script temporarily stores the
credentials in HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon and
activates AutoAdminLogon.
3. RunOnce Setup: The main menu script is registered in the RunOnce key of the registry.

4. State Files: A file is written to logs\InstallState.txt (e.g., ResumeServerConfig). After the
reboot, the script reads this state, immediately clears the registry values for security
reasons, and directly resumes that specific installation sequence.
Logging
In accordance with the project requirements, every executed system change is meticulously
logged. Errors or already existing objects (such as folders or OUs that are already present) are
neatly handled, displayed on the screen, and written to the log file without the script crashing.
Location log file: \scripting\logs\InstallatieLogYSa.txt
Example of log output:
09-06-2026 15:40:12 #### XML settings successfully loaded. ####
09-06-2026 15:41:05 #### Start IP configuration process... ####
09-06-2026 15:41:08 #### Static IP and DNS configured for network card Ethernet0. ####
09-06-2026 15:43:22 #### Start installation of AD DS roles... ####
09-06-2026 15:44:50 #### Installation of AD DS roles successfully completed. ####
09-06-2026 15:45:10 #### Folder automatically created:
OU=Gedeeld,OU=Antwerpen,DC=sveagles,DC=local ####

Author
● Name: Younes Saoudi
● Program: System and Network Management
● Educational Institution: AP Hogeschool Antwerpen
● Academic Year: 2025 - 2026
● Lecturers: Nick Van Acker & Dany De Deken
