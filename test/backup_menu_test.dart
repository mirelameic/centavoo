import 'dart:convert';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:drift/native.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:centavoo/l10n/arb/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:centavoo/data/backup.dart';
import 'package:centavoo/data/database.dart';
import 'package:centavoo/data/repo.dart';
import 'package:centavoo/theme.dart';
import 'package:centavoo/theme_controller.dart';
import 'package:centavoo/locale_controller.dart';
import 'package:centavoo/widgets/app_shell.dart';

base class _FakePlatformFile extends PlatformFile {
  final Uint8List _bytes;
  _FakePlatformFile(this._bytes);

  @override
  String get name => 'backup.json';

  @override
  Uri get uri => Uri.parse('file:///backup.json');

  @override
  XFile get xFile => throw UnimplementedError();

  @override
  int? lengthSync() => _bytes.length;

  @override
  Future<int?> length() async => _bytes.length;

  @override
  Future<Uint8List> readAsBytes() async => _bytes;

  @override
  Stream<Uint8List> readAsByteStream() => Stream.value(_bytes);
}

class _FakeFilePickerPlatform extends FilePickerPlatform with MockPlatformInterfaceMixin {
  PlatformFile? nextPickedFile;
  Uri? nextSavedUri = Uri.parse('file:///saved.json');
  Object? saveError;
  Uint8List? lastSavedBytes;

  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    return nextPickedFile;
  }

  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String? dialogTitle,
    String? initialDirectory,
    Function(FilePickerStatus)? onFileSaving,
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    if (saveError != null) throw saveError!;
    lastSavedBytes = bytes;
    return nextSavedUri;
  }
}

Future<AppDatabase> pump(WidgetTester tester) async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  await tester.pumpWidget(
    Provider<AppDatabase>.value(
      value: db,
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider<ThemeController>(create: (_) => ThemeController()),
          ChangeNotifierProvider<LocaleController>(create: (_) => LocaleController()),
        ],
        child: MaterialApp(
          locale: const Locale('pt', 'BR'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildLightTheme(),
          home: const AppShell(child: SizedBox.shrink()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return db;
}

void main() {
  late _FakeFilePickerPlatform fake;

  setUp(() {
    fake = _FakeFilePickerPlatform();
    FilePickerPlatform.instance = fake;
  });

  testWidgets('exporting writes every table as JSON and shows a success message', (tester) async {
    final db = await pump(tester);
    await createTrip(db, name: 'Japan');

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exportar dados'));
    await tester.pumpAndSettle();

    expect(fake.lastSavedBytes, isNotNull);
    final decoded = jsonDecode(utf8.decode(fake.lastSavedBytes!)) as Map<String, dynamic>;
    expect(decoded['app'], 'centavoo');
    expect((decoded['trips'] as List), hasLength(1));
    expect(find.text('Backup exportado.'), findsOneWidget);
    await db.close();
  });

  testWidgets('a failed export shows an error message instead of crashing', (tester) async {
    fake.saveError = Exception('disk full');
    final db = await pump(tester);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exportar dados'));
    await tester.pumpAndSettle();

    expect(find.text('Não foi possível exportar o backup.'), findsOneWidget);
    await db.close();
  });

  testWidgets('cancelling the export save dialog shows no message', (tester) async {
    fake.nextSavedUri = null;
    final db = await pump(tester);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exportar dados'));
    await tester.pumpAndSettle();

    expect(find.text('Backup exportado.'), findsNothing);
    expect(find.text('Não foi possível exportar o backup.'), findsNothing);
    await db.close();
  });

  testWidgets('importing a valid backup restores the data and shows a success message', (tester) async {
    final source = AppDatabase.forTesting(NativeDatabase.memory());
    await createTrip(source, name: 'Portugal');
    final json = await exportBackupJson(source);
    await source.close();

    fake.nextPickedFile = _FakePlatformFile(Uint8List.fromList(utf8.encode(json)));
    final db = await pump(tester);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Importar dados'));
    await tester.pumpAndSettle();

    expect(find.text('Backup importado com sucesso.'), findsOneWidget);
    final trips = await db.select(db.tripsTable).get();
    expect(trips.any((t) => t.name == 'Portugal'), isTrue);
    await db.close();
  });

  testWidgets('importing an invalid file shows an error and does not crash', (tester) async {
    fake.nextPickedFile = _FakePlatformFile(Uint8List.fromList(utf8.encode('not a backup')));
    final db = await pump(tester);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Importar dados'));
    await tester.pumpAndSettle();

    expect(find.text('Arquivo de backup inválido.'), findsOneWidget);
    await db.close();
  });

  testWidgets('cancelling the import file picker shows no message', (tester) async {
    fake.nextPickedFile = null;
    final db = await pump(tester);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Importar dados'));
    await tester.pumpAndSettle();

    expect(find.text('Backup importado com sucesso.'), findsNothing);
    expect(find.text('Arquivo de backup inválido.'), findsNothing);
    await db.close();
  });
}
