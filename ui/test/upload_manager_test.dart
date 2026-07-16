import 'dart:io' as io;
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

class FakeFilePicker extends FilePickerPlatform {
  FilePickerResult? resultToReturn;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
    bool cancelUploadOnWindowBlur = true,
    AndroidSAFOptions? androidSafOptions,
  }) async => resultToReturn;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockApi mockApi;
  late UploadManager uploadManager;

  setUpAll(() {
    registerFallbackValue(PlatformFile(name: 'dummy', size: 0));
    registerFallbackValue(const PortablePath([]));
    registerFallbackValue(
      const FileStat(size: 0, mtime: '', isDirectory: false, sha256: null),
    );
    registerFallbackValue(Uint8List(0));
  });

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') {
          return '.';
        }
        return null;
      },
    );

    mockApi = MockApi();
    uploadManager = UploadManager(api: mockApi);
    await logger.initLogger(logSize: 100);
  });

  test(
    'Upload failures should not count as successes (currently they do due to bug)',
    () async {
      // Arrange: Mock api.uploadFile to return Left (failure)
      when(
        () => mockApi.uploadFile(any(), any(), any(), any()),
      ).thenAnswer((_) async => Either.left('Upload failed'));

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
    },
  );

  test(
    'uploadFile with bytes==null (desktop-style pick) leaves sync status balanced',
    () async {
      // Arrange: a PlatformFile with bytes == null and only a path set, as
      // file_picker returns on non-web platforms without withData: true.
      when(
        () => mockApi.uploadFile(any(), any(), any(), any()),
      ).thenAnswer((_) async => const Either.right(null));

      final tempDir = await io.Directory.systemTemp.createTemp();
      final tempFile = io.File('${tempDir.path}/test_file.txt');
      await tempFile.writeAsString('hello world');

      final fakeFilePicker = FakeFilePicker()
        ..resultToReturn = FilePickerResult([
          PlatformFile(
            path: tempFile.path,
            name: 'test_file.txt',
            size: 11,
            bytes: null,
          ),
        ]);
      FilePickerPlatform.instance = fakeFilePicker;

      // Act
      await uploadManager.uploadFile(PortablePath.fromString('/dest'));

      // Clean up
      await tempDir.delete(recursive: true);

      // Assert: addFile (loop 1) and removeFile (loop 2) must agree on which
      // files are counted, otherwise remainingFiles/remainingBytes drift away
      // from zero and isUploading gets stuck.
      expect(uploadManager.isUploading, isFalse);
      expect(uploadManager.remainingFiles, 0);
      expect(uploadManager.remainingBytes, 0);
      verify(() => mockApi.uploadFile(any(), any(), any(), any())).called(1);
    },
  );

  test(
    'uploadFiles skips non-file entries in both the count and upload loops',
    () async {
      // Arrange: mock success for the one real file we expect to be uploaded.
      when(
        () => mockApi.uploadFile(any(), any(), any(), any()),
      ).thenAnswer((_) async => const Either.right(null));

      final tempDir = await io.Directory.systemTemp.createTemp();
      final tempFile = io.File('${tempDir.path}/real_file.txt');
      await tempFile.writeAsString('hello world');

      final realItem = SyncItem(
        path: PortablePath.fromString(tempFile.path),
        stats: const FileStat(
          size: 11,
          mtime: '2026-07-14T00:00:00Z',
          isDirectory: false,
          sha256: null,
        ),
      );
      // A directory masquerading as a SyncItem: isFile() will be false for it,
      // so the upload loop skips it via `continue` before reaching removeFile.
      final notAFileItem = SyncItem(
        path: PortablePath.fromString(tempDir.path),
        stats: const FileStat(
          size: 4096,
          mtime: '2026-07-14T00:00:00Z',
          isDirectory: true,
          sha256: null,
        ),
      );

      // Act
      final results = await uploadManager.uploadFiles(
        [notAFileItem, realItem],
        PortablePath.fromString('/dest'),
        PortablePath.fromString(tempDir.path),
      );

      // Clean up
      await tempDir.delete(recursive: true);

      // Assert
      expect(results.successCount, 1);
      // addFile was called for both entries up front; removeFile must be
      // called for the skipped entry too, or remainingFiles/remainingBytes
      // never return to zero and isUploading gets stuck forever.
      expect(uploadManager.isUploading, isFalse);
      expect(uploadManager.remainingFiles, 0);
      expect(uploadManager.remainingBytes, 0);
    },
  );
}
