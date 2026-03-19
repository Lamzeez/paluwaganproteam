import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/db_service.dart';
import 'viewmodels/auth_viewmodel.dart';
import 'viewmodels/groups_viewmodel.dart';
import 'viewmodels/notification_viewmodel.dart';
import 'views/welcome_view.dart';
import 'views/login_view.dart';
import 'views/signup_view.dart';
import 'views/home_view.dart';
import 'views/profile_view.dart';
import 'views/notifications_view.dart';
import 'views/all_groups_view.dart';
import 'views/group_detail_view.dart';
import 'views/create_group_view.dart';
import 'views/join_group_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DbService.instance.database;
  runApp(const PaluwaganProApp());
}

class PaluwaganProApp extends StatelessWidget {
  const PaluwaganProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthViewModel(DbService.instance),
        ),
        ChangeNotifierProvider(
          create: (_) => GroupsViewModel(DbService.instance),
        ),
        ChangeNotifierProvider(
          create: (_) => NotificationViewModel(DbService.instance),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'PaluwaganPro',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
          scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        ),
        initialRoute: '/',
        routes: {
          '/': (context) => const SplashScreen(),
          '/login': (context) => const LoginScreen(),
          '/signup': (context) => const SignUpScreen(),
          '/profile': (context) => const ProfileScreen(),
          '/notifications': (context) => const NotificationsScreen(),
          '/create-group': (context) => const CreateGroupScreen(),
          '/join-group': (context) => const JoinGroupScreen(),
        },
        onGenerateRoute: (settings) {
          if (settings.name == '/home') {
            final auth = Provider.of<AuthViewModel>(context, listen: false);
            if (auth.currentUser == null) {
              return MaterialPageRoute(builder: (_) => const LoginScreen());
            }

            // Load user groups before showing dashboard
            final groupsVm = Provider.of<GroupsViewModel>(
              context,
              listen: false,
            );
            groupsVm.loadUserGroups(auth.currentUser!.id);

            return MaterialPageRoute(
              builder: (_) => DashboardScreen(user: auth.currentUser!),
            );
          }
          if (settings.name == '/group-detail') {
            final groupId = settings.arguments as int;
            return MaterialPageRoute(
              builder: (context) => GroupDetailScreen(groupId: groupId),
            );
          }
          if (settings.name == '/all-groups') {
            final groups = settings.arguments as List;
            return MaterialPageRoute(
              builder: (context) => AllGroupsPage(groups: groups.cast()),
            );
          }
          return null;
        },
      ),
    );
  }
}
