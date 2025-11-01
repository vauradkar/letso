import 'package:flutter/material.dart';
import 'package:letso/api.dart';
import 'package:letso/app_info_widget.dart';
import 'package:letso/logger_manager.dart';
import 'package:letso/app_state.dart';
import 'package:letso/browser_container.dart';
import 'package:letso/log_viewer.dart';
import 'package:letso/settings.dart';
import 'package:letso/settings_page.dart';
import 'package:letso/status_bar.dart';
import 'package:letso/upload_manager.dart';
import 'package:package_info_plus/package_info_plus.dart';

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
  AppState? appState;
  void showSettingsPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsPage(
          onChange: () {
            setState(() {});
          },
          appState: appState,
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
            logger.clear();
          },
        ),
      ),
    );
  }

  Widget _buildMainContent(
    BuildContext context,
    AsyncSnapshot<AppState> snapshot,
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
      AppState appState = snapshot.data as AppState;
      if (appState.settings.isConfigured()) {
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
            appState: appState,
          ),
        );
      }
    } else {
      return const Center(child: Text('No preferences found'));
    }
  }

  Future<AppState> _loadAppState() async {
    final settings = await Settings.loadSettings();
    Api api = Api.create(settings);
    final serverVersion = await api.getServerVersion();
    final apiVersion = await api.getApiVersion();
    final packageInfo = await PackageInfo.fromPlatform();
    AppState state = AppState(
      settings: settings,
      api: api,
      uploadManager: UploadManager(api: api),
      serverVersion: serverVersion,
      apiVersion: apiVersion,
      packageInfo: packageInfo,
    );
    appState = state;
    return state;
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
                MaterialPageRoute(
                  builder: (_) => FutureBuilder(
                    future: _loadAppState(),
                    builder: _buildAppInfoWidget,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.info_outline),
          ),
        ],
      ),
      body: FutureBuilder(future: _loadAppState(), builder: _buildMainContent),
    );
  }

  Widget _buildAppInfoWidget(
    BuildContext context,
    AsyncSnapshot<AppState> snapshot,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    } else if (snapshot.hasError) {
      logger.e('Error loading app state: ${snapshot.error}');
      return Center(child: Text('Error: ${snapshot.error}'));
    } else if (snapshot.hasData) {
      AppState appState = snapshot.data as AppState;
      return AppInfoWidget(
        apiVersion: appState.apiVersion,
        serverVersion: appState.serverVersion,
        appVersion: appState.packageInfo.version,
      );
    } else {
      return const Center(child: Text('No data'));
    }
  }
}
