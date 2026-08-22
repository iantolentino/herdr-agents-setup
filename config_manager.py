import json
import os
from datetime import datetime

class ConfigManager:
    def __init__(self, config_file="config.json"):
        self.config_file = config_file
        self.config = self.load_config()
    
    def load_config(self):
        """Load config from JSON file"""
        if not os.path.exists(self.config_file):
            return {"apis": [], "setup_complete": False}
        
        with open(self.config_file, 'r') as f:
            return json.load(f)
    
    def save_config(self):
        """Save config to JSON file"""
        with open(self.config_file, 'w') as f:
            json.dump(self.config, f, indent=2)
    
    def get_apis(self):
        """Get all configured APIs"""
        return self.config.get("apis", [])
    
    def get_api_by_provider(self, provider):
        """Get first API of a specific provider with available quota"""
        apis = self.get_apis()
        for api in apis:
            if api.get("provider") == provider:
                if self._check_daily_limit(api):
                    return api
        return None
    
    def get_available_api(self):
        """Get first available API with daily quota remaining"""
        apis = self.get_apis()
        for api in apis:
            if self._check_daily_limit(api):
                return api
        return None
    
    def _check_daily_limit(self, api):
        """Check if API has daily quota remaining"""
        daily_limit = api.get("daily_limit")
        daily_used = api.get("daily_used", 0)
        
        if daily_limit == "unlimited":
            return True
        
        return int(daily_used) < int(daily_limit)
    
    def add_usage(self, api_name, requests=1):
        """Log usage for an API"""
        apis = self.get_apis()
        for api in apis:
            if api.get("name") == api_name:
                api["daily_used"] = api.get("daily_used", 0) + requests
                self.save_config()
                return True
        return False
    
    def reset_daily_usage(self):
        """Reset daily usage counters"""
        apis = self.get_apis()
        for api in apis:
            api["daily_used"] = 0
        self.save_config()
    
    def get_api_key(self, provider):
        """Get API key for a provider"""
        api = self.get_api_by_provider(provider)
        if api:
            return api.get("api_key")
        return None
