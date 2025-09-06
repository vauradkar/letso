// GENERATED CODE - DO NOT MODIFY BY HAND

// coverage:ignore-file


part of 'data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FileStat _$FileStatFromJson(Map<String, dynamic> json) => FileStat(
  size: (json['size'] as num).toInt(),
  mtime: json['mtime'] as String,
  isDirectory: json['is_directory'] as bool,
);

Map<String, dynamic> _$FileStatToJson(FileStat instance) => <String, dynamic>{
  'size': instance.size,
  'mtime': instance.mtime,
  'is_directory': instance.isDirectory,
};

DirectoryEntry _$DirectoryEntryFromJson(Map<String, dynamic> json) =>
    DirectoryEntry(
      name: json['name'] as String,
      stats: FileStat.fromJson(json['stats'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$DirectoryEntryToJson(DirectoryEntry instance) =>
    <String, dynamic>{'name': instance.name, 'stats': instance.stats};

PortablePath _$PortablePathFromJson(Map<String, dynamic> json) => PortablePath(
  components: (json['components'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
);

Map<String, dynamic> _$PortablePathToJson(PortablePath instance) =>
    <String, dynamic>{'components': instance.components};

Directory _$DirectoryFromJson(Map<String, dynamic> json) => Directory(
  currentPath: PortablePath.fromJson(
    json['current_path'] as Map<String, dynamic>,
  ),
  items: (json['items'] as List<dynamic>)
      .map((e) => DirectoryEntry.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$DirectoryToJson(Directory instance) => <String, dynamic>{
  'current_path': instance.currentPath,
  'items': instance.items,
};

LookupResult _$LookupResultFromJson(Map<String, dynamic> json) => LookupResult(
  (json['stats'] as List<dynamic>?)
      ?.map((e) => FileStat.fromJson(e as Map<String, dynamic>))
      .toList(),
  path: PortablePath.fromJson(json['path'] as Map<String, dynamic>),
);

Map<String, dynamic> _$LookupResultToJson(LookupResult instance) =>
    <String, dynamic>{'path': instance.path, 'stats': instance.stats};

SyncPath _$SyncPathFromJson(Map<String, dynamic> json) => SyncPath(
  local: PortablePath.fromJson(json['local'] as Map<String, dynamic>),
  remote: PortablePath.fromJson(json['remote'] as Map<String, dynamic>),
);

Map<String, dynamic> _$SyncPathToJson(SyncPath instance) => <String, dynamic>{
  'local': instance.local,
  'remote': instance.remote,
};
