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
  sha256: json['sha256'] as String?,
);

Map<String, dynamic> _$FileStatToJson(FileStat instance) => <String, dynamic>{
  'size': instance.size,
  'mtime': instance.mtime,
  'is_directory': instance.isDirectory,
  'sha256': instance.sha256,
};

DirectoryEntry _$DirectoryEntryFromJson(Map<String, dynamic> json) =>
    DirectoryEntry(
      name: json['name'] as String,
      stats: FileStat.fromJson(json['stats'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$DirectoryEntryToJson(DirectoryEntry instance) =>
    <String, dynamic>{'name': instance.name, 'stats': instance.stats};

PortablePath _$PortablePathFromJson(Map<String, dynamic> json) => PortablePath(
  (json['components'] as List<dynamic>).map((e) => e as String).toList(),
);

Map<String, dynamic> _$PortablePathToJson(PortablePath instance) =>
    <String, dynamic>{'components': instance._components};

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
  src: PortablePath.fromJson(json['src'] as Map<String, dynamic>),
  dest: PortablePath.fromJson(json['dest'] as Map<String, dynamic>),
);

Map<String, dynamic> _$SyncPathToJson(SyncPath instance) => <String, dynamic>{
  'src': instance.src,
  'dest': instance.dest,
};

SyncItem _$SyncItemFromJson(Map<String, dynamic> json) => SyncItem(
  path: PortablePath.fromJson(json['path'] as Map<String, dynamic>),
  stats: json['stats'] == null
      ? null
      : FileStat.fromJson(json['stats'] as Map<String, dynamic>),
);

Map<String, dynamic> _$SyncItemToJson(SyncItem instance) => <String, dynamic>{
  'path': instance.path,
  'stats': instance.stats,
};

DeltaRequest _$DeltaRequestFromJson(Map<String, dynamic> json) => DeltaRequest(
  dest: PortablePath.fromJson(json['dest'] as Map<String, dynamic>),
  deltas: (json['deltas'] as List<dynamic>)
      .map((e) => SyncItem.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$DeltaRequestToJson(DeltaRequest instance) =>
    <String, dynamic>{'dest': instance.dest, 'deltas': instance.deltas};
