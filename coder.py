#!/usr/bin/env python3

import os
import sys
from pathlib import Path
from api_router import APIRouter

try:
    import google.generativeai as genai
except ImportError:
    print("❌ Missing google-generativeai. Run: pip install -r requirements.txt")
    sys.exit(1)

class CoderAgent:
    def __init__(self):
        self.router = APIRouter()
        self.project_root = os.getcwd()
        self.system_prompt = """You are an agentic coding assistant acting as a junior/mid-level developer.

Your capabilities:
- Read and analyze files in the current project
- Understand code structure and patterns
- Plan changes before implementing
- Write and edit code
- Suggest improvements
- Iterate based on feedback

When given a task:
1. Ask clarifying questions if needed
2. Plan your approach
3. Read relevant files
4. Implement changes step-by-step
5. Test and iterate

Always be clear about what you're doing and ask for approval before making major changes."""

    def read_file(self, filepath):
        """Read and return file contents"""
        try:
            full_path = os.path.join(self.project_root, filepath)
            if not os.path.exists(full_path):
                return f"❌ File not found: {filepath}"
            
            with open(full_path, 'r', encoding='utf-8') as f:
                contents = f.read()
            return contents
        except Exception as e:
            return f"❌ Error reading file: {e}"
    
    def list_files(self, directory="."):
        """List files in project directory"""
        try:
            full_path = os.path.join(self.project_root, directory)
            if not os.path.exists(full_path):
                return f"❌ Directory not found: {directory}"
            
            files = []
            for root, dirs, filenames in os.walk(full_path):
                # Skip common directories
                dirs[:] = [d for d in dirs if d not in ['.git', '__pycache__', 'node_modules', '.venv']]
                
                for file in filenames:
                    rel_path = os.path.relpath(os.path.join(root, file), self.project_root)
                    files.append(rel_path)
            
            return "\n".join(sorted(files)[:50])  # Limit to 50 files
        except Exception as e:
            return f"❌ Error listing files: {e}"
    
    def write_file(self, filepath, contents):
        """Write contents to file"""
        try:
            full_path = os.path.join(self.project_root, filepath)
            os.makedirs(os.path.dirname(full_path), exist_ok=True)
            
            with open(full_path, 'w', encoding='utf-8') as f:
                f.write(contents)
            return f"✓ File written: {filepath}"
        except Exception as e:
            return f"❌ Error writing file: {e}"
    
    def get_api_client(self):
        """Get configured API client (currently Gemini)"""
        api, api_key = self.router.route_request("gemini")
        
        if not api_key:
            return None
        
        genai.configure(api_key=api_key)
        return genai.GenerativeModel("gemini-2.0-flash")
    
    def chat(self, user_input, conversation_history):
        """Send message and get response"""
        model = self.get_api_client()
        
        if not model:
            return "❌ No available API. Check your configuration."
        
        # Build context
        context = f"""You are working in: {self.project_root}

Available commands you can suggest:
- read_file(path): Read file contents
- list_files(directory): List files
- write_file(path, contents): Create/update file

User: {user_input}"""

        try:
            response = model.generate_content(context)
            return response.text
        except Exception as e:
            return f"❌ API Error: {e}"
    
    def run(self):
        """Main interaction loop"""
        print("\n" + "="*60)
        print("🤖 Coder Agent - Ready")
        print("="*60)
        print(f"Working directory: {self.project_root}")
        print("\nAvailable commands:")
        print("  read <filepath>       - Read a file")
        print("  list [directory]      - List files")
        print("  write <filepath>      - Write/create file")
        print("  status                - Show API status")
        print("  help                  - Show this help")
        print("  exit                  - Exit agent")
        print("\nOr type any task (e.g., 'refactor this function')")
        print("="*60 + "\n")
        
        conversation_history = []
        
        while True:
            try:
                user_input = input("you> ").strip()
                
                if not user_input:
                    continue
                
                if user_input.lower() == "exit":
                    print("Goodbye! 👋")
                    break
                
                if user_input.lower() == "status":
                    self.router.display_status()
                    continue
                
                if user_input.lower() == "help":
                    print("\n" + "="*60)
                    print("Help")
                    print("="*60)
                    print("This agent can help you:")
                    print("- Understand code structure")
                    print("- Write new code")
                    print("- Refactor existing code")
                    print("- Plan architectural changes")
                    print("\nTip: Be specific with your requests.")
                    print("="*60 + "\n")
                    continue
                
                if user_input.lower().startswith("read "):
                    filepath = user_input[5:].strip()
                    contents = self.read_file(filepath)
                    print(f"\nAgent> {contents}\n")
                    continue
                
                if user_input.lower().startswith("list"):
                    directory = user_input[4:].strip() or "."
                    files = self.list_files(directory)
                    print(f"\nAgent> Files in {directory}:\n{files}\n")
                    continue
                
                # General chat
                response = self.chat(user_input, conversation_history)
                print(f"\nAgent> {response}\n")
                
            except KeyboardInterrupt:
                print("\n\nExiting...")
                break
            except Exception as e:
                print(f"❌ Error: {e}\n")

if __name__ == "__main__":
    agent = CoderAgent()
    agent.run()
