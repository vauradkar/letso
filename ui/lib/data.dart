import 'package:json_annotation/json_annotation.dart';

part 'data.g.dart';

@JsonSerializable()
class FileStat {
  final int size;
  final String mtime; // using string for simplicity, can be datetime.
  @JsonKey(name: 'is_directory')
  final bool isDirectory;

  FileStat({
    required this.size,
    required this.mtime,
    required this.isDirectory,
  });

  factory FileStat.fromJson(Map<String, dynamic> json) =>
      _$FileStatFromJson(json);
  Map<String, dynamic> toJson() => _$FileStatToJson(this);
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
class PortablePath {
  final List<String> components;

  PortablePath({required this.components});
  factory PortablePath.fromJson(Map<String, dynamic> json) =>
      _$PortablePathFromJson(json);
  Map<String, dynamic> toJson() => _$PortablePathToJson(this);

  void add(String component) {
    components.add(component);
  }

  PortablePath subPath(int index) {
    return PortablePath(components: components.sublist(0, index + 1));
  }

  int get length => components.length;
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
