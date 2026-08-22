# AI Coding System - Coder + Reviewer Agent

A dual-terminal AI coding system with agentic coder and senior-level code reviewer.

---

## ⚡ Quick Install (One Command)

Open **PowerShell** and run:

```powershell
iex (irm https://raw.githubusercontent.com/iantolentino/opencode-agents-setup/main/install.ps1)
```

That's it. The installer will:
1. Clone this repo to `C:\Users\YourName\opencode-agents`
2. Install Python dependencies
3. Prompt for your API keys (loop to add multiple)
4. Launch both agents automatically in 2 terminals

**Next time on any machine:** Just run the same command above. If config exists, it skips setup and launches directly.

---

## Features

- **🤖 Coder Agent**: Agentic coding assistant (reads files, plans, writes code)
- **👁️ Reviewer Agent**: Senior-level code review (architecture, security, performance)
- **🔄 Auto-Rotating APIs**: Seamlessly switches between free APIs when limits are reached
- **📊 Token Tracking**: Daily usage stats per API
- **🎯 Easy Setup**: One-command install from anywhere

---

## Prerequisites

- Python 3.8+ (install from [python.org](https://python.org) — check **Add to PATH**)
- Git (install from [git-scm.com](https://git-scm.com))
- PowerShell (built-in on Windows 11)
- At least one free API key:
  - [Google Gemini](https://aistudio.google.com) — 1,500 requests/day free, no credit card
  - [DeepSeek](https://platform.deepseek.com) — 5M token grant on signup (30 days)
  - [Groq](https://console.groq.com) — Free tier available
  - [Amazon Q](https://aws.amazon.com/codewhisperer/) — 50 agentic requests/day free

---

## Usage

### Before Launching

`cd` to your project folder first in both terminals after they open:

```bash
cd C:\Users\Soyk\Projects\myapp
```

The agents work on whatever directory you're in.

---

### Terminal 1: Coder Agent

```
🤖 Coder Agent - Ready
Working directory: C:\Users\Soyk\Projects\myapp

Commands:
  read <filepath>       - Read a file
  list [directory]      - List files
  write <filepath>      - Write/create file
  status                - Show API status
  help                  - Show this help
  exit                  - Exit agent

you> refactor this function to use async/await
you> read src/app.js
you> list
you> help me optimize this database query
you> status
```

---

### Terminal 2: Reviewer Agent

```
👁️  Reviewer Agent - Ready
Working directory: C:\Users\Soyk\Projects\myapp

Commands:
  review <filepath>     - Review a file
  read <filepath>       - Read a file
  list [directory]      - List files
  status                - Show API status
  help                  - Show this help
  exit                  - Exit agent

reviewer> review src/auth.js
reviewer> what are security considerations for this?
reviewer> read src/api.js
reviewer> status
```

---

## API Keys

### Getting Free Keys

| Provider  | Link                              | Limit               | Notes              |
| --------- | --------------------------------- | ------------------- | ------------------ |
| Gemini    | https://aistudio.google.com       | 1,500 requests/day  | Permanent free ✅  |
| DeepSeek  | https://platform.deepseek.com     | 5M tokens (30 days) | Then pay-per-token |
| Groq      | https://console.groq.com          | Varies              | Free tier          |
| Amazon Q  | AWS Console → Amazon Q            | 50 agentic reqs/day | AWS account needed |

### Adding Keys

During install, the prompt loops:
```
Provider (gemini/deepseek/groq/amazon-q): gemini
Paste API Key: AIza...
Add another API key? (y/n): y

Provider (gemini/deepseek/groq/amazon-q): groq
Paste API Key: gsk_...
Add another API key? (y/n): n
```

Keys are saved locally in `config.json` — **never pushed to GitHub**.

---

## How Auto-Rotation Works

1. Uses first available API with quota remaining
2. When daily limit hit → automatically switches to next API
3. Seamless: no interruption to your session
4. Use `status` command to see remaining quota per API

---

## config.json (Local Only, Never Committed)

Auto-generated after setup:

```json
{
  "apis": [
    {
      "name": "gemini-1",
      "provider": "gemini",
      "api_key": "your-key-here",
      "daily_limit": 1500,
      "daily_used": 0
    }
  ],
  "setup_complete": true
}
```

Daily usage resets automatically each day.

---

## File Structure

```
opencode-agents/
├── install.ps1             # One-command installer
├── launch.bat              # Manual launcher (Windows)
├── coder.py                # Coder agent
├── reviewer.py             # Reviewer agent
├── config_manager.py       # Manages API keys
├── api_router.py           # API selection & rotation
├── token_tracker.py        # Usage tracking
├── requirements.txt        # Python dependencies
├── config.json             # YOUR KEYS (auto-generated, git-ignored)
├── tracker.json            # Usage stats (auto-generated, git-ignored)
├── .gitignore              # Prevents key leaks
└── README.md               # This file
```

---

## Troubleshooting

**"Python not found"**
→ Install from python.org, check "Add Python to PATH"

**"git is not recognized"**
→ Install from git-scm.com

**"No API keys configured"**
→ Re-run the install command and add keys when prompted

**"All APIs have reached daily limits"**
→ Wait for daily reset, or add more free API keys

---

## Security

⚠️ `config.json` contains your API keys — it is **git-ignored** and never pushed to GitHub.

- Keys stay only on your machine
- If you switch machines, re-run the install command and add keys again
- Regenerate keys if accidentally exposed

---

## License

MIT — Use freely, modify as needed.
