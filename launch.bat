@echo off
setlocal enabledelayedexpansion

echo.
echo ========================================
echo    AI Coding System - Setup
echo ========================================
echo.

REM Check if config.json exists
if not exist "config.json" (
    echo Creating new config.json...
    (
        echo {
        echo   "apis": [],
        echo   "setup_complete": false
        echo }
    ) > config.json
)

REM Check if setup is already complete
for /f "tokens=*" %%A in ('findstr "setup_complete" config.json') do (
    if "%%A"=="    "setup_complete": true" (
        echo Config found. Starting agents...
        goto :start_agents
    )
)

REM API Setup Loop
set "api_count=0"
set "temp_config=[" 

:api_loop
set /p "provider=Enter API Provider (gemini/deepseek/groq/amazon-q) or press Enter to skip: "

if "!provider!"=="" goto :finish_setup

set /p "api_key=Paste API Key: "

if "!api_count!"=="0" (
    set "temp_config=!temp_config!{^"name^": ^"!provider!-1^", ^"provider^": ^"!provider!^", ^"api_key^": ^"!api_key!^", ^"daily_limit^": 1500, ^"daily_used^": 0}"
) else (
    set "temp_config=!temp_config!, {^"name^": ^"!provider!-!api_count!^", ^"provider^": ^"!provider!^", ^"api_key^": ^"!api_key!^", ^"daily_limit^": 1500, ^"daily_used^": 0}"
)

set /a "api_count+=1"

set /p "add_more=Add another API key? (y/n): "
if /i "!add_more!"=="y" goto :api_loop

:finish_setup
set "temp_config=!temp_config!]"

(
    echo {
    echo   "apis": %temp_config%,
    echo   "setup_complete": true
    echo }
) > config.json

echo.
echo Setup complete! Starting agents...
echo.

:start_agents
REM Open two terminals
start cmd /k "python coder.py"
start cmd /k "python reviewer.py"

echo Both agents started in separate terminals.
pause
