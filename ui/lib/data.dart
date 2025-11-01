import 'package:file_picker/file_picker.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

import 'dart:io' as io;

import 'package:letso/utils.dart';

part 'data.g.dart';

@JsonSerializable()
class FileStat extends Equatable {
  final int size;
  final String mtime; // using string for simplicity, can be datetime.
  @JsonKey(name: 'is_directory')
  final bool isDirectory;
  final String? sha256;

  const FileStat({
    required this.size,
    required this.mtime,
    required this.isDirectory,
    required this.sha256,
  });

  static Future<FileStat?> fromIoFileStat(io.FileStat stats) async {
    return FileStat(
      size: stats.size,
      mtime: stats.modified.toIso8601String(),
      isDirectory: stats.type == io.FileSystemEntityType.directory,
      sha256: null,
    );
  }

  static Future<FileStat> fromPickerFile(PlatformFile file) async {
    return FileStat(
      size: file.size,
      mtime: (await file.xFile.lastModified()).toIso8601String(),
      isDirectory: false,
      sha256: null,
    );
  }

  factory FileStat.fromJson(Map<String, dynamic> json) =>
      _$FileStatFromJson(json);
  Map<String, dynamic> toJson() => _$FileStatToJson(this);

  @override
  List<Object?> get props => [size, mtime, isDirectory, sha256];

  @override
  bool get stringify => true;
}

@JsonSerializable()
class DirectoryEntry {
  final String name;
  final FileStat stats;

  DirectoryEntry({required this.name, required this.stats});
  factory DirectoryEntry.fromJson(Map<String, dynamic> json) =>
      _$DirectoryEntryFromJson(json);
  Map<String, dynamic> toJson() => _$DirectoryEntryToJson(this);

  bool get isDirectory => stats.isDirectory;
  int get size => stats.size;
  String get mtime => stats.mtime;
}

@JsonSerializable()
class PortablePath extends Equatable {
  @JsonKey(includeFromJson: true, includeToJson: true, name: "components")
  final List<String> _components;

  const PortablePath(this._components);

  factory PortablePath.fromString(String s) {
    List<String> components = s.startsWith('/') ? [] : ['/'];
    components.addAll(s.split('/'));
    return PortablePath(components);
  }

  factory PortablePath.clone(PortablePath src) {
    PortablePath destDir = PortablePath([]);
    for (var c in src._components) {
      if (c.isNotEmpty) {
        destDir.add(c);
      }
    }
    return destDir;
  }

  factory PortablePath.fromJson(Map<String, dynamic> json) =>
      _$PortablePathFromJson(json);
  Map<String, dynamic> toJson() => _$PortablePathToJson(this);

  @override
  List<Object> get props => [_components];

  void add(String component) {
    _components.add(component);
  }

  PortablePath subPath(int index) {
    return PortablePath(_components.sublist(0, index + 1));
  }

  int get length => _components.length;

  String? getAncestor(int i) {
    return i < _components.length && i >= 0 ? _components[i] : null;
  }

  String? getBasename() {
    return getAncestor(_components.length - 1);
  }

  @override
  String toString() {
    return _components.join('/');
  }
}

@JsonSerializable()
class Directory {
  @JsonKey(name: 'current_path')
  final PortablePath currentPath;
  final List<DirectoryEntry> items;

  Directory({required this.currentPath, required this.items});
  factory Directory.fromJson(Map<String, dynamic> json) =>
      _$DirectoryFromJson(json);
  Map<String, dynamic> toJson() => _$DirectoryToJson(this);
}

@JsonSerializable()
class LookupResult {
  final PortablePath path;
  final List<FileStat>? stats;

  LookupResult(this.stats, {required this.path});
  factory LookupResult.fromJson(Map<String, dynamic> json) =>
      _$LookupResultFromJson(json);
  Map<String, dynamic> toJson() => _$LookupResultToJson(this);
}

@JsonSerializable()
class SyncPath {
  final PortablePath src;
  final PortablePath dest;

  SyncPath({required this.src, required this.dest});

  Map<String, dynamic> toJson() => _$SyncPathToJson(this);

  static SyncPath fromJson(Map<String, dynamic> json) =>
      _$SyncPathFromJson(json);
}

@JsonSerializable()
class SyncItem extends Equatable {
  /// The full path of the file.
  final PortablePath path;

  /// Metadata if the file exists.
  final FileStat? stats;

  const SyncItem({required this.path, this.stats});

  static Future<SyncItem?> fromFileSystemEntity(io.FileSystemEntity e) async {
    var stats = await getFileStats(e);
    if (stats == null) {
      return null;
    }

    return SyncItem(path: PortablePath.fromString(e.path), stats: stats);
  }

  Map<String, dynamic> toJson() => _$SyncItemToJson(this);

  static SyncItem fromJson(Map<String, dynamic> json) =>
      _$SyncItemFromJson(json);

  @override
  List<Object?> get props => [path, stats];

  @override
  bool get stringify => true;
}

@JsonSerializable()
class DeltaRequest {
  /// Path where the directory should be synced
  final PortablePath dest;

  /// List of SyncItems representing the deltas
  List<SyncItem> deltas;

  DeltaRequest({required this.dest, required this.deltas});

  Map<String, dynamic> toJson() => _$DeltaRequestToJson(this);

  static DeltaRequest fromJson(Map<String, dynamic> json) =>
      _$DeltaRequestFromJson(json);
}
