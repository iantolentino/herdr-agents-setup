# AI Coding System - Installer
# Usage: iex (irm https://raw.githubusercontent.com/iantolentino/opencode-agents-setup/main/install.ps1)

Write-Host ""
Write-Host "========================================"
Write-Host "   AI Coding System - Installer"
Write-Host "========================================"
Write-Host ""

# Check Python
Write-Host "Checking Python..."
try {
    $pythonVersion = python --version 2>&1
    Write-Host "✓ Found: $pythonVersion"
} catch {
    Write-Host "❌ Python not found. Please install Python 3.8+ from https://python.org"
    Write-Host "   Make sure to check 'Add Python to PATH' during installation."
    Read-Host "Press Enter to exit"
    exit 1
}

# Set install directory
$installDir = "$env:USERPROFILE\opencode-agents"

# Clone or update repo
if (Test-Path $installDir) {
    Write-Host ""
    Write-Host "Updating existing installation at $installDir..."
    Set-Location $installDir
    git pull origin main
} else {
    Write-Host ""
    Write-Host "Cloning repo to $installDir..."
    git clone https://github.com/iantolentino/opencode-agents-setup.git $installDir
    Set-Location $installDir
}

# Install Python dependencies
Write-Host ""
Write-Host "Installing dependencies..."
python -m pip install -r requirements.txt --quiet
Write-Host "✓ Dependencies installed"

# Check if config.json exists with setup complete
$configExists = $false
if (Test-Path "config.json") {
    $config = Get-Content "config.json" | ConvertFrom-Json
    if ($config.setup_complete -eq $true -and $config.apis.Count -gt 0) {
        $configExists = $true
    }
}

if ($configExists) {
    Write-Host ""
    Write-Host "✓ Config found with $($config.apis.Count) API key(s)."
    $reconfigure = Read-Host "Do you want to add more API keys? (y/n)"
    if ($reconfigure -ne "y") {
        Write-Host ""
        Write-Host "Launching agents..."
        Start-Process cmd -ArgumentList "/k python coder.py"
        Start-Process cmd -ArgumentList "/k python reviewer.py"
        Write-Host "✓ Both agents launched!"
        exit 0
    }
}

# API Key Setup Loop
Write-Host ""
Write-Host "========================================"
Write-Host "   API Key Setup"
Write-Host "========================================"
Write-Host ""
Write-Host "Add your free API keys below."
Write-Host "Get Gemini key (free): https://aistudio.google.com"
Write-Host ""

$apis = @()

:apiLoop while ($true) {
    $provider = Read-Host "Provider (gemini/deepseek/groq/amazon-q) or press Enter to skip"
    
    if ([string]::IsNullOrWhiteSpace($provider)) {
        if ($apis.Count -eq 0) {
            Write-Host "⚠️  No API keys added. You need at least one key to use the agents."
            $retry = Read-Host "Try again? (y/n)"
            if ($retry -eq "y") { continue } else { break }
        }
        break
    }
    
    $apiKey = Read-Host "Paste API Key"
    
    if ([string]::IsNullOrWhiteSpace($apiKey)) {
        Write-Host "⚠️  Empty key skipped."
        continue
    }

    # Determine daily limit per provider
    $dailyLimit = switch ($provider.ToLower()) {
        "gemini"    { 1500 }
        "deepseek"  { "unlimited" }
        "groq"      { 500 }
        "amazon-q"  { 50 }
        default     { 1000 }
    }

    $apiCount = $apis.Count + 1
    $apis += @{
        name        = "$provider-$apiCount"
        provider    = $provider.ToLower()
        api_key     = $apiKey
        daily_limit = $dailyLimit
        daily_used  = 0
    }

    Write-Host "✓ Added $provider key"
    Write-Host ""

    $addMore = Read-Host "Add another API key? (y/n)"
    if ($addMore -ne "y") { break }
    Write-Host ""
}

# Save config.json
$configData = @{
    apis           = $apis
    setup_complete = $true
} | ConvertTo-Json -Depth 5

$configData | Out-File -FilePath "config.json" -Encoding UTF8
Write-Host ""
Write-Host "✓ Config saved with $($apis.Count) API key(s)"

# Launch both agents
Write-Host ""
Write-Host "========================================"
Write-Host "   Launching Agents"
Write-Host "========================================"
Write-Host ""
Write-Host "Opening Terminal 1: Coder Agent..."
Start-Process cmd -ArgumentList "/k cd /d `"$installDir`" && python coder.py"

Start-Sleep -Seconds 1

Write-Host "Opening Terminal 2: Reviewer Agent..."
Start-Process cmd -ArgumentList "/k cd /d `"$installDir`" && python reviewer.py"

Write-Host ""
Write-Host "✓ Both agents launched!"
Write-Host ""
Write-Host "TIP: Next time, just run:"
Write-Host "  iex (irm https://raw.githubusercontent.com/iantolentino/opencode-agents-setup/main/install.ps1)"
Write-Host ""
Write-Host "Or go to $installDir and double-click launch.bat"
Write-Host ""
Read-Host "Press Enter to exit installer"
