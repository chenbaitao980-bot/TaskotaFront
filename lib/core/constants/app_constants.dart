class AppConstants {
  // App Info
  static const String appName = '智能小管家';
  static const String appVersion = '1.0.0';
  
  // Supabase Config
  static const String supabaseUrl = 'YOUR_SUPABASE_URL';
  static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
  
  // API Config
  static const String deepseekApiUrl = 'https://api.deepseek.com/v1/chat/completions';
  static const String deepseekApiKey = 'YOUR_DEEPSEEK_API_KEY';
  
  // Priority Levels
  static const String priorityP0 = 'P0';
  static const String priorityP1 = 'P1';
  static const String priorityP2 = 'P2';
  static const String priorityP3 = 'P3';
  
  // Task Status
  static const String statusPending = 'pending';
  static const String statusInProgress = 'in_progress';
  static const String statusCompleted = 'completed';
  static const String statusFailed = 'failed';
  static const String statusDeferred = 'deferred';
  
  // Task Levels
  static const String levelYearly = 'yearly';
  static const String levelQuarterly = 'quarterly';
  static const String levelMonthly = 'monthly';
  static const String levelWeekly = 'weekly';
  static const String levelDaily = 'daily';
  static const String levelHourly = 'hourly';
  
  // Reminder Channels
  static const String channelPush = 'push';
  static const String channelSms = 'sms';
  
  // Shared Preferences Keys
  static const String prefUserProfile = 'user_profile';
  static const String prefAuthToken = 'auth_token';
  static const String prefLastSync = 'last_sync';
  
  // Default Values
  static const int defaultFocusCapacity = 90; // minutes
  static const double defaultCompletionRate = 0.75;
}
