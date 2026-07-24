<#
.SYNOPSIS
    Windows License Checker & Edition Manager (CLI)
.DESCRIPTION
    A command-line tool to help users check their Windows licensing status, 
    manage product keys, and easily upgrade or downgrade Windows editions.
.NOTES
    DISCLAIMER: This tool is intended solely to assist with Windows licensing operations. 
    The author is not responsible for any misuse or illegal use of this tool. 
    We strongly encourage users to purchase a genuine Windows license.
#>

# Auto-elevate to Administrator
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Requesting Administrator privileges..." -ForegroundColor Yellow
    if ($PSCommandPath) {
        Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    } else {
        Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"irm https://raw.githubusercontent.com/tctvn/winlic/main/winlic.ps1 | iex`"" -Verb RunAs
    }
    exit
}

function Show-Header {
    Clear-Host
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "      Windows License Checker & Edition Manager" -ForegroundColor White
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host " DISCLAIMER: For educational & management purposes only." -ForegroundColor Yellow
    Write-Host " We are not responsible for any misuse. Please buy a genuine license." -ForegroundColor Yellow
    Write-Host "==========================================================" -ForegroundColor Cyan
}

function Read-MenuChoice {
    param([string]$Prompt = "Select an option")
    Write-Host "$($Prompt): " -NoNewline -ForegroundColor Green
    $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").Character
    Write-Host $key -ForegroundColor White
    Write-Host ""
    return [string]$key
}

function Pause {
    Write-Host "Press any key to continue..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    Write-Host ""
}

function Invoke-Slmgr {
    param([string]$ArgsStr)
    Write-Host "`n[*] Running slmgr.vbs $ArgsStr..." -ForegroundColor DarkGray
    $sysDir = [Environment]::GetFolderPath('System')
    $slmgr = Join-Path $sysDir "slmgr.vbs"
    if (Test-Path $slmgr) {
        cscript.exe //nologo $slmgr $ArgsStr
    } else {
        Write-Host "[!] slmgr.vbs not found at $slmgr" -ForegroundColor Red
    }
}

function Get-BiosKeyInfo {
    try {
        $svc = Get-CimInstance -ClassName SoftwareLicensingService -ErrorAction SilentlyContinue
        if ($svc -and -not [string]::IsNullOrWhiteSpace($svc.OA3xOriginalProductKey)) {
            return @{ 
                Key = $svc.OA3xOriginalProductKey
                Description = $svc.OA3xOriginalProductKeyDescription 
            }
        }
    } catch {}
    return $null
}

function Get-ActiveLicenses {
    try {
        return Get-CimInstance -ClassName SoftwareLicensingProduct -Filter "PartialProductKey IS NOT NULL" -ErrorAction SilentlyContinue
    } catch {
        return $null
    }
}

function Show-BasicInfo {
    Write-Host "`n--- OS Information ---" -ForegroundColor Cyan
    try {
        $os = Get-WmiObject -Class Win32_OperatingSystem
        Write-Host "OS Name       : $($os.Caption)"
        Write-Host "Version       : $($os.Version)"
        Write-Host "Build Number  : $($os.BuildNumber)"
        Write-Host "Architecture  : $($os.OSArchitecture)"
    } catch {
        Write-Host "Error retrieving OS info: $_" -ForegroundColor Red
    }

    Write-Host "`n--- Active License (WMI) ---" -ForegroundColor Cyan
    try {
        $biosInfo = Get-BiosKeyInfo
        $biosKey = if ($biosInfo) { $biosInfo.Key } else { $null }
        
        $lic = Get-ActiveLicenses
        if ($lic) {
            foreach ($l in $lic) {
                if ($l.Name -match "Windows") {
                    Write-Host "Edition       : $($l.Name)"
                    Write-Host "Channel       : $($l.Description)"
                    Write-Host "Partial Key   : $($l.PartialProductKey)"
                    
                    if (![string]::IsNullOrWhiteSpace($biosKey) -and $biosKey.Length -ge 5) {
                        $last5 = $biosKey.Substring($biosKey.Length - 5)
                        if ($l.PartialProductKey -eq $last5) {
                            Write-Host "BIOS Match    : Yes" -ForegroundColor Green
                        } else {
                            Write-Host "BIOS Match    : No" -ForegroundColor Yellow
                        }
                    } else {
                        Write-Host "BIOS Match    : N/A (No BIOS key)" -ForegroundColor DarkGray
                    }
                    
                    $status = switch ($l.LicenseStatus) {
                        0 { "Unlicensed" }
                        1 { "Licensed" }
                        2 { "OOB Grace" }
                        3 { "OOT Grace" }
                        4 { "Non-Genuine Grace" }
                        5 { "Notification" }
                        6 { "Extended Grace" }
                        default { "Unknown ($($l.LicenseStatus))" }
                    }
                    Write-Host "Status        : $status"
                }
            }
        } else {
            Write-Host "No active partial product key found." -ForegroundColor Yellow
        }
    } catch {
        Write-Host "Error retrieving License info: $_" -ForegroundColor Red
    }

    Invoke-Slmgr "/dli"
    Pause
}

function Show-BiosKey {
    Write-Host "`n--- BIOS/OEM Original Product Key ---" -ForegroundColor Cyan
    try {
        $biosInfo = Get-BiosKeyInfo
        $key = if ($biosInfo) { $biosInfo.Key } else { $null }
        $desc = if ($biosInfo) { $biosInfo.Description } else { $null }
        
        if ([string]::IsNullOrWhiteSpace($key)) {
            Write-Host "No BIOS/OEM key detected on this system." -ForegroundColor Yellow
        } else {
            Write-Host "Key Found     : $key" -ForegroundColor Green
            Write-Host "Description   : $desc"
        }
    } catch {
        Write-Host "Error retrieving BIOS key: $_" -ForegroundColor Red
    }
    Pause
}

function Remove-License {
    Write-Host "`n--- Remove License ---" -ForegroundColor Red
    Write-Host "This will uninstall your current product key and clear it from the registry."
    $confirm = Read-MenuChoice "Are you sure? (Y/N)"
    if ($confirm -match "^[Yy]") {
        Invoke-Slmgr "/upk"
        Invoke-Slmgr "/cpky"
        Write-Host "Done." -ForegroundColor Green
    } else {
        Write-Host "Operation cancelled." -ForegroundColor Yellow
    }
    Pause
}

function Reset-Activation {
    Write-Host "`n--- Reset Activation (Rearm) ---" -ForegroundColor Red
    Write-Host "This will reset the licensing status and activation timers."
    $confirm = Read-MenuChoice "Are you sure? (Y/N)"
    if ($confirm -match "^[Yy]") {
        Invoke-Slmgr "/rearm"
        Write-Host "Done. You may need to restart your computer." -ForegroundColor Green
    } else {
        Write-Host "Operation cancelled." -ForegroundColor Yellow
    }
    Pause
}

function Show-KmsMenu {
    $kmsLoop = $true
    while ($kmsLoop) {
        Show-Header
        Write-Host "--- KMS Activation Menu ---" -ForegroundColor Cyan
        Write-Host "1. Install KMS Client Key (slmgr /ipk)"
        Write-Host "2. Set KMS Server (slmgr /skms)"
        Write-Host "3. Attempt Activation (slmgr /ato)"
        Write-Host "4. Clear KMS Server (slmgr /ckms)"
        Write-Host "0. Back to Main Menu"
        Write-Host ""
        
        $opt = Read-MenuChoice
        switch ($opt) {
            "1" {
                $key = Read-Host "Enter Product Key"
                if (![string]::IsNullOrWhiteSpace($key)) {
                    Invoke-Slmgr "/ipk $key"
                }
                Pause
            }
            "2" {
                $server = Read-Host "Enter KMS Server Address (e.g., kms.example.com)"
                if (![string]::IsNullOrWhiteSpace($server)) {
                    Invoke-Slmgr "/skms $server"
                }
                Pause
            }
            "3" {
                Invoke-Slmgr "/ato"
                Pause
            }
            "4" {
                Invoke-Slmgr "/ckms"
                Pause
            }
            "0" {
                $kmsLoop = $false
            }
            default { Write-Host "Invalid option." -ForegroundColor Red; Start-Sleep -Seconds 1 }
        }
    }
}

function Invoke-DowngradeSetup {
    param([string]$SetupKey)
    Write-Host ""
    $auto = Read-MenuChoice "Do you want to automatically select an ISO and start the installation now? (Y/N)"
    if ($auto -match "^[Yy]") {
        Add-Type -AssemblyName System.Windows.Forms
        $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
        $openFileDialog.Filter = "ISO Files (*.iso)|*.iso|All Files (*.*)|*.*"
        $openFileDialog.Title = "Select Windows ISO File"
        
        # Form required to bring dialog to front
        $form = New-Object System.Windows.Forms.Form
        $form.TopMost = $true
        
        if ($openFileDialog.ShowDialog($form) -eq [System.Windows.Forms.DialogResult]::OK) {
            $isoPath = $openFileDialog.FileName
            Write-Host "`nMounting ISO: $isoPath" -ForegroundColor Cyan
            
            $mountResult = Mount-DiskImage -ImagePath $isoPath -PassThru
            $driveLetter = ($mountResult | Get-Volume).DriveLetter
            
            if (-not $driveLetter) {
                Write-Host "Waiting for drive to be ready..." -ForegroundColor DarkGray
                Start-Sleep -Seconds 3
                $driveLetter = (Get-DiskImage -ImagePath $isoPath | Get-Volume).DriveLetter
            }
            
            if ($driveLetter) {
                Write-Host "ISO mounted at $($driveLetter):\" -ForegroundColor Green
                
                $setupPath = "$($driveLetter):\setup.exe"
                if (Test-Path $setupPath) {
                    Write-Host "Launching Windows Setup with /pkey to bypass BIOS key..." -ForegroundColor Yellow
                    Start-Process -FilePath $setupPath -ArgumentList "/pkey $SetupKey"
                } else {
                    Write-Host "setup.exe not found on the mounted drive." -ForegroundColor Red
                }
            } else {
                Write-Host "Failed to get drive letter for mounted ISO." -ForegroundColor Red
            }
        } else {
            Write-Host "ISO selection cancelled." -ForegroundColor Yellow
        }
    } else {
        Write-Host "Please run setup.exe from your Windows installation media with parameter /pkey $SetupKey" -ForegroundColor Yellow
    }
}

function Restore-BiosEdition {
    Show-Header
    Write-Host "--- Restore BIOS/OEM Edition ---" -ForegroundColor Cyan
    try {
        $biosInfo = Get-BiosKeyInfo
        $key = if ($biosInfo) { $biosInfo.Key } else { $null }
        $desc = if ($biosInfo) { $biosInfo.Description } else { $null }
        
        if ([string]::IsNullOrWhiteSpace($key)) {
            Write-Host "No BIOS/OEM key detected on this system." -ForegroundColor Red
            Pause
            return
        }
        
        Write-Host "BIOS Key Found : $key" -ForegroundColor Green
        Write-Host "Description    : $desc"
        
        $editionId = ""
        $productName = ""
        
        if ($desc -match "CoreSingleLanguage") {
            $editionId = "CoreSingleLanguage"
            $productName = "Windows 10 Home Single Language"
        } elseif ($desc -match "Core") {
            $editionId = "Core"
            $productName = "Windows 10 Home"
        } elseif ($desc -match "Professional") {
            $editionId = "Professional"
            $productName = "Windows 10 Pro"
        } elseif ($desc -match "Education") {
            $editionId = "Education"
            $productName = "Windows 10 Education"
        } elseif ($desc -match "Enterprise") {
            $editionId = "Enterprise"
            $productName = "Windows 10 Enterprise"
        } else {
            Write-Host "Warning: Could not strictly determine target EditionID from description." -ForegroundColor Yellow
            $editionId = Read-Host "Please enter the target EditionID manually (e.g. Core, Professional)"
            $productName = Read-Host "Please enter the target ProductName manually (e.g. Windows 10 Home)"
        }
        
        Write-Host ""
        Write-Host "Target Edition: $productName ($editionId)"
        Write-Host "1. Upgrade to this edition (slmgr /ipk)"
        Write-Host "2. Downgrade to this edition (Registry change + In-place upgrade)"
        Write-Host "0. Cancel"
        Write-Host ""
        $opt = Read-MenuChoice
        
        if ($opt -eq "1") {
            Write-Host "Applying BIOS product key $key ..."
            Invoke-Slmgr "/ipk $key"
            Write-Host "Please restart your PC if required to complete the upgrade." -ForegroundColor Yellow
        } elseif ($opt -eq "2") {
            $regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
            Set-ItemProperty -Path $regPath -Name "EditionID" -Value $editionId -ErrorAction Stop
            Set-ItemProperty -Path $regPath -Name "ProductName" -Value $productName -ErrorAction Stop
            Write-Host "Successfully set EditionID to $editionId and ProductName to $productName." -ForegroundColor Green
            Invoke-DowngradeSetup -SetupKey $key
        }
    } catch {
        Write-Host "Error: $_" -ForegroundColor Red
    }
    Pause
}

function Upgrade-Edition {
    Show-Header
    Write-Host "--- Upgrade Edition ---" -ForegroundColor Cyan
    Write-Host "This will upgrade your Windows edition using generic keys."
    Write-Host "Target Edition:"
    Write-Host "1. Pro"
    Write-Host "2. Pro Education"
    Write-Host "3. Pro for Workstations"
    Write-Host "4. Education"
    Write-Host "5. Enterprise"
    Write-Host "0. Cancel"
    Write-Host ""
    
    $opt = Read-MenuChoice
    $key = ""
    switch ($opt) {
        "1" { $key = "VK7JG-NPHTM-C97JM-9MPGT-3V66T" }
        "2" { $key = "8PTT6-RNW4C-6V7J2-C2D3X-MHBPB" }
        "3" { $key = "NRG8B-VKK3Q-CXVCJ-9G2XF-VKQIG" }
        "4" { $key = "YNMGQ-8RYV3-4PGQ3-C8XTP-7CFBY" }
        "5" { $key = "XGVPP-NMH47-7TTHJ-W3FW7-8HV2C" }
        "0" { return }
        default { Write-Host "Invalid choice." -ForegroundColor Red; Start-Sleep -Seconds 1; return }
    }
    
    Write-Host "Applying product key $key ..."
    Invoke-Slmgr "/ipk $key"
    Write-Host "Please restart your PC if required to complete the upgrade." -ForegroundColor Yellow
    Pause
}

function Prepare-EditionDowngrade {
    Show-Header
    Write-Host "--- Prepare Edition Downgrade ---" -ForegroundColor Cyan
    Write-Host "This will modify the registry to allow downgrading via in-place upgrade."
    Write-Host "Target Edition:"
    Write-Host "1. Home"
    Write-Host "2. Home Single Language"
    Write-Host "3. Pro"
    Write-Host "0. Cancel"
    Write-Host ""
    
    $opt = Read-MenuChoice
    $editionId = ""
    $productName = ""
    $setupKey = ""
    
    switch ($opt) {
        "1" { $editionId = "Core"; $productName = "Windows 10 Home"; $setupKey = "YTMG3-N6DKC-DKB77-7M9GH-8HVX7" }
        "2" { $editionId = "CoreSingleLanguage"; $productName = "Windows 10 Home Single Language"; $setupKey = "BT79Q-G7N6G-PGBYW-4YWX6-6F4BT" }
        "3" { $editionId = "Professional"; $productName = "Windows 10 Pro"; $setupKey = "VK7JG-NPHTM-C97JM-9MPGT-3V66T" }
        "0" { return }
        default { Write-Host "Invalid choice." -ForegroundColor Red; Start-Sleep -Seconds 1; return }
    }
    
    $regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
    try {
        Set-ItemProperty -Path $regPath -Name "EditionID" -Value $editionId -ErrorAction Stop
        Set-ItemProperty -Path $regPath -Name "ProductName" -Value $productName -ErrorAction Stop
        Write-Host "Successfully set EditionID to $editionId and ProductName to $productName." -ForegroundColor Green
        
        Invoke-DowngradeSetup -SetupKey $setupKey
    } catch {
        Write-Host "Error: $_" -ForegroundColor Red
    }
    Pause
}

function Show-EditionConversionMenu {
    $convLoop = $true
    while ($convLoop) {
        Show-Header
        Write-Host "--- Edition Conversion Menu ---" -ForegroundColor Cyan
        Write-Host "1. Upgrade Edition (e.g. Home -> Pro)"
        Write-Host "2. Prepare Edition Downgrade (via Registry)"
        Write-Host "3. Auto-detect BIOS Key & Restore Edition"
        Write-Host "0. Back to Main Menu"
        Write-Host ""
        
        $opt = Read-MenuChoice
        switch ($opt) {
            "1" { Upgrade-Edition }
            "2" { Prepare-EditionDowngrade }
            "3" { Restore-BiosEdition }
            "0" { $convLoop = $false }
            default { Write-Host "Invalid option." -ForegroundColor Red; Start-Sleep -Seconds 1 }
        }
    }
}

function Get-DecodedProductKey {
    $productKey = "Not Found"
    try {
        $digitalProductId = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name "DigitalProductId" -ErrorAction SilentlyContinue).DigitalProductId
        if ($digitalProductId -and $digitalProductId.Length -ge 67) {
            $isWin8OrUp = [math]::Truncate($digitalProductId[66] / 6) -band 1
            $digitalProductId[66] = ($digitalProductId[66] -band 247) -bor (($isWin8OrUp -band 2) * 4)
            $chars = "BCDFGHJKMPQRTVWXY2346789"
            $decodedChars = New-Object char[] 29
            $last = 0
            for ($i = 24; $i -ge 0; $i--) {
                $current = 0
                for ($j = 14; $j -ge 0; $j--) {
                    $current = ($current * 256) -bxor $digitalProductId[$j + 52]
                    $digitalProductId[$j + 52] = [math]::Truncate($current / 24)
                    $current = $current % 24
                }
                $decodedChars[$i] = $chars[$current]
                $last = $current
            }
            
            $fullKey = ""
            if ($isWin8OrUp -eq 1) {
                $keyPart1 = ""
                $keyPart2 = ""
                if ($last -gt 0) { $keyPart1 = $decodedChars[1..$last] -join '' }
                if ($last -lt 24) { $keyPart2 = $decodedChars[($last + 1)..24] -join '' }
                $fullKey = $keyPart1 + "N" + $keyPart2
            } else {
                $fullKey = $decodedChars[0..24] -join ''
            }
            
            if ($fullKey.Length -eq 25) {
                $productKey = "{0}-{1}-{2}-{3}-{4}" -f $fullKey.Substring(0,5), $fullKey.Substring(5,5), $fullKey.Substring(10,5), $fullKey.Substring(15,5), $fullKey.Substring(20,5)
            }
        }
    } catch {}
    
    return $productKey
}

function Check-ComprehensiveLicense {
    Show-Header
    Write-Host "--- Comprehensive Windows License Check ---" -ForegroundColor Cyan
    
    Write-Host "[*] 1/5 Retrieving Basic OS Information..." -ForegroundColor DarkGray
    $osName = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -ErrorAction SilentlyContinue).ProductName
    $osBuild = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -ErrorAction SilentlyContinue).CurrentBuild
    if ([int]$osBuild -ge 22000) { $osName = $osName -replace "Windows 10", "Windows 11" }
    
    Write-Host "[*] 2/5 Decoding Product Key from Registry..." -ForegroundColor DarkGray
    $fullKey = Get-DecodedProductKey
    
    $tempPath = [System.IO.Path]::GetTempPath()
    $xprFile = Join-Path $tempPath "dtool_xpr.txt"

    Write-Host "[*] 3/5 Querying Activation Status (slmgr /xpr)..." -ForegroundColor DarkGray
    Start-Process -FilePath "cscript" -ArgumentList "//Nologo `"$env:windir\system32\slmgr.vbs`" /xpr" -RedirectStandardOutput $xprFile -NoNewWindow -Wait

    Write-Host "[*] 4/5 Fetching Active License Details..." -ForegroundColor DarkGray
    $activeLic = Get-ActiveLicenses | Where-Object { $_.Name -match "Windows" } | Select-Object -First 1
    
    $partialKey = "XXXXX"
    if ($activeLic -and $activeLic.PartialProductKey) {
        $partialKey = $activeLic.PartialProductKey
    }

    if ($fullKey -eq "BBBBB-BBBBB-BBBBB-BBBBB-BBBBB" -or $fullKey -eq "Not Found") {
        $fullKey = if ($partialKey -ne "XXXXX") { "*****-*****-*****-*****-" + $partialKey } else { "[Key Unreadable]" }
    }

    $channel = "Not Found"
    if ($activeLic) {
        if ($activeLic.Description -match "RETAIL") { $channel = "RETAIL" } 
        elseif ($activeLic.Description -match "OEM") { $channel = "OEM" } 
        elseif ($activeLic.Description -match "VOLUME_MAK|MAK") { $channel = "VOLUME MAK" } 
        elseif ($activeLic.Description -match "VOLUME_KMSCLIENT|KMS|GVLK") { $channel = "VOLUME KMS" }
    }

    $activationStatus = "NOT ACTIVATED"
    $xprText = if (Test-Path $xprFile) { Get-Content $xprFile -Raw } else { "" }
    if ($xprText -match "permanently activated") { $activationStatus = "ACTIVATED" }
    elseif ($xprText -match "will expire") { $activationStatus = "ACTIVATED (EXPIRING)" }

    Write-Host "[*] 5/5 Checking BIOS/OEM Key..." -ForegroundColor DarkGray
    $biosInfo = Get-BiosKeyInfo
    $biosKey = if ($biosInfo -and $biosInfo.Key) { $biosInfo.Key } else { "NOT_FOUND" }

    Write-Host "`n==================================================" -ForegroundColor Cyan
    Write-Host "[SECURITY & CRACK TRACES ANALYSIS]" -ForegroundColor White
    
    function Print-ScanLine($id, $name, $status, $msg) {
        $namePadded = $name.PadRight(18)
        if ($status) { Write-Host "[+] $id. $($namePadded): $msg" -ForegroundColor Green } 
        else { Write-Host "[-] $id. $($namePadded): $msg" -ForegroundColor Red }
    }

    # Initialize Scan Results
    $isCrack = $false
    $scanKms = $true; $msgKms = "No illegal KMS server configuration found."
    $scanMas = $true; $msgMas = "Command history is clean. No cracking behavior detected."
    $scanKms38 = $true; $msgKms38 = "Expiration logic structure is consistent and valid."
    $scanLogic = $true; $msgLogic = "Licensing channel and BIOS matching valid."
    $scanFolder = $true; $msgFolder = "No KMS emulator folders found."
    $scanTask = $true; $msgTask = "No illegal renewal tasks found in Task Scheduler."
    $scanReg = $true; $msgReg = "Registry is intact and not tampered with."

    # Crack Detection
    Write-Host "`n[*] Scanning for KMS Crack..." -ForegroundColor DarkGray
    Start-Sleep -Milliseconds 400
    if ($channel -eq "VOLUME KMS") {
        $kmsServer = "Unknown"
        try {
            $slp = Get-ActiveLicenses | Where-Object { $_.KeyManagementServiceMachine } | Select-Object -First 1
            if ($slp -and $slp.KeyManagementServiceMachine) { $kmsServer = $slp.KeyManagementServiceMachine.ToLower() }
        } catch {}

        $fakeKmsServers = @("127\.0\.0\.1", "0\.0\.0\.0", "localhost", "kms\.loli\.net", "kms\.msgang\.com", "kms\.digiboy\.ir", "kms\.cangshui\.net", "kms\.03k\.org", "kms\.tee\.party", "massgrave", "luody\.info", "kms\.lotro\.cc")
        foreach ($fake in $fakeKmsServers) {
            if ($kmsServer -match $fake) { 
                $scanKms = $false; $msgKms = "DETECTED illegal/virtual KMS server ($kmsServer)."
                $isCrack = $true; break 
            }
        }
        if ($scanKms -and $kmsServer -ne "Unknown") { $msgKms = "Connected server: $kmsServer" }
    }

    $badServices = @("AutoKMS", "KMSELDI", "SppExtComObjHook")
    if (Get-Service -Name $badServices -ErrorAction SilentlyContinue) {
        $scanKms = $false; $msgKms = "DETECTED background service of KMS crack tool."
        $isCrack = $true
    }
    $hostsPath = "$env:windir\System32\drivers\etc\hosts"
    if (Test-Path $hostsPath) {
        if ((Get-Content $hostsPath -Raw) -match "(127\.0\.0\.1|activation\.sls\.microsoft\.com).+microsoft") {
            $scanKms = $false; $msgKms = "DETECTED Hosts file modified to block Microsoft servers."
            $isCrack = $true
        }
    }
    Print-ScanLine "1" "KMS Crack" $scanKms $msgKms

    Write-Host "[*] Scanning for MAS / HWID script traces..." -ForegroundColor DarkGray
    Start-Sleep -Milliseconds 400
    $historyPath = "$env:APPDATA\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt"
    if (Test-Path $historyPath) {
        if ((Get-Content $historyPath -Raw -ErrorAction SilentlyContinue) -match "massgrave|mas\.dev|hwid|kms") {
            $scanMas = $false; $msgMas = "DETECTED history of online crack script execution."
            $isCrack = $true
        }
    }
    Print-ScanLine "2" "MAS / HWID" $scanMas $msgMas

    Write-Host "[*] Scanning for KMS38 Hook..." -ForegroundColor DarkGray
    Start-Sleep -Milliseconds 400
    if ($xprText -match "2038") {
        $scanKms38 = $false; $msgKms38 = "DETECTED abnormal expiration date structure (KMS38)."
        $isCrack = $true
    }
    Print-ScanLine "3" "KMS38 Hook" $scanKms38 $msgKms38

    Write-Host "[*] Checking License Logic & BIOS match..." -ForegroundColor DarkGray
    Start-Sleep -Milliseconds 400
    $hwidKeys = @("3V66T","T83GX","YKHCF","TXYCV","8HVX7","233PK","8XC4K","WFG99","6F4BT","YTDFH","2YT43","H8Q99","7CFBY","VCFB2","J8JXD","8HV2C","PDQGT","YY74H","2YV77","6Q84J")
    $isHwidWarn = $false
    if ($hwidKeys -contains $partialKey) {
        $isHwidWarn = $true
        if ($biosKey -eq "NOT_FOUND") {
            $scanLogic = $true; $msgLogic = "Digital License (Likely Custom Build)."
        } else {
            $scanLogic = $false; $msgLogic = "DETECTED: Original Key bypassed, system forced to activate using Generic Key."
            $isCrack = $true
        }
    }
    Print-ScanLine "4" "License Logic" $scanLogic $msgLogic

    Write-Host "[*] Scanning for Illegal Emulator Folders..." -ForegroundColor DarkGray
    Start-Sleep -Milliseconds 400
    $suspiciousFolders = @("$env:windir\KMS", "$env:windir\AutoKMS", "$env:ProgramData\KMSAutoS")
    foreach ($folder in $suspiciousFolders) {
        if (Test-Path $folder) {
            $scanFolder = $false; $msgFolder = "DETECTED folder containing crack payload."
            $isCrack = $true; break
        }
    }
    Print-ScanLine "5" "Illegal Folders" $scanFolder $msgFolder

    Write-Host "[*] Scanning for Hidden Scheduled Tasks..." -ForegroundColor DarkGray
    Start-Sleep -Milliseconds 400
    $crackTasks = @("AutoKMS", "AutoPico Daily Restart", "KMSAutoNet")
    $foundTasks = Get-ScheduledTask -TaskName $crackTasks -ErrorAction SilentlyContinue
    if ($foundTasks) {
        $taskNames = ($foundTasks | Select-Object -ExpandProperty TaskName) -join ", "
        $scanTask = $false; $msgTask = "DETECTED background tasks: $taskNames" 
        $isCrack = $true
    }
    Print-ScanLine "6" "Hidden Tasks" $scanTask $msgTask

    Write-Host "[*] Scanning for Registry Activation Hacks..." -ForegroundColor DarkGray
    Start-Sleep -Milliseconds 400
    $sppPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\CurrentVersion\Software Protection Platform"
    try {
        if ((Get-ItemProperty -Path $sppPolicyPath -Name "NoGenTicket" -ErrorAction Stop).NoGenTicket -eq 1) {
            $scanReg = $false; $msgReg = "DETECTED 'NoGenTicket' key blocking system authentication."
            $isCrack = $true
        }
    } catch {}
    Print-ScanLine "7" "Registry Hacks" $scanReg $msgReg

    # Print Final Verification Report
    Write-Host "`n==================================================" -ForegroundColor Cyan
    Write-Host "           FINAL VERIFICATION RESULT"
    Write-Host "=================================================="
    Write-Host "Windows Edition  : $osName" -ForegroundColor Cyan
    
    if ($isCrack) {
        Write-Host "License Status   : " -NoNewline; Write-Host "INVALID (CRACKED)" -ForegroundColor Red
    } elseif ($activationStatus -eq "NOT ACTIVATED") {
        Write-Host "License Status   : " -NoNewline; Write-Host "NO LICENSE" -ForegroundColor Red
    } elseif ($isHwidWarn -and $biosKey -eq "NOT_FOUND") {
        Write-Host "License Status   : " -NoNewline; Write-Host "DIGITAL LICENSE (REQUIRES VERIFICATION)" -ForegroundColor Yellow
    } elseif ($channel -eq "VOLUME MAK") {
        Write-Host "License Status   : " -NoNewline; Write-Host "ENTERPRISE KEY (MAK)" -ForegroundColor Yellow
    } else {
        Write-Host "License Status   : " -NoNewline; Write-Host "VALID" -ForegroundColor Green
    }
    
    Write-Host "Activation State : $activationStatus"
    Write-Host "License Channel  : $channel"
    Write-Host ""
    Write-Host "Windows Key      : $fullKey" -ForegroundColor Magenta
    Write-Host "BIOS Key         : $biosKey" -ForegroundColor Magenta
    Write-Host ""

    Write-Host "==================================================" -ForegroundColor Cyan

    if ($isCrack) {
        Write-Host "`n[CONCLUSION]" -ForegroundColor Red
        Write-Host "-> WARNING: SYSTEM IS USING A CRACK (KMS / ONLINE SCRIPT)."
        Write-Host "The license is connected to insecure servers."
        if ($biosKey -ne "NOT_FOUND") {
            Write-Host "`n[!!! IMPORTANT !!!]" -ForegroundColor Yellow
            Write-Host "Your device actually HAS an ORIGINAL LICENSE hidden in the motherboard."
            Write-Host "Consider restoring it instead of using a cracked key."
        }
        
        Write-Host ""
        $fixChoice = Read-MenuChoice "Do you want to automatically clean up and fix these issues? (Y/N)"
        if ($fixChoice -match "^[Yy]") {
            Write-Host "`n--- Beginning Cleanup & Fixes ---" -ForegroundColor Cyan
            
            if (-not $scanKms) {
                Write-Host "[*] Clearing KMS Server..." -ForegroundColor Yellow
                Invoke-Slmgr "/ckms"
                
                Write-Host "[*] Stopping and disabling known crack services..." -ForegroundColor Yellow
                foreach ($srv in $badServices) {
                    if (Get-Service -Name $srv -ErrorAction SilentlyContinue) {
                        Stop-Service -Name $srv -Force -ErrorAction SilentlyContinue
                        Set-Service -Name $srv -StartupType Disabled -ErrorAction SilentlyContinue
                    }
                }
            }
            
            if (Test-Path $hostsPath) {
                Write-Host "[*] Cleaning Hosts file from Microsoft server blocks..." -ForegroundColor Yellow
                $hostsContent = Get-Content $hostsPath -ErrorAction SilentlyContinue
                if ($hostsContent) {
                    $cleanHosts = $hostsContent | Where-Object { $_ -notmatch "(127\.0\.0\.1|0\.0\.0\.0|activation\.sls\.microsoft\.com).+microsoft" }
                    $cleanHosts | Set-Content $hostsPath -Force -ErrorAction SilentlyContinue
                }
            }
            
            if (-not $scanFolder) {
                Write-Host "[*] Removing illegal emulator folders..." -ForegroundColor Yellow
                foreach ($folder in $suspiciousFolders) {
                    if (Test-Path $folder) { Remove-Item -Path $folder -Recurse -Force -ErrorAction SilentlyContinue }
                }
            }
            
            if (-not $scanTask) {
                Write-Host "[*] Removing hidden scheduled tasks..." -ForegroundColor Yellow
                foreach ($task in $crackTasks) {
                    Unregister-ScheduledTask -TaskName $task -Confirm:$false -ErrorAction SilentlyContinue
                }
            }
            
            if (-not $scanReg) {
                Write-Host "[*] Fixing Registry Activation Hacks..." -ForegroundColor Yellow
                Remove-ItemProperty -Path $sppPolicyPath -Name "NoGenTicket" -ErrorAction SilentlyContinue
            }
            
            if (-not $scanMas) {
                Write-Host "[*] Cleaning PowerShell history traces..." -ForegroundColor Yellow
                if (Test-Path $historyPath) { Remove-Item -Path $historyPath -Force -ErrorAction SilentlyContinue }
            }
            
            Write-Host "[*] Uninstalling cracked product key and clearing registry..." -ForegroundColor Yellow
            Invoke-Slmgr "/upk"
            Invoke-Slmgr "/cpky"
            
            if ($biosKey -ne "NOT_FOUND") {
                Write-Host "[*] Restoring original BIOS/OEM product key..." -ForegroundColor Green
                Invoke-Slmgr "/ipk $biosKey"
            } else {
                Write-Host "[*] Rearming license state..." -ForegroundColor Yellow
                Invoke-Slmgr "/rearm"
            }
            
            Write-Host "`n[+] Cleanup complete! Please RESTART your computer to apply all changes." -ForegroundColor Green
        }
    } elseif ($activationStatus -eq "NOT ACTIVATED") {
        Write-Host "`n[CONCLUSION]" -ForegroundColor Red
        Write-Host "-> WARNING: System is not activated."
    } elseif ($isHwidWarn -and $biosKey -eq "NOT_FOUND") {
        Write-Host "`n[CONCLUSION]" -ForegroundColor Yellow
        Write-Host "-> SYSTEM IS CLEAN: NO BACKGROUND CRACKING PROCESSES."
        Write-Host "`nHowever, the system uses a Generic Key without a BIOS key."
        Write-Host "This could be HWID/MAS activation or a valid hardware-linked digital license."
        Write-Host "You may need an original purchase invoice or Retail key to prove validity."
    } else {
        Write-Host "`n[CONCLUSION]" -ForegroundColor Green
        Write-Host "-> SYSTEM IS CLEAN: LICENSE IS VALID, NO TRACES OF CRACKING."
    }

    if ($biosKey -ne "NOT_FOUND") {
        Write-Host "`n-> CONGRATULATIONS! This device has a GENUINE built-in license." -ForegroundColor Cyan
    }
    
    Write-Host ""
    Pause
}

# Main Loop
$running = $true
while ($running) {
    Show-Header
    Write-Host "--- Information & Checking ---" -ForegroundColor Yellow
    Write-Host "1. Show Windows Version & Basic License Info"
    Write-Host "2. Show Detailed License Info (slmgr /dlv)"
    Write-Host "3. Show BIOS/OEM Key"
    Write-Host "4. Comprehensive License Check (IWC)"
    Write-Host "`n--- Management & Troubleshooting ---" -ForegroundColor Yellow
    Write-Host "5. Remove Current License"
    Write-Host "6. Reset Activation (Rearm)"
    Write-Host "`n--- Tools & Advanced ---" -ForegroundColor Yellow
    Write-Host "7. KMS Activation Menu"
    Write-Host "8. Edition Conversion Menu"
    Write-Host "9. Switch to dtool (System Utilities)"
    Write-Host "`n0. Exit"
    Write-Host ""
    
    $choice = Read-MenuChoice
    
    switch ($choice) {
        "1" { Show-BasicInfo }
        "2" { 
            Write-Host "`n--- BIOS Key Match Status ---" -ForegroundColor Cyan
            try {
                $biosInfo = Get-BiosKeyInfo
                $biosKey = if ($biosInfo) { $biosInfo.Key } else { $null }
                if (![string]::IsNullOrWhiteSpace($biosKey) -and $biosKey.Length -ge 5) {
                    $last5 = $biosKey.Substring($biosKey.Length - 5)
                    $lic = Get-ActiveLicenses
                    $matched = $false
                    if ($lic) {
                        foreach ($l in $lic) {
                            if ($l.Name -match "Windows" -and $l.PartialProductKey -eq $last5) { $matched = $true }
                        }
                    }
                    if ($matched) {
                        Write-Host "BIOS Match    : Yes (Current key matches BIOS key)" -ForegroundColor Green
                    } else {
                        Write-Host "BIOS Match    : No (Current key does not match BIOS key)" -ForegroundColor Yellow
                    }
                } else {
                    Write-Host "BIOS Match    : N/A (No BIOS key found)" -ForegroundColor DarkGray
                }
            } catch { }
            Invoke-Slmgr "/dlv"
            Pause 
        }
        "3" { Show-BiosKey }
        "4" { Check-ComprehensiveLicense }
        "5" { Remove-License }
        "6" { Reset-Activation }
        "7" { Show-KmsMenu }
        "8" { Show-EditionConversionMenu }
        "9" { 
            Write-Host "`n--- Launch dtool ---" -ForegroundColor Cyan
            Write-Host "Downloading and executing dtool script..."
            try {
                irm https://raw.githubusercontent.com/tctvn/dtool/main/dtool.ps1 | iex
            } catch {
                Write-Host "Failed to execute script: $_" -ForegroundColor Red
            }
        }
        "0" { $running = $false }
        default { Write-Host "Invalid choice, please try again." -ForegroundColor Red; Start-Sleep -Seconds 1 }
    }
}
Write-Host "Exiting..." -ForegroundColor DarkGray
