import 'package:go_router/go_router.dart';

import '../features/work_log/presentation/detail/work_log_detail_page.dart';
import '../features/work_log/presentation/home_page.dart';

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
  ],
);
