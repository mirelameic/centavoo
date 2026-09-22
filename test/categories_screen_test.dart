import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:centavoo/l10n/arb/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:centavoo/data/database.dart';
import 'package:centavoo/data/repo.dart';
import 'package:centavoo/screens/categories_screen.dart';
import 'package:centavoo/theme.dart';

Future<AppDatabase> pump(WidgetTester tester, String tripId, {AppDatabase? db}) async {
  db ??= AppDatabase.forTesting(NativeDatabase.memory());
  final router = GoRouter(
    initialLocation: '/trip/$tripId/categories',
    routes: [
      GoRoute(path: '/trip/:id', builder: (context, state) => const Scaffold(body: Text('trip screen'))),
      GoRoute(
        path: '/trip/:id/categories',
        builder: (context, state) => Scaffold(body: CategoriesScreen(tripId: tripId)),
      ),
    ],
  );
  await tester.pumpWidget(
    Provider<AppDatabase>.value(
      value: db,
      child: MaterialApp.router(locale: const Locale('pt', 'BR'), localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales, routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return db;
}

void main() {
  testWidgets('shows the empty state when the trip has no categories', (tester) async {
    final tripId = 'empty-trip';
    final db = await pump(tester, tripId);
    expect(find.text('Nenhuma categoria.'), findsOneWidget);
    await db.close();
  });

  testWidgets('tapping "Voltar" pops back when reached via push, instead of resetting the stack', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final tripId = await createTrip(db, name: 'Japan');
    final router = GoRouter(
      initialLocation: '/trip/$tripId',
      routes: [
        GoRoute(path: '/trip/:id', builder: (context, state) => const Scaffold(body: Text('trip screen'))),
        GoRoute(
          path: '/trip/:id/categories',
          builder: (context, state) => Scaffold(body: CategoriesScreen(tripId: tripId)),
        ),
      ],
    );
    await tester.pumpWidget(
      Provider<AppDatabase>.value(
        value: db,
        child: MaterialApp.router(locale: const Locale('pt', 'BR'), localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    router.push('/trip/$tripId/categories');
    await tester.pumpAndSettle();
    expect(router.canPop(), isTrue);

    await tester.tap(find.text('Voltar'));
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.toString(), '/trip/$tripId');
    expect(router.canPop(), isFalse);
    await db.close();
  });

  testWidgets('tapping "Voltar" still reaches the trip screen when categories was opened directly', (tester) async {
    final tripId = 'direct-trip';
    final db = await pump(tester, tripId);
    final router = GoRouter.of(tester.element(find.text('Voltar')));

    await tester.tap(find.text('Voltar'));
    await tester.pump();

    expect(router.routerDelegate.currentConfiguration.uri.toString(), '/trip/$tripId');
    await db.close();
  });

  testWidgets('lists existing categories with their color and icon', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final tripId = await createTrip(db, name: 'Japan');

    await pump(tester, tripId, db: db);
    expect(find.text('Hospedagem'), findsOneWidget);
    expect(find.text('Passagem'), findsOneWidget);
    await db.close();
  });

  testWidgets('creating a category through the dialog adds it to the list', (tester) async {
    final tripId = 'new-trip';
    final db = await pump(tester, tripId);

    await tester.tap(find.byType(IconButton).first);
    await tester.pumpAndSettle();
    expect(find.text('Nova categoria'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Nome'), 'Cinema');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(find.text('Cinema'), findsOneWidget);
    await db.close();
  });

  testWidgets('creating a category with a chosen color and icon persists both', (tester) async {
    final tripId = 'new-trip-2';
    final db = await pump(tester, tripId);

    await tester.tap(find.byType(IconButton).first);
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Nome'), 'Praia');

    await tester.tap(find.byWidgetPredicate(
      (w) => w is Container && w.decoration is BoxDecoration && (w.decoration as BoxDecoration).color == hexColor('#0E8C6B'),
    ));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.beach_access));
    await tester.pump();

    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    final cats = await db.select(db.categoriesTable).get();
    final created = cats.firstWhere((c) => c.name == 'Praia');
    expect(created.color, '#0E8C6B');
    expect(created.icon, 'beach');
    await db.close();
  });

  testWidgets('editing a category through the dialog updates its name', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final tripId = await createTrip(db, name: 'Japan');

    await pump(tester, tripId, db: db);
    await tester.tap(find.byTooltip('edit').first);
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Nome'), 'Estadia');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(find.text('Estadia'), findsOneWidget);
    expect(find.text('Hospedagem'), findsNothing);
    await db.close();
  });

  testWidgets('deleting a category removes it after confirmation', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final tripId = await createTrip(db, name: 'Japan');

    await pump(tester, tripId, db: db);
    await tester.tap(find.byTooltip('delete').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();

    expect(find.text('Hospedagem'), findsNothing);
    await db.close();
  });
}
