import 'dart:io' as io;
import 'dart:typed_data';
import 'package:dart_either/dart_either.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letso/api.dart';
import 'package:letso/data.dart';
import 'package:flutter/services.dart';
import 'package:letso/logger_manager.dart';
import 'package:letso/upload_manager.dart';
import 'package:mocktail/mocktail.dart';

class MockApi extends Mock implements Api {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockApi mockApi;
  late UploadManager uploadManager;

  setUpAll(() {
    registerFallbackValue(PlatformFile(name: 'dummy', size: 0));
    registerFallbackValue(const PortablePath([]));
    registerFallbackValue(const FileStat(
      size: 0,
      mtime: '',
      isDirectory: false,
      sha256: null,
    ));
    registerFallbackValue(Uint8List(0));
  });

  setUp(() async {
    const MethodChannel('plugins.flutter.io/path_provider')
        .setMockMethodCallHandler((MethodCall methodCall) async {
      if (methodCall.method == 'getApplicationDocumentsDirectory') {
        return '.';
      }
      return null;
    });

    mockApi = MockApi();
    uploadManager = UploadManager(api: mockApi);
    await logger.initLogger(logSize: 100);
  });

  test('Upload failures should not count as successes (currently they do due to bug)', () async {
    // Arrange: Mock api.uploadFile to return Left (failure)
    when(() => mockApi.uploadFile(any(), any(), any(), any()))
        .thenAnswer((_) async => Either.left('Upload failed'));

    final tempDir = await io.Directory.systemTemp.createTemp();
    final tempFile = io.File('${tempDir.path}/test_file.txt');
    await tempFile.writeAsString('hello world');

    final syncItem = SyncItem(
      path: PortablePath.fromString(tempFile.path),
      stats: const FileStat(
        size: 11,
        mtime: '2026-07-14T00:00:00Z',
        isDirectory: false,
        sha256: null,
      ),
    );

    // Act
    final results = await uploadManager.uploadFiles(
      [syncItem],
      PortablePath.fromString('/dest'),
      PortablePath.fromString(tempDir.path),
    );

    // Clean up
    await tempDir.delete(recursive: true);

    // Assert (Verifying that the bug is fixed)
    expect(results.successCount, 0);
    expect(results.failureCount, 1);
    expect(results.errors, contains('Upload failed'));
  });
}
