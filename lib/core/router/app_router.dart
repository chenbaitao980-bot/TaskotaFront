import 'package:flutter/material.dart';
import '../../presentation/pages/home/home_page.dart';
import '../../presentation/pages/calendar/calendar_page.dart';
import '../../presentation/pages/profile/profile_page.dart';
import '../../presentation/pages/auth/login_page.dart';
import '../../presentation/pages/auth/register_page.dart';
import '../../presentation/pages/task/task_detail_page.dart';
import '../../presentation/pages/task/create_task_page.dart';

class AppRouter {
  /// 全局导航键，供通知点击等外部事件导航到指定页面。
  static final navigatorKey = GlobalKey<NavigatorState>();

  static const String home = '/';
  static const String calendar = '/calendar';
  static const String profile = '/profile';
  static const String login = '/login';
  static const String register = '/register';
  static const String taskDetail = '/task/:id';
  static const String createTask = '/create-task';
  
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case home:
        return MaterialPageRoute(builder: (_) => const HomePage());
      case calendar:
        return MaterialPageRoute(builder: (_) => const CalendarPage());
      case profile:
        return MaterialPageRoute(builder: (_) => const ProfilePage());
      case login:
        return MaterialPageRoute(builder: (_) => const LoginPage());
      case register:
        return MaterialPageRoute(builder: (_) => const RegisterPage());
      case createTask:
        return MaterialPageRoute(builder: (_) => const CreateTaskPage());
      default:
        if (settings.name?.startsWith('/task/') ?? false) {
          final id = settings.name!.split('/').last;
          return MaterialPageRoute(
            builder: (_) => TaskDetailPage(taskId: id),
          );
        }
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('页面未找到: ${settings.name}'),
            ),
          ),
        );
    }
  }
  
  static void navigateTo(BuildContext context, String route, {Object? arguments}) {
    Navigator.pushNamed(context, route, arguments: arguments);
  }
  
  static void navigateToAndReplace(BuildContext context, String route, {Object? arguments}) {
    Navigator.pushReplacementNamed(context, route, arguments: arguments);
  }
  
  static void goBack(BuildContext context) {
    Navigator.pop(context);
  }
}
