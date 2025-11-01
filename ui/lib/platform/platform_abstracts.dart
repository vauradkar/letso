import 'package:letso/data.dart';
import 'package:letso/upload_manager.dart';

abstract class AbstractSyncManager {
  Future<UploadResults> sync(SyncPath syncPath);
}
