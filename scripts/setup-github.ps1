#!/usr/bin/env pwsh
# GitHub Repository Setup and Push Script
# This script initializes git, commits your project, and pushes to GitHub

param(
    [string]$GitHubUsername,
    [string]$RepositoryName = "production-eks-deployment",
    [string]$GitUserName,
    [string]$GitUserEmail,
    [switch]$Private
)

# Colors for output
$Green = "`e[32m"
$Yellow = "`e[33m"
$Red = "`e[31m"
$Reset = "`e[0m"

function Write-Info {
    Write-Host "${Green}[INFO]${Reset} $args" -NoNewline
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
# Main Script
# ============================================================================

Write-Host "`n================================"
Write-Host "GitHub Repository Setup Script"
Write-Host "================================`n"

# Get user inputs if not provided
if (-not $GitHubUsername) {
    $GitHubUsername = Read-Host "Chinmayash11"
}

if (-not $RepositoryName) {
    $RepositoryName = Read-Host "Enter repository name (default: production-eks-deployment)" -Default "Devops-demo-project-cps"
}

if (-not $GitUserName) {
    $GitUserName = Read-Host "chinmaya prasad sahoo"
}

if (-not $GitUserEmail) {
    $GitUserEmail = Read-Host "chinmayash11@gmail.com"
}

$RepositoryUrl = "https://github.com/$GitHubUsername/$RepositoryName.git"
$Visibility = if ($Private) { "private" } else { "public" }

Write-Host "`nConfiguration:"
Write-Host "  GitHub Username: $GitHubUsername"
Write-Host "  Repository Name: $RepositoryName"
Write-Host "  Repository URL: $RepositoryUrl"
Write-Host "  Visibility: $Visibility"
Write-Host "  Git User: $GitUserName [$GitUserEmail]"
Write-Host ""

$Confirm = Read-Host "Continue? (y/n)"
if ($Confirm -ne "y") {
    Write-Warning "Setup cancelled"
    exit 0
}

# ============================================================================
# Step 1: Configure Git
# ============================================================================

Write-Host "`n${Green}Step 1: Configuring Git${Reset}"

try {
    git config --global user.name "$GitUserName"
    Write-Success "Git user name set: $GitUserName"
} catch {
    Write-Error "Failed to set git user name"
    exit 1
}

try {
    git config --global user.email "$GitUserEmail"
    Write-Success "Git user email set: $GitUserEmail"
} catch {
    Write-Error "Failed to set git user email"
    exit 1
}

# ============================================================================
# Step 2: Initialize Local Repository
# ============================================================================

Write-Host "`n${Green}Step 2: Initializing Local Repository${Reset}"

if (Test-Path ".git") {
    Write-Warning "Git repository already exists. Skipping initialization."
} else {
    try {
        git init
        Write-Success "Git repository initialized"
    } catch {
        Write-Error "Failed to initialize git repository"
        exit 1
    }
}

# ============================================================================
# Step 3: Stage All Files
# ============================================================================

Write-Host "`n${Green}Step 3: Staging Files${Reset}"

try {
    git add .
    Write-Success "All files staged"
    
    # Show what will be committed
    Write-Host ""
    git status --short | ForEach-Object {
        Write-Host "  $_"
    }
} catch {
    Write-Error "Failed to stage files"
    exit 1
}

# ============================================================================
# Step 4: Create Initial Commit
# ============================================================================

Write-Host "`n${Green}Step 4: Creating Initial Commit${Reset}"

try {
    git commit -m "Initial commit: Production-grade DevOps project with EKS, Terraform, and Kubernetes"
    Write-Success "Initial commit created"
} catch {
    Write-Error "Failed to create commit"
    exit 1
}

# ============================================================================
# Step 5: Rename Branch to Main
# ============================================================================

Write-Host "`n${Green}Step 5: Setting Main Branch${Reset}"

try {
    git branch -M main
    Write-Success "Branch renamed to 'main'"
} catch {
    Write-Error "Failed to rename branch"
    exit 1
}

# ============================================================================
# Step 6: Add Remote Origin
# ============================================================================

Write-Host "`n${Green}Step 6: Adding Remote Origin${Reset}"

# Check if remote already exists
$ExistingRemote = git config --get remote.origin.url 2>$null
if ($ExistingRemote) {
    Write-Warning "Remote 'origin' already exists: $ExistingRemote"
    $UpdateRemote = Read-Host "Update to new URL? (y/n)"
    if ($UpdateRemote -eq "y") {
        git remote remove origin
        git remote add origin $RepositoryUrl
        Write-Success "Remote origin updated: $RepositoryUrl"
    }
} else {
    try {
        git remote add origin $RepositoryUrl
        Write-Success "Remote origin added: $RepositoryUrl"
    } catch {
        Write-Error "Failed to add remote origin"
        exit 1
    }
}

# ============================================================================
# Step 7: Verify Remote Configuration
# ============================================================================

Write-Host "`n${Green}Step 7: Verifying Configuration${Reset}"

try {
    $RemoteUrl = git config --get remote.origin.url
    Write-Success "Remote URL: $RemoteUrl"
    
    $CurrentBranch = git rev-parse --abbrev-ref HEAD
    Write-Success "Current branch: $CurrentBranch"
} catch {
    Write-Error "Failed to verify configuration"
    exit 1
}

# ============================================================================
# Step 8: Push to GitHub
# ============================================================================

Write-Host "`n${Green}Step 8: Pushing to GitHub${Reset}"

Write-Host "`nBefore pushing, please ensure:"
Write-Host "  1. You have created the repository on GitHub"
Write-Host "  2. You are authenticated with GitHub (use 'gh auth login' or SSH keys)"
Write-Host ""

$ProceedPush = Read-Host "Ready to push to GitHub? (y/n)"
if ($ProceedPush -ne "y") {
    Write-Warning "Push cancelled. You can push later with: git push -u origin main"
    exit 0
}

try {
    Write-Host "`nPushing to GitHub (this may prompt for credentials)...`n"
    git push -u origin main
    Write-Success "Successfully pushed to GitHub!"
} catch {
    Write-Error "Failed to push to GitHub"
    Write-Host ""
    Write-Host "Troubleshooting:"
    Write-Host "  1. Verify you created the repository on GitHub: https://github.com/$GitHubUsername/$RepositoryName"
    Write-Host "  2. Authenticate with GitHub using one of:"
    Write-Host "     - gh auth login (GitHub CLI)"
    Write-Host "     - Add SSH key to GitHub"
    Write-Host "     - Use personal access token for HTTPS"
    Write-Host "  3. Then run: git push -u origin main"
    exit 1
}

# ============================================================================
# Success Summary
# ============================================================================

Write-Host "`n================================"
Write-Success "Setup Complete!"
Write-Host "================================`n"

Write-Host "Your repository is ready at:"
Write-Host "  ${Green}$RepositoryUrl${Reset}`n"

Write-Host "Next steps:"
Write-Host "  1. View your repository: https://github.com/$GitHubUsername/$RepositoryName"
Write-Host "  2. Clone elsewhere: git clone $RepositoryUrl"
Write-Host "  3. Make changes and push:"
Write-Host "     - git add ."
Write-Host "     - git commit -m 'Your message'"
Write-Host "     - git push`n"

Write-Host "Useful commands:"
Write-Host "  - Check status: git status"
Write-Host "  - View commits: git log --oneline"
Write-Host "  - Create branch: git checkout -b feature/your-feature"
Write-Host "  - Push branch: git push -u origin feature/your-feature"
