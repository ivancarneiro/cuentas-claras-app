import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/logger_service.dart';

/// Floating debug button that opens a log viewer overlay.
///
/// Shows a small badge with the count of errors/warnings.
/// Tap to open the full log viewer.
class DebugOverlay extends StatefulWidget {
  final Widget child;

  static final ValueNotifier<bool> showDebugPanel = ValueNotifier<bool>(false);

  const DebugOverlay({super.key, required this.child});

  @override
  State<DebugOverlay> createState() => _DebugOverlayState();
}

class _DebugOverlayState extends State<DebugOverlay> {
  bool _showLogViewer = false;

  @override
  void initState() {
    super.initState();
    DebugOverlay.showDebugPanel.addListener(_onDebugPanelChanged);
  }

  @override
  void dispose() {
    DebugOverlay.showDebugPanel.removeListener(_onDebugPanelChanged);
    super.dispose();
  }

  void _onDebugPanelChanged() {
    if (mounted) {
      setState(() {
        _showLogViewer = DebugOverlay.showDebugPanel.value;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_showLogViewer)
          Positioned(
            left: 12,
            bottom: 80,
            child: _LogViewerPanel(
              onClose: () => DebugOverlay.showDebugPanel.value = false,
            ),
          ),
      ],
    );
  }
}

/// Panel that displays log entries.
class _LogViewerPanel extends StatefulWidget {
  final VoidCallback onClose;

  const _LogViewerPanel({required this.onClose});

  @override
  State<_LogViewerPanel> createState() => _LogViewerPanelState();
}

class _LogViewerPanelState extends State<_LogViewerPanel> {
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _copyToClipboard(List<LogEntry> entries) {
    final text = entries.map((e) => e.toString()).join('\n');
    Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Copiadas ${entries.length} entradas al portapapeles'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(bottom: 120, left: 16, right: 16),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          backgroundColor: Colors.grey.shade800,
        ),
      );
    }
  }

  void _scrollToBottom() {
    if (_autoScroll && _scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LoggerService>(
      builder: (context, logger, _) {
        // Auto-scroll on new entries
        _scrollToBottom();

        final entries = logger.entries;

        return Container(
          width: MediaQuery.of(context).size.width * 0.92,
          height: 320,
          margin: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            color: const Color(0xF0111111),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24, width: 0.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.white12)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.bug_report, size: 16, color: Colors.white70),
                    const SizedBox(width: 8),
                    const Text('DEBUG LOGS',
                        style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => _copyToClipboard(entries),
                      child: const Icon(Icons.copy, size: 14, color: Colors.white54),
                    ),
                    const SizedBox(width: 8),
                    Text('${entries.length} entradas',
                        style: const TextStyle(color: Colors.white38, fontSize: 10)),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setState(() => _autoScroll = !_autoScroll),
                      child: Icon(
                        _autoScroll ? Icons.vertical_align_bottom : Icons.vertical_align_center,
                        size: 14, color: _autoScroll ? Colors.blue : Colors.white38,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: widget.onClose,
                      child: const Icon(Icons.close, size: 16, color: Colors.white54),
                    ),
                  ],
                ),
              ),
              // Log list
              Expanded(
                child: entries.isEmpty
                    ? const Center(
                        child: Text('Sin logs aún. Realizá una acción en la app.',
                            style: TextStyle(color: Colors.white30, fontSize: 12)),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        itemCount: entries.length,
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          return _LogEntryTile(entry: entry);
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LogEntryTile extends StatelessWidget {
  final LogEntry entry;

  const _LogEntryTile({required this.entry});

  Color _levelColor() {
    switch (entry.level) {
      case LogLevel.error:
        return Colors.red.shade300;
      case LogLevel.warning:
        return Colors.orange.shade300;
      case LogLevel.info:
        return Colors.green.shade300;
      case LogLevel.debug:
        return Colors.grey.shade400;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: SelectableText(
        entry.toString(),
        style: TextStyle(
          color: _levelColor(),
          fontSize: 11,
          fontFamily: 'monospace',
          height: 1.3,
        ),
      ),
    );
  }
}

