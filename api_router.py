from config_manager import ConfigManager
from token_tracker import TokenTracker

class APIRouter:
    def __init__(self):
        self.config = ConfigManager()
        self.tracker = TokenTracker()
    
    def get_next_api(self, preferred_provider=None):
        """
        Get the next available API, with optional provider preference.
        Returns API dict or None if no APIs available.
        """
        apis = self.config.get_apis()
        
        if not apis:
            print("❌ No API keys configured. Please run setup.")
            return None
        
        # Try preferred provider first
        if preferred_provider:
            for api in apis:
                if api.get("provider") == preferred_provider:
                    if self.config._check_daily_limit(api):
                        return api
        
        # Fall back to first available
        for api in apis:
            if self.config._check_daily_limit(api):
                return api
        
        print("⚠️  All APIs have reached daily limits!")
        return None
    
    def route_request(self, preferred_provider=None):
        """
        Route a request to the best available API.
        Returns (api_dict, api_key) or (None, None) if no API available.
        """
        api = self.get_next_api(preferred_provider)
        
        if not api:
            return None, None
        
        api_key = api.get("api_key")
        api_name = api.get("name")
        
        # Log the request
        self.tracker.log_request(api_name, api.get("provider"))
        self.config.add_usage(api_name, 1)
        
        return api, api_key
    
    def display_status(self):
        """Display current API status and usage"""
        apis = self.config.get_apis()
        
        if not apis:
            print("No APIs configured.")
            return
        
        print("\n" + "="*60)
        print("API Status")
        print("="*60)
        
        for api in apis:
            name = api.get("name")
            provider = api.get("provider")
            daily_limit = api.get("daily_limit")
            daily_used = api.get("daily_used", 0)
            
            if daily_limit == "unlimited":
                status = "✓ UNLIMITED"
                usage_str = f"{daily_used} used"
            else:
                remaining = int(daily_limit) - int(daily_used)
                status = "✓" if remaining > 0 else "✗ LIMIT REACHED"
                usage_str = f"{daily_used}/{daily_limit}"
            
            print(f"{provider.upper():10} ({name:12}) {usage_str:15} {status}")
        
        print("="*60)
        self.tracker.display_usage()
