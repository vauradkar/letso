import 'package:letso/api.dart';
import 'package:letso/data.dart';
import 'package:letso/upload_manager.dart';

class SyncManager {
  SyncManager({required Api api, required UploadManager uploadManager});

  Future<UploadResults> sync(SyncPath syncPath) async {
    return UploadResults();
  }
}
