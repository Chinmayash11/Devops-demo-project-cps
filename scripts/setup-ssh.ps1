#!/usr/bin/env pwsh
# SSH Key Setup for GitHub Authentication
# This script helps you generate SSH keys and authenticate with GitHub

param(
    [string]$Email,
    [switch]$Force
)

# Colors
$Green = "`e[32m"
$Yellow = "`e[33m"
$Red = "`e[31m"
$Blue = "`e[34m"
$Reset = "`e[0m"

function Write-Info {
    Write-Host "${Blue}[ℹ]${Reset} $args"
}

function Write-Success {
    Write-Host "${Green}[✓]${Reset} $args"
}

function Write-Warning {
    Write-Host "${Yellow}[!]${Reset} $args"
}

function Write-Error {
    Write-Host "${Red}[✗]${Reset} $args"
}

# ============================================================================
# Configuration
# ============================================================================

$SSHDir = "$env:USERPROFILE\.ssh"
$PrivateKeyPath = "$SSHDir\id_ed25519"
$PublicKeyPath = "$SSHDir\id_ed25519.pub"
$SSHConfigPath = "$SSHDir\config"

# ============================================================================
# Helper Functions
# ============================================================================

function Ensure-SSHDirectory {
    if (-not (Test-Path $SSHDir)) {
        Write-Info "Creating SSH directory: $SSHDir"
        New-Item -ItemType Directory -Path $SSHDir -Force | Out-Null
        Write-Success "SSH directory created"
    } else {
        Write-Info "SSH directory exists: $SSHDir"
    }
}

function Check-ExistingKeys {
    if (Test-Path $PrivateKeyPath) {
        Write-Warning "SSH key already exists: $PrivateKeyPath"
        if ($Force) {
            Write-Warning "Overwriting existing key (--Force)"
            Remove-Item $PrivateKeyPath, $PublicKeyPath -Force 2>$null
            return $false
        } else {
            return $true
        }
    }
    return $false
}

function Generate-SSHKey {
    if (-not $Email) {
        $Email = Read-Host "Enter email for SSH key"
    }

    Write-Info "Generating ED25519 SSH key..."
    Write-Info "Email: $Email"
    Write-Host ""

    # Generate SSH key (no passphrase for automation, can add later)
    ssh-keygen -t ed25519 -C "$Email" -f $PrivateKeyPath -N "" | Out-Null

    if (Test-Path $PrivateKeyPath) {
        Write-Success "SSH key generated successfully!"
        Write-Success "  Private key: $PrivateKeyPath"
        Write-Success "  Public key: $PublicKeyPath"
        return $true
    } else {
        Write-Error "Failed to generate SSH key"
        return $false
    }
}

function Display-PublicKey {
    if (Test-Path $PublicKeyPath) {
        $PublicKey = Get-Content $PublicKeyPath
        
        Write-Host "`n$Blue════════════════════════════════════════════$Reset"
        Write-Host "$Blue Your SSH Public Key:$Reset"
        Write-Host "$Blue════════════════════════════════════════════$Reset`n"
        
        Write-Host $PublicKey
        
        Write-Host "`n$Blue════════════════════════════════════════════$Reset`n"
        
        # Copy to clipboard
        $PublicKey | Set-Clipboard
        Write-Success "Public key copied to clipboard!"
        
        return $PublicKey
    }
}

function Create-SSHConfig {
    $ConfigContent = @"
# GitHub SSH Configuration
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519
    AddKeysToAgent yes
    StrictHostKeyChecking no
"@

    if (-not (Test-Path $SSHConfigPath)) {
        Write-Info "Creating SSH config file..."
        Set-Content -Path $SSHConfigPath -Value $ConfigContent
        Write-Success "SSH config created: $SSHConfigPath"
    } else {
        Write-Warning "SSH config already exists"
        $UpdateConfig = Read-Host "Update SSH config? (y/n)"
        if ($UpdateConfig -eq "y") {
            Add-Content -Path $SSHConfigPath -Value "`n$ConfigContent"
            Write-Success "SSH config updated"
        }
    }
}

function Add-KeyToSSHAgent {
    Write-Info "Adding key to SSH agent..."
    
    try {
        # Start SSH agent if not running
        $SSHAgentStatus = Get-Service ssh-agent -ErrorAction SilentlyContinue
        if ($SSHAgentStatus -and $SSHAgentStatus.Status -ne "Running") {
            Start-Service ssh-agent
            Write-Success "SSH agent started"
        }
        
        # Add key to agent
        ssh-add $PrivateKeyPath
        Write-Success "SSH key added to agent"
    } catch {
        Write-Warning "Could not add key to SSH agent: $_"
        Write-Info "You can manually add it later with: ssh-add $PrivateKeyPath"
    }
}

function Test-GitHubConnection {
    Write-Host "`n$Blue Testing GitHub connection...$Reset`n"
    
    try {
        $Output = ssh -T git@github.com 2>&1
        if ($Output -like "*successfully authenticated*") {
            Write-Success "✓ GitHub SSH authentication successful!"
            Write-Host "  $Output`n"
            return $true
        } elseif ($Output -like "*Permission denied*") {
            Write-Error "Permission denied - SSH key not yet added to GitHub account"
            return $false
        } else {
            Write-Info "GitHub response: $Output"
            return $true
        }
    } catch {
        Write-Error "Could not connect to GitHub: $_"
        Write-Warning "This is normal if you haven't added the key to GitHub yet"
        return $false
    }
}

function Show-GitHubInstructions {
    Write-Host "`n$Blue════════════════════════════════════════════$Reset"
    Write-Host "$Green NEXT STEPS: Add SSH Key to GitHub$Reset"
    Write-Host "$Blue════════════════════════════════════════════$Reset`n"
    
    Write-Host "1. Go to GitHub Settings: $Green https://github.com/settings/ssh/new$Reset"
    Write-Host ""
    Write-Host "2. Title: Enter a name like 'Windows Dev Machine'"
    Write-Host ""
    Write-Host "3. Key type: Select 'Authentication Key'"
    Write-Host ""
    Write-Host "4. Key: Paste your public key (already copied to clipboard)"
    Write-Host "   Public key content:"
    Write-Host "   $Blue$(Get-Content $PublicKeyPath)$Reset"
    Write-Host ""
    Write-Host "5. Click 'Add SSH Key'"
    Write-Host ""
    Write-Host "6. Verify connection with:"
    Write-Host "   $Blue ssh -T git@github.com$Reset`n"
}

function Update-GitRemote {
    Write-Host "`n$Blue════════════════════════════════════════════$Reset"
    Write-Host "$Green Update Git Remote to Use SSH$Reset"
    Write-Host "$Blue════════════════════════════════════════════$Reset`n"
    
    $UseRemote = Read-Host "Update git remote to use SSH? (y/n)"
    if ($UseRemote -eq "y") {
        $CurrentRemote = git config --get remote.origin.url 2>$null
        
        if ($CurrentRemote -like "https://*") {
            # Convert HTTPS to SSH
            $SSHRemote = $CurrentRemote -replace "https://github\.com/", "git@github.com:" -replace ".git$", ".git"
            
            Write-Info "Current remote: $CurrentRemote"
            Write-Info "New SSH remote: $SSHRemote"
            
            git remote set-url origin $SSHRemote
            Write-Success "Git remote updated to SSH"
            Write-Host "  New remote: $(git config --get remote.origin.url)`n"
        } else {
            Write-Info "Remote is already using SSH: $CurrentRemote"
        }
    }
}

# ============================================================================
# Main Script
# ============================================================================

Write-Host "`n$Blue════════════════════════════════════════════$Reset"
Write-Host "$Green SSH Key Setup for GitHub$Reset"
Write-Host "$Blue════════════════════════════════════════════$Reset`n"

Write-Info "This script will help you set up SSH authentication with GitHub"
Write-Info "SSH is more secure than HTTPS and easier for automation`n"

# Step 1: Ensure SSH directory exists
Ensure-SSHDirectory

# Step 2: Check for existing keys
if (Check-ExistingKeys) {
    Write-Host ""
    $UseExisting = Read-Host "Use existing SSH key? (y/n)"
    if ($UseExisting -ne "y") {
        exit 0
    }
} else {
    # Step 3: Generate new SSH key
    Write-Host ""
    if (-not (Generate-SSHKey)) {
        Write-Error "SSH key generation failed"
        exit 1
    }
}

# Step 4: Create SSH config
Write-Host ""
Create-SSHConfig

# Step 5: Add key to SSH agent
Write-Host ""
Add-KeyToSSHAgent

# Step 6: Display public key
Write-Host ""
$PublicKey = Display-PublicKey

# Step 7: Show instructions
Show-GitHubInstructions

# Step 8: Ask to test connection
Write-Host ""
$TestConnection = Read-Host "Test GitHub connection now? (y/n)"
if ($TestConnection -eq "y") {
    Write-Host ""
    Write-Warning "If this is your first time, add the key to GitHub first (see instructions above)"
    Write-Host ""
    Test-GitHubConnection
}

# Step 9: Update git remote if in a repo
Write-Host ""
if (Test-Path ".git") {
    Update-GitRemote
}

# Summary
Write-Host "`n$Blue════════════════════════════════════════════$Reset"
Write-Success "SSH Setup Complete!"
Write-Host "$Blue════════════════════════════════════════════$Reset`n"

Write-Host "SSH Key Location:"
Write-Host "  Private: $PrivateKeyPath"
Write-Host "  Public: $PublicKeyPath`n"

Write-Host "Your SSH Key Fingerprint:"
ssh-keygen -l -f $PrivateKeyPath | ForEach-Object { Write-Host "  $_" }
Write-Host ""

Write-Host "Useful SSH Commands:"
Write-Host "  - Test connection: ${Blue}ssh -T git@github.com${Reset}"
Write-Host "  - View key info: ${Blue}ssh-keygen -l -f ~/.ssh/id_ed25519${Reset}"
Write-Host "  - Remove key from agent: ${Blue}ssh-add -d ~/.ssh/id_ed25519${Reset}"
Write-Host "  - Add key to agent: ${Blue}ssh-add ~/.ssh/id_ed25519${Reset}`n"

Write-Host "Git with SSH:"
Write-Host "  - Clone: ${Blue}git clone git@github.com:username/repo.git${Reset}"
Write-Host "  - Push: ${Blue}git push${Reset} (no password needed!)`n"
