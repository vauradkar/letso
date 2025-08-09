import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:letso/data.dart';
import 'package:letso/file_browser.dart';
import 'package:letso/main.dart';
import 'package:letso/platform_native.dart' if (kIsWeb) 'platform_web.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EventHandlers {
  final Function(DirectoryEntry) onItemTap;
  final Function(DirectoryEntry) onItemDoubleTap;
  final Function(int) onAncestorTap;

  EventHandlers({
    required this.onItemTap,
    required this.onItemDoubleTap,
    required this.onAncestorTap,
  });
}

class BrowserContainer extends StatefulWidget {
  const BrowserContainer({super.key});

  @override
  State<BrowserContainer> createState() => _BrowserContainerState();
}

class _BrowserContainerState extends State<BrowserContainer> {
  List<String> currentDirectory = ["/"];

  void _onItemTap(DirectoryEntry item) {
    debugPrint('Item tapped: ${item.name}');
    if (item.isDirectory) {
      setState(() {
        currentDirectory.add(item.name);
      });
    } else {
      debugPrint('Tapped on file: ${item.name}');
    }
  }

  void _onItemDoubleTap(DirectoryEntry item) {
    debugPrint('Item double tapped: ${item.name}');
    _onItemTap(item);
  }

  void _onAncestorTap(int index) {
    debugPrint('Ancestor tapped at index: $index');
    if (index < 0) {
      return;
    }
    if (index >= currentDirectory.length - 1) {
      // If the last item is tapped, do nothing.
      return;
    }

    setState(() {
      currentDirectory = currentDirectory.sublist(0, index + 1);
      debugPrint('Current directory updated: $currentDirectory');
    });
  }

  Future<DirectoryEntries> fetchData(List<String> currentDirectory) async {
    // await Future.delayed(const Duration(seconds: 1));
    final prefs = SharedPreferencesAsync();
    String? serverAddress = await prefs.getString('serverAddress');
    String? serverPort = await prefs.getString('serverPort');
    if (serverAddress == null || serverPort == null) {
      throw Exception('Server address or port is missing.');
    }

    // Construct the full API URL.
    final uri = getUri(await Preferences.loadPreferences(), '/api/browse/path');

    try {
      // final response = await http.get(uri);
      debugPrint(
        'posting data to $serverAddress:$serverPort with body: ${json.encode(currentDirectory)}',
      );
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          "Access-Control-Allow-Origin": "*",
          "Access-Control-Allow-Methods":
              "POST, GET, OPTIONS, PUT, DELETE, HEAD",
        },
        body: json.encode(currentDirectory),
      );
      debugPrint(
        'Posted data to $serverAddress:$serverPort with body: $currentDirectory',
      );

      if (response.statusCode == 200) {
        debugPrint('Response JSON: ');
        // If the server returns a 200 OK response, parse the JSON.
        debugPrint('Response body: ${response.body}');
        final Map<String, dynamic> jsonList = json.decode(response.body);
        debugPrint('Response JSON: $jsonList');
        return DirectoryEntries.fromJson(jsonList);
      } else {
        // If the server did not return a 200 OK response, handle the error.
        throw Exception(
          'Failed to load data. Status code: ${response.statusCode}',
        );
      }
    } catch (e) {
      // Handle network or other errors.
      throw Exception('Exception occurred: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DirectoryEntries>(
      future: fetchData(currentDirectory),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (snapshot.hasData) {
          EventHandlers eventHandlers = EventHandlers(
            onItemTap: _onItemTap,
            onItemDoubleTap: _onItemDoubleTap,
            onAncestorTap: _onAncestorTap,
          );
          return FileBrowser(
            directoryEntries: snapshot.data!,
            eventHandlers: eventHandlers,
          );
        } else {
          // Handle case where data is null
          return const Center(child: Text('No data available'));
        }
      },
    );
  }
}
