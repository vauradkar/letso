import 'package:flutter/material.dart';
import 'package:letso/api.dart';
import 'package:letso/licenses_widget.dart';
import 'package:letso/logger_manager.dart';
import 'package:letso/app_state.dart';
import 'package:letso/browser_container.dart';
import 'package:letso/log_viewer.dart';
import 'package:letso/preferences.dart';
import 'package:letso/settings_page.dart';
import 'package:letso/status_bar.dart';
import 'package:letso/upload_manager.dart';

// This is the main entry point for the Flutter application.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // logger.i("Application started");
  await logger.initLogger(logSize: 10000);
  logger.i("Logger initialized");

  runApp(
    MaterialApp(
      title: 'letso',
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

  void showLogsPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LogViewer(
          logMessages: logger.getLogs(),
          onClear: () {
            debugPrint('Clear logs not implemented');
          },
        ),
      ),
    );
  }

  Widget _buildMainContent(
    BuildContext context,
    AsyncSnapshot<Preferences> snapshot,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(
        child: Column(
          children: [Text("loading preferences"), CircularProgressIndicator()],
        ),
      );
    } else if (snapshot.hasError) {
      return Center(child: Text('Error: ${snapshot.error}'));
    } else if (snapshot.hasData) {
      Preferences preferences = snapshot.data as Preferences;
      Api api = Api.create(preferences);
      AppState appState = AppState(
        preferences: preferences,
        api: api,
        uploadManager: UploadManager(api: api),
      );
      if (preferences.isConfigured()) {
        return Column(
          children: [
            Expanded(child: BrowserContainer(appState: appState)),
            StatusBar(appState: appState),
          ],
        );
      } else {
        return Scaffold(
          body: SettingsPage(
            onChange: () {
              setState(() {});
            },
          ),
        );
      }
    } else {
      return const Center(child: Text('No preferences found'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Let That Sync Out'),
        actions: [
          IconButton(
            onPressed: () => showLogsPage(context),
            icon: Icon(Icons.terminal),
          ),
          IconButton(
            onPressed: () => showSettingsPage(context),
            icon: Icon(Icons.settings),
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LicencesWidget()),
              );
            },
            icon: const Icon(Icons.info_outline),
          ),
        ],
      ),
      body: FutureBuilder(
        future: Preferences.loadPreferences(),
        builder: _buildMainContent,
      ),
    );
  }
}
