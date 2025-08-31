import 'package:flutter/material.dart';
import 'package:letso/api.dart';
import 'package:letso/app_state.dart';
import 'package:letso/browser_container.dart';
import 'package:letso/preferences.dart';
import 'package:letso/settings_page.dart';

// This is the main entry point for the Flutter application.
void main() async {
  runApp(
    MaterialApp(
      title: 'REST API App',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: MyApp(),
    ),
  );
}

// Define the main application widget.
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  void showSettingsPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsPage(
          onChange: () {
            setState(() {});
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Let That Sync Out'),
        actions: [
          IconButton(
            onPressed: () => showSettingsPage(context),
            icon: Icon(Icons.settings),
          ),
        ],
      ),
      body: FutureBuilder(
        future: Preferences.loadPreferences(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                children: [
                  Text("loading preferences"),
                  CircularProgressIndicator(),
                ],
              ),
            );
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (snapshot.hasData) {
            Preferences preferences = snapshot.data as Preferences;
            Api api = Api.create(preferences);
            AppState appState = AppState(preferences: preferences, api: api);
            if (preferences.isConfigured()) {
              return BrowserContainer(appState: appState);
            } else {
              return Scaffold(
                body: SettingsPage(
                  onChange: () {
                    setState(() {});
                  },
                ),
              );
              // return const Center(child: Text('No preferences found'));
            }
          } else {
            return const Center(child: Text('No preferences found'));
          }
        },
      ),
    );
  }
}
