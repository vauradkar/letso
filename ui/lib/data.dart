class DirectoryEntry {
  final String name;
  final int size;
  final String mtime; // Using String for simplicity, can be DateTime.
  final bool isDirectory;

  DirectoryEntry({
    required this.name,
    required this.size,
    required this.mtime,
    required this.isDirectory,
  });

  // Factory constructor to create a DirectoryItem from a JSON map.
  factory DirectoryEntry.fromJson(Map<String, dynamic> json) {
    return DirectoryEntry(
      name: json['name'] as String,
      size: json['size'] as int,
      mtime: json['mtime'] as String,
      isDirectory: json['is_directory'] as bool,
    );
  }
}

// Define the Dart struct for a directory item.
class DirectoryEntries {
  final List<String> currentPath;
  final List<DirectoryEntry> items;

  DirectoryEntries({required this.currentPath, required this.items});

  // Factory constructor to create a DirectoryItem from a JSON map.
  factory DirectoryEntries.fromJson(Map<String, dynamic> json) {
    var entriesJson = json['items'] as List;
    List<DirectoryEntry> entriesList = entriesJson
        .map((entry) => DirectoryEntry.fromJson(entry as Map<String, dynamic>))
        .toList();

    List<String> currentPath = (json['current_path'] as List<dynamic>)
        .cast<String>();
    return DirectoryEntries(currentPath: currentPath, items: entriesList);
  }
}
