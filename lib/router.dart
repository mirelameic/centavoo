import 'package:go_router/go_router.dart';
import 'package:centavoo/screens/trips_screen.dart';
import 'package:centavoo/screens/trip_screen.dart';
import 'package:centavoo/screens/categories_screen.dart';
import 'package:centavoo/widgets/app_shell.dart';

GoRouter buildRouter() {
  return GoRouter(
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const TripsScreen(),
          ),
          GoRoute(
            path: '/trip/:id',
            builder: (context, state) => TripScreen(tripId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/trip/:id/categories',
            builder: (context, state) => CategoriesScreen(tripId: state.pathParameters['id']!),
          ),
        ],
      ),
    ],
  );
}
