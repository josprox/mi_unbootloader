import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/app_log.dart';
import '../services/db_service.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final DatabaseService _dbService = DatabaseService();
  late Future<List<AppLog>> _logsFuture;

  @override
  void initState() {
    super.initState();
    _refreshLogs();
  }

  void _refreshLogs() {
    setState(() {
      _logsFuture = _dbService.getLogs();
    });
  }

  Future<void> _clearLogs() async {
    await _dbService.clearLogs();
    _refreshLogs();
  }

  Color _getLogColor(String type, ColorScheme scheme) {
    switch (type) {
      case 'ERROR':
        return scheme.error;
      case 'SUCCESS':
        return scheme.primary;
      case 'WARNING':
        return scheme.tertiary;
      default:
        return scheme.onSurface;
    }
  }

  IconData _getLogIcon(String type) {
    switch (type) {
      case 'ERROR':
        return Icons.error_outline;
      case 'SUCCESS':
        return Icons.check_circle_outline;
      case 'WARNING':
        return Icons.warning_amber_rounded;
      default:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('System Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshLogs,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text("Clear Logs?"),
                  content: const Text("This cannot be undone."),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("Cancel"),
                    ),
                    FilledButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _clearLogs();
                      },
                      child: const Text("Clear"),
                    ),
                  ],
                ),
              );
            },
            tooltip: 'Clear Logs',
          ),
        ],
      ),
      body: FutureBuilder<List<AppLog>>(
        future: _logsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notes, size: 64, color: colorScheme.outline),
                  const SizedBox(height: 16),
                  Text(
                    "No logs available",
                    style: TextStyle(
                      fontSize: 18,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          final logs = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: logs.length,
            itemBuilder: (ctx, i) {
              final log = logs[i];
              final color = _getLogColor(log.type, colorScheme);

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                elevation: 0,
                color: colorScheme.surface,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: color.withOpacity(0.1),
                    child: Icon(_getLogIcon(log.type), color: color, size: 20),
                  ),
                  title: Text(
                    log.message,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      DateFormat('yyyy-MM-dd HH:mm:ss').format(log.timestamp),
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
