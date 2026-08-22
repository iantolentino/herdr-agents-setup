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

class ReviewerAgent:
    def __init__(self):
        self.router = APIRouter()
        self.project_root = os.getcwd()
        self.system_prompt = """You are a senior code reviewer with expertise in:
- Architecture and design patterns
- Security best practices
- Performance optimization
- Code maintainability
- Testing strategies
- Edge cases and error handling

When reviewing code:
1. Look for architectural issues first
2. Check for security vulnerabilities
3. Evaluate performance implications
4. Assess maintainability
5. Verify error handling
6. Check for edge cases

Provide constructive, specific feedback with:
- What's good about the code
- What could be improved
- Why the improvement matters
- How to fix it (if applicable)"""

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
    
    def get_api_client(self):
        """Get configured API client (currently Gemini)"""
        api, api_key = self.router.route_request("gemini")
        
        if not api_key:
            return None
        
        genai.configure(api_key=api_key)
        return genai.GenerativeModel("gemini-2.0-flash")
    
    def review_code(self, code_content, filepath):
        """Get senior-level code review"""
        model = self.get_api_client()
        
        if not model:
            return "❌ No available API. Check your configuration."
        
        review_prompt = f"""Please review this code from {filepath} with a senior engineer's perspective.

Code:
```
{code_content}
```

Provide detailed feedback on:
1. Architecture & Design
2. Security
3. Performance
4. Maintainability
5. Error Handling
6. Edge Cases
7. Testing Considerations"""

        try:
            response = model.generate_content(review_prompt)
            return response.text
        except Exception as e:
            return f"❌ API Error: {e}"
    
    def run(self):
        """Main interaction loop"""
        print("\n" + "="*60)
        print("👁️  Reviewer Agent - Ready")
        print("="*60)
        print(f"Working directory: {self.project_root}")
        print("\nAvailable commands:")
        print("  review <filepath>     - Review a file")
        print("  read <filepath>       - Read a file")
        print("  list [directory]      - List files")
        print("  status                - Show API status")
        print("  help                  - Show this help")
        print("  exit                  - Exit agent")
        print("\nOr ask any review-related question")
        print("="*60 + "\n")
        
        while True:
            try:
                user_input = input("reviewer> ").strip()
                
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
                    print("Reviewer Help")
                    print("="*60)
                    print("This agent reviews code for:")
                    print("- Architectural issues")
                    print("- Security vulnerabilities")
                    print("- Performance problems")
                    print("- Code maintainability")
                    print("- Error handling gaps")
                    print("- Edge cases")
                    print("\nTip: Use 'review <filepath>' for full reviews")
                    print("="*60 + "\n")
                    continue
                
                if user_input.lower().startswith("review "):
                    filepath = user_input[7:].strip()
                    code = self.read_file(filepath)
                    
                    if code.startswith("❌"):
                        print(f"\nReviewer> {code}\n")
                    else:
                        print("\nReviewer> Analyzing code...\n")
                        review = self.review_code(code, filepath)
                        print(f"Reviewer> {review}\n")
                    continue
                
                if user_input.lower().startswith("read "):
                    filepath = user_input[5:].strip()
                    contents = self.read_file(filepath)
                    print(f"\nReviewer> {contents}\n")
                    continue
                
                if user_input.lower().startswith("list"):
                    directory = user_input[4:].strip() or "."
                    files = self.list_files(directory)
                    print(f"\nReviewer> Files in {directory}:\n{files}\n")
                    continue
                
                # General question
                model = self.get_api_client()
                if not model:
                    print("❌ No available API. Check your configuration.\n")
                    continue
                
                prompt = f"{self.system_prompt}\n\nQuestion: {user_input}"
                response = model.generate_content(prompt)
                print(f"\nReviewer> {response.text}\n")
                
            except KeyboardInterrupt:
                print("\n\nExiting...")
                break
            except Exception as e:
                print(f"❌ Error: {e}\n")

if __name__ == "__main__":
    agent = ReviewerAgent()
    agent.run()
