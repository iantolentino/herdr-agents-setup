import json
import os
from datetime import datetime

class TokenTracker:
    def __init__(self, tracker_file="tracker.json"):
        self.tracker_file = tracker_file
        self.tracker = self.load_tracker()
    
    def load_tracker(self):
        """Load tracker from JSON file"""
        if not os.path.exists(self.tracker_file):
            return {
                "date": str(datetime.now().date()),
                "apis": {}
            }
        
        with open(self.tracker_file, 'r') as f:
            data = json.load(f)
        
        # Reset if new day
        today = str(datetime.now().date())
        if data.get("date") != today:
            return {
                "date": today,
                "apis": {}
            }
        
        return data
    
    def save_tracker(self):
        """Save tracker to JSON file"""
        with open(self.tracker_file, 'w') as f:
            json.dump(self.tracker, f, indent=2)
    
    def log_request(self, api_name, provider, requests=1):
        """Log a request to an API"""
        if api_name not in self.tracker["apis"]:
            self.tracker["apis"][api_name] = {
                "provider": provider,
                "requests": 0,
                "usage": []
            }
        
        self.tracker["apis"][api_name]["requests"] += requests
        self.tracker["apis"][api_name]["usage"].append({
            "timestamp": str(datetime.now()),
            "requests": requests
        })
        
        self.save_tracker()
    
    def get_usage(self, api_name):
        """Get usage for a specific API"""
        if api_name in self.tracker["apis"]:
            return self.tracker["apis"][api_name]["requests"]
        return 0
    
    def get_all_usage(self):
        """Get all API usage for today"""
        return self.tracker["apis"]
    
    def display_usage(self):
        """Display formatted usage stats"""
        print("\n" + "="*50)
        print(f"Usage Stats - {self.tracker['date']}")
        print("="*50)
        
        total_requests = 0
        for api_name, data in self.tracker["apis"].items():
            requests = data["requests"]
            provider = data["provider"]
            total_requests += requests
            print(f"{provider.upper():15} ({api_name:15}): {requests:5} requests")
        
        print("-"*50)
        print(f"{'TOTAL':15} {'':15}: {total_requests:5} requests")
        print("="*50 + "\n")
