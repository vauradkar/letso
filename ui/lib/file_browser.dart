import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:letso/browser_container.dart';
import 'package:letso/data.dart';
import 'package:letso/upload_manager.dart';
import 'package:letso/api.dart';
import 'package:letso/browser_container.dart';
import 'package:letso/data.dart';
import 'package:letso/upload_manager.dart';

enum ViewType { icon, list }

enum SortColumn { name, size, kind, mtime }

enum SortOrder { ascending, descending }

class FileBrowser extends StatefulWidget {
  final Directory directory;
  final EventHandlers eventHandlers;
  final Api api;

  const FileBrowser({
    super.key,
    required this.directory,
    required this.eventHandlers,
    required this.api,
  });

  @override
  State<FileBrowser> createState() => _FileBrowserState();
}

class _FileBrowserState extends State<FileBrowser> {
  ViewType _viewType = ViewType.list;
  SortColumn _sortColumn = SortColumn.name;
  SortOrder _sortOrder = SortOrder.ascending;
  List<DirectoryEntry> _sortedItems = [];

  @override
  void initState() {
    super.initState();
    _sortedItems = List.from(widget.directory.items);
    _sortItems();
  }

  @override
  void didUpdateWidget(FileBrowser oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.directory.items != widget.directory.items) {
      _sortedItems = List.from(widget.directory.items);
      _sortItems();
    }
  }

  void _sortItems() {
    _sortedItems.sort((a, b) {
      int comparison = 0;

      // Always put directories first
      if (a.isDirectory && !b.isDirectory) return -1;
      if (!a.isDirectory && b.isDirectory) return 1;

      switch (_sortColumn) {
        case SortColumn.name:
          comparison = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          break;
        case SortColumn.size:
          comparison = a.size.compareTo(b.size);
          break;
        case SortColumn.kind:
          String aKind = a.isDirectory
              ? 'Directory'
              : _getFileExtension(a.name);
          String bKind = b.isDirectory
              ? 'Directory'
              : _getFileExtension(b.name);
          comparison = aKind.compareTo(bKind);
          break;
        case SortColumn.mtime:
          comparison = a.mtime.compareTo(b.mtime);
          break;
      }

      return _sortOrder == SortOrder.ascending ? comparison : -comparison;
    });
  }

  String _getFileExtension(String fileName) {
    int dotIndex = fileName.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == fileName.length - 1) {
      return 'File';
    }
    return fileName.substring(dotIndex + 1).toUpperCase();
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  void _onColumnHeaderTap(SortColumn column) {
    setState(() {
      if (_sortColumn == column) {
        _sortOrder = _sortOrder == SortOrder.ascending
            ? SortOrder.descending
            : SortOrder.ascending;
      } else {
        _sortColumn = column;
        _sortOrder = SortOrder.ascending;
      }
      _sortItems();
    });
  }

  Widget _buildColumnHeader(String title, SortColumn column) {
    bool isActive = _sortColumn == column;

    return InkWell(
      onTap: () => _onColumnHeaderTap(column),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isActive ? Theme.of(context).primaryColor : null,
              ),
            ),
            const SizedBox(width: 4),
            if (isActive)
              Icon(
                _sortOrder == SortOrder.ascending
                    ? Icons.arrow_upward
                    : Icons.arrow_downward,
                size: 16,
                color: Theme.of(context).primaryColor,
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return buildInternal(context);
  }

  Widget buildInternal(BuildContext context) {
    UploadManager uploadManager = UploadManager(
      widget.directory.currentPath,
      api: widget.api,
    );
    List<Widget> ancestors = [];
    for (int i = 0; i < widget.directory.currentPath.length; i++) {
      String ancestor = widget.directory.currentPath.components[i];
      ancestors.add(
        ElevatedButton(
          onPressed: () {
            widget.eventHandlers.onAncestorTap(i);
          },
          child: Text(ancestor),
        ),
      );
    }
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor,
                width: 1,
              ),
            ),
          ),
          child: Row(children: ancestors),
        ),
        // Toolbar
        Container(
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              ElevatedButton.icon(
                label: Text('Up'),
                onPressed: () {
                  widget.eventHandlers.onAncestorTap(
                    widget.directory.currentPath.length - 2,
                  );
                },
                icon: Transform.rotate(
                  angle: -pi / 2,
                  child: Icon(Icons.subdirectory_arrow_right),
                ),
              ),
              ElevatedButton.icon(
                label: Text("Upload file"),
                onPressed: () {
                  uploadManager.uploadFiles();
                },
                icon: const Icon(Icons.upload_file),
              ),
              if (!kIsWeb)
                ElevatedButton.icon(
                  onPressed: () {
                    uploadManager.uploadDirectory();
                  },
                  icon: const Icon(Icons.drive_folder_upload),
                  label: Text("Upload folder"),
                ),
              const Spacer(),
              ToggleButtons(
                borderRadius: BorderRadius.circular(4),
                constraints: const BoxConstraints(minWidth: 40, minHeight: 36),
                isSelected: [
                  _viewType == ViewType.icon,
                  _viewType == ViewType.list,
                ],
                onPressed: (int index) {
                  setState(() {
                    _viewType = index == 0 ? ViewType.icon : ViewType.list;
                  });
                },
                children: const [
                  Icon(Icons.grid_view, size: 20),
                  Icon(Icons.list, size: 20),
                ],
              ),
            ],
          ),
        ),
        // Content
        Expanded(
          child: _viewType == ViewType.icon
              ? _buildIconView()
              : _buildListView(),
        ),
        Row(
          children: [
            Text(
              '${_sortedItems.length} items',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildIconView() {
    return GridView.builder(
      padding: const EdgeInsets.all(8.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 1.0,
        crossAxisSpacing: 8.0,
        mainAxisSpacing: 8.0,
      ),
      itemCount: _sortedItems.length,
      itemBuilder: (context, index) {
        final item = _sortedItems[index];
        return InkWell(
          onTap: () => widget.eventHandlers.onItemTap(item),
          onDoubleTap: () => widget.eventHandlers.onItemDoubleTap(item),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  item.isDirectory ? Icons.folder : Icons.insert_drive_file,
                  size: 48,
                  color: item.isDirectory ? Colors.blue[600] : Colors.grey[600],
                ),
                const SizedBox(height: 8),
                Text(
                  item.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildListView() {
    return Column(
      children: [
        // Header
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: _buildColumnHeader('Name', SortColumn.name),
              ),
              Expanded(
                flex: 1,
                child: _buildColumnHeader('Size', SortColumn.size),
              ),
              Expanded(
                flex: 1,
                child: _buildColumnHeader('Kind', SortColumn.kind),
              ),
              Expanded(
                flex: 2,
                child: _buildColumnHeader('Modified', SortColumn.mtime),
              ),
            ],
          ),
        ),
        // List items
        Expanded(
          child: ListView.builder(
            itemCount: _sortedItems.length,
            itemBuilder: (context, index) {
              final item = _sortedItems[index];
              return InkWell(
                onTap: () => widget.eventHandlers.onItemTap(item),
                onDoubleTap: () => widget.eventHandlers.onItemDoubleTap(item),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 4.0,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Theme.of(
                          context,
                        ).dividerColor.withValues(alpha: 0.3),
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Row(children: buildRow(item)),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  List<Widget> buildRow(DirectoryEntry item) {
    return [
      Expanded(
        flex: 3,
        child: Row(
          children: [
            Icon(
              item.isDirectory ? Icons.folder : Icons.insert_drive_file,
              size: 20,
              color: item.isDirectory ? Colors.blue[600] : Colors.grey[600],
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                item.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      ),
      Expanded(
        flex: 1,
        child: Text(
          item.isDirectory ? '--' : _formatSize(item.size),
          style: const TextStyle(fontSize: 12),
        ),
      ),
      Expanded(
        flex: 1,
        child: Text(
          item.isDirectory ? 'Directory' : _getFileExtension(item.name),
          style: const TextStyle(fontSize: 12),
        ),
      ),
      Expanded(
        flex: 2,
        child: Text(item.mtime, style: const TextStyle(fontSize: 12)),
      ),
    ];
  }
}
