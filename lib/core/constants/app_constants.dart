class AppConstants {
  // App Info
  static const String appName = 'Taskora';
  static const String appVersion = '1.0.0';

  // Supabase Config
  static const String supabaseUrl = 'https://wlehkvsxftyxmxelcaps.supabase.co';
  static const String supabaseAnonKey =
      'sb_publishable_Nz2Ro_4jBthvDwjeQ8m-ww_tT0wYgcF';

  // API Config
  static const String deepseekApiUrl =
      'https://api.deepseek.com/v1/chat/completions';
  static const String deepseekApiKey = 'sk-1923fb07640b45b8a0ab564192810321';

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

  // VIP 配额
  static const int freeMaxProjects = 3;
  static const int freeMaxTasksPerProject = 50;

  // VIP 定价（分，用于订单创建）
  static const int vipMonthlyPriceCents = 990;
  static const int vipYearlyPriceCents = 6800;
  static const String vipMonthlyPriceDisplay = '¥9.9/月';
  static const String vipYearlyPriceDisplay = '¥68/年';

  // WxPusher 微信提醒
  static const String wxpusherAppToken = 'AT_YOUR_APP_TOKEN_HERE';
  static const int wxpusherAppId = 0; // 替换为实际 appId
}
