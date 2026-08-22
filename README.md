# AI Coding System - Coder + Reviewer Agent

A dual-terminal AI coding system with agentic coder and senior-level code reviewer.

## Features

- **🤖 Coder Agent**: Agentic coding assistant (reads files, plans, writes code)
- **👁️ Reviewer Agent**: Senior-level code review (architecture, security, performance)
- **🔄 Auto-Rotating APIs**: Seamlessly switches between free APIs when limits are reached
- **📊 Token Tracking**: Daily usage stats per API
- **🎯 Easy Setup**: One-click launcher with API key configuration

## Prerequisites

- Python 3.8+
- Windows 11 (or any OS with Python)
- API keys (free):
  - [Google Gemini](https://aistudio.google.com) - 1,500 requests/day free
  - [DeepSeek](https://platform.deepseek.com) - 5M token grant (30 days)
  - [Groq](https://console.groq.com) - Free tier available
  - [Amazon Q](https://aws.amazon.com/codewhisperer/) - Free tier available

## Quick Start

### 1. Clone or Download

```bash
git clone <your-repo-url> my-ai-cli
cd my-ai-cli
```

### 2. First Run (Setup)

Double-click `launch.bat` on Windows:
- Prompts for API keys (loop to add multiple)
- Installs dependencies automatically
- Opens 2 terminals (Coder + Reviewer)

**Or manually:**

```bash
pip install -r requirements.txt
python launch.bat  # Or manually run: python coder.py & python reviewer.py
```

### 3. Configure API Keys

When `launch.bat` runs, it prompts:
```
Enter API Provider (gemini/deepseek/groq/amazon-q): gemini
Paste API Key: [paste your key]
Add another API key? (y/n): y
```

**Get free API keys:**
- **Gemini**: Go to https://aistudio.google.com → "Get API key" button
- **DeepSeek**: https://platform.deepseek.com → Sign up → API Keys
- **Groq**: https://console.groq.com → Create API key
- **Amazon Q**: AWS Console → Amazon Q → Create API key

## Usage

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
```

**Examples:**
```
you> read src/app.js
you> list
you> write src/new_module.py
    [paste code]
you> help me optimize this database query
you> status
```

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
```

**Examples:**
```
reviewer> review src/database.py
reviewer> what are security considerations for this?
reviewer> read src/api.js
reviewer> status
```

## Configuration

### config.json (Auto-Generated)

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

- Automatically created on first run
- Stores API keys and daily usage
- Reset daily at midnight

### tracker.json (Auto-Generated)

```json
{
  "date": "2026-08-22",
  "apis": {
    "gemini-1": {
      "provider": "gemini",
      "requests": 42,
      "usage": [...]
    }
  }
}
```

- Tracks requests per API per day
- Resets daily
- Used for auto-rotation

## How It Works

### API Selection & Rotation

1. **Primary Selection**: Tries first available API with quota
2. **Fallback**: If limit reached, tries next API in list
3. **Smart Rotation**: Seamless switching mid-conversation
4. **Status Display**: `status` command shows all APIs and remaining quota

### Workflow Example

**Day 1:**
- Gemini free: 1,500 requests/day
- DeepSeek free: 5M token grant (30 days)
- Both available ✓

**Day 2:**
- Gemini reset: 1,500 available
- DeepSeek grant nearly depleted
- Both available (uses Gemini first)

**Day 30:**
- Gemini: Still available (permanent free tier)
- DeepSeek: Grant expired
- Falls back to Gemini only

## File Structure

```
my-ai-cli/
├── launch.bat              # One-click launcher (Windows)
├── coder.py                # Coder agent
├── reviewer.py             # Reviewer agent
├── config_manager.py       # Manages config.json
├── api_router.py           # API selection & rotation
├── token_tracker.py        # Usage tracking
├── requirements.txt        # Python dependencies
├── config.json             # (auto-generated) Your API keys
├── config.json.example     # Template
├── tracker.json            # (auto-generated) Usage stats
├── tracker.json.example    # Template
├── .gitignore              # Prevents key leaks
└── README.md               # This file
```

## Tips & Tricks

### Working Directory
The agents work on your current directory. Before launching:
```bash
cd C:\Users\Soyk\Projects\myapp
# Then double-click launch.bat
```

### Max Request Per Day
```
Status command shows:
✓ UNLIMITED (if using DeepSeek/Amazon Q free)
✓ 1500/1500 (if using Gemini)
✗ LIMIT REACHED (if daily limit hit)
```

### Multiple API Keys
Add Gemini key 1, then add DeepSeek, then add Groq:
```
Provider: gemini
Key: key1
Add more? y

Provider: deepseek
Key: key2
Add more? y

Provider: groq
Key: key3
Add more? n
```

### Reset Usage
Delete `tracker.json` to reset daily stats (new day auto-resets anyway).

## Troubleshooting

**"No API keys configured"**
- Run `launch.bat` again to add keys
- Or manually edit `config.json`

**"All APIs have reached daily limits"**
- Gemini limit (1,500 reqs/day) hit
- DeepSeek tokens exhausted (after 30-day free grant)
- Get more free keys or wait for daily reset

**"Python not found"**
- Install Python from python.org
- Add to PATH during installation

**"Missing google-generativeai"**
- Run: `pip install -r requirements.txt`

## Security

⚠️ **Never commit `config.json`** — it contains API keys!

- `.gitignore` prevents accidental commits
- Keep API keys private
- Don't share config.json
- Regenerate keys if leaked

## Free Tier Limits

| Provider | Limit | Agentic | Notes |
|----------|-------|---------|-------|
| Gemini   | 1,500 requests/day | ✓ | Permanent free |
| DeepSeek | 5M tokens (30d) | ✓ | Then pay-per-token |
| Groq     | Varies | ✓ | Free tier available |
| Amazon Q | 50 agentic reqs/day | ✓ | AWS account needed |

## License

MIT - Use freely, modify as needed.

## Support

For issues or improvements:
1. Check README first
2. Review config.json and tracker.json
3. Check `status` in both agents
4. Verify API keys are valid

---

**Happy coding!** 🚀
