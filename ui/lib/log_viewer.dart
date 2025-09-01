import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:letso/logger_manager.dart';

const String kFontFamily = 'FiraMonoNerdFont';

class LogViewer extends StatelessWidget {
  final Future<String> logMessages;
  final VoidCallback onClear;

  const LogViewer({
    super.key,
    required this.logMessages,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Viewer'),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: logger.clear,
            tooltip: 'Clear Logs',
          ),
        ],
      ),
      body: FutureBuilder<String>(
        future: logger.getLogs(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading logs',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    style: TextStyle(color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final logs = snapshot.data ?? '';
          if (logs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No logs available',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return _LogContent(logs: logs);
        },
      ),
    );
  }
}

class _LogContent extends StatefulWidget {
  final String logs;

  const _LogContent({required this.logs});

  @override
  State<_LogContent> createState() => _LogContentState();
}

class _LogContentState extends State<_LogContent> {
  bool _wrapText = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _copyLogs() {
    Clipboard.setData(ClipboardData(text: widget.logs));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Logs copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _toggleTextWrap() {
    setState(() {
      _wrapText = !_wrapText;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lines = widget.logs.split('\n');
    final lineNumberWidth = (lines.length.toString().length * 12.0) + 16.0;

    return Column(
      children: [
        // Controls bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
          ),
          child: Row(
            children: [
              ElevatedButton.icon(
                onPressed: _copyLogs,
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copy All'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _toggleTextWrap,
                icon: Icon(
                  _wrapText ? Icons.wrap_text : Icons.format_align_left,
                  size: 18,
                ),
                label: Text(_wrapText ? 'Unwrap' : 'Wrap'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${lines.length} lines',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        ),

        // Log content
        Expanded(
          child: Container(
            color: Colors.grey[50],
            child: Scrollbar(
              controller: _scrollController,
              child: _wrapText
                  ? SingleChildScrollView(
                      controller: _scrollController,
                      scrollDirection: Axis.vertical,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (int i = 0; i < lines.length; i++)
                            _LogLine(
                              lineNumber: i + 1,
                              content: lines[i],
                              wrapText: _wrapText,
                              lineNumberWidth: lineNumberWidth,
                              isEvenLine: i % 2 == 0,
                            ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      controller: _scrollController,
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: IntrinsicWidth(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (int i = 0; i < lines.length; i++)
                                _LogLine(
                                  lineNumber: i + 1,
                                  content: lines[i],
                                  wrapText: _wrapText,
                                  lineNumberWidth: lineNumberWidth,
                                  isEvenLine: i % 2 == 0,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

final List<(RegExp, Color)> levels = [
  (RegExp(r'error|err|^\s*(\[E\])', caseSensitive: false), Colors.red),
  (RegExp(r'warning|warn|^\s*(\[W\])', caseSensitive: false), Colors.orange),
  (RegExp(r'info|^\s*(\[I\])', caseSensitive: false), Colors.blue),
  (RegExp(r'debug|^\s*(\[D\])', caseSensitive: false), Colors.purple),
  (RegExp(r'success|^\s*(\[S\])', caseSensitive: false), Colors.green),
];

class _LogLine extends StatelessWidget {
  final int lineNumber;
  final String content;
  final bool wrapText;
  final double lineNumberWidth;
  final bool isEvenLine;

  const _LogLine({
    required this.lineNumber,
    required this.content,
    required this.wrapText,
    required this.lineNumberWidth,
    required this.isEvenLine,
  });

  Color _getLogLevelColor(String line) {
    final lowerLine = line.toLowerCase();
    for (var (pattern, color) in levels) {
      if (pattern.hasMatch(lowerLine)) {
        return color;
      }
    }
    return Colors.grey[800]!;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isEvenLine ? Colors.white : Colors.grey[50],
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!, width: 0.5),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Line number section
            Container(
              width: lineNumberWidth,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                border: Border(
                  right: BorderSide(color: Colors.grey[300]!, width: 1),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                lineNumber.toString(),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontFamily: kFontFamily,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.right,
              ),
            ),

            // Log content section
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                width: double.infinity,
                child: SelectableText(
                  content.isEmpty ? ' ' : content,
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: kFontFamily,
                    color: _getLogLevelColor(content),
                    height: 1.4,
                  ),
                  maxLines: wrapText ? null : 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
