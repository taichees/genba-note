import 'package:go_router/go_router.dart';

import '../features/monetize/presentation/paywall_page.dart';
import '../features/monetize/presentation/settings_page.dart';
import '../features/work_log/presentation/map/work_log_map_page.dart';
import '../features/work_log/presentation/detail/work_log_detail_page.dart';
import '../features/work_log/presentation/home_page.dart';
import '../features/work_log/presentation/search/work_log_search_page.dart';

final GoRouter appRouter = GoRouter(
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (context, state) => const HomePage(),
    ),
    GoRoute(
      path: '/work-logs/:id',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return WorkLogDetailPage(workLogId: id);
      },
    ),
    GoRoute(
      path: '/map',
      builder: (context, state) {
        final selectedWorkLogId = int.tryParse(
          state.uri.queryParameters['workLogId'] ?? '',
        );
        return WorkLogMapPage(selectedWorkLogId: selectedWorkLogId);
      },
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsPage(),
    ),
    GoRoute(
      path: '/paywall',
      builder: (context, state) =>
          PaywallPage(reason: state.extra as String?),
    ),
    GoRoute(
      path: '/search',
      builder: (context, state) => const WorkLogSearchPage(),
    ),
  ],
);
