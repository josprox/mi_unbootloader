import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'logs_screen.dart';

import 'dart:async'; // Add async import for Timer

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _tokenController = TextEditingController();
  final TextEditingController _popRunTokenController =
      TextEditingController(); // New token per user request
  final TextEditingController _timeShiftController = TextEditingController();
  final XiaomiApiService _apiService = XiaomiApiService();
  String _status = "Idle";
  bool _isRunning = false;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _checkServiceStatus();
    // Start polling status
    _statusTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _checkServiceStatus();
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _tokenController.dispose();
    _popRunTokenController.dispose();
    _timeShiftController.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _tokenController.text = prefs.getString('token') ?? '';
      _popRunTokenController.text = prefs.getString('poprun_token') ?? '';
      _timeShiftController.text = (prefs.getDouble('timeshift') ?? 0.0)
          .toString();

      if (prefs.getString('device_id') == null) {
        String devId = _apiService.generateDeviceId();
        prefs.setString('device_id', devId);
      }
    });
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', _tokenController.text);
    await prefs.setString('poprun_token', _popRunTokenController.text);
    await prefs.setDouble(
      'timeshift',
      double.tryParse(_timeShiftController.text) ?? 0.0,
    );
  }

  Future<void> _checkServiceStatus() async {
    final isRunning = await FlutterBackgroundService().isRunning();
    if (mounted && _isRunning != isRunning) {
      setState(() {
        _isRunning = isRunning;
      });
    }
  }

  Future<void> _toggleService() async {
    await _savePreferences();
    final service = FlutterBackgroundService();
    var isRunning = await service.isRunning();
    if (isRunning) {
      service.invoke("stopService");
    } else {
      await service.startService();
    }
    // Update local state immediately for responsiveness, though Timer will confirm
    setState(() {
      _isRunning = !isRunning;
    });
  }

  Future<void> _checkAccountStatus() async {
    await _savePreferences();
    final prefs = await SharedPreferences.getInstance();
    final deviceId =
        prefs.getString('device_id') ?? _apiService.generateDeviceId();

    setState(() => _status = "Checking...");
    bool canUnlock = await _apiService.checkUnlockStatus(
      _tokenController.text,
      deviceId,
    );
    setState(
      () => _status = canUnlock
          ? "Account Ready!"
          : "Account Not Ready (Check Logs)",
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Mi Bootloader Unlocker'),
            actions: [
              IconButton(
                icon: const Icon(Icons.history_edu),
                tooltip: 'View Logs',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LogsScreen()),
                  );
                },
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildServiceStatusCard(colorScheme, textTheme),
                  const SizedBox(height: 24),
                  Text(
                    "Configuration",
                    style: textTheme.titleLarge?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildConfigCard(colorScheme),
                  const SizedBox(height: 24),
                  Text(
                    "Actions",
                    style: textTheme.titleLarge?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildActionsCard(colorScheme),
                  const SizedBox(height: 48), // Bottom padding
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _toggleService,
        icon: Icon(_isRunning ? Icons.stop_circle : Icons.play_circle_filled),
        label: Text(_isRunning ? "Stop Service" : "Start Service"),
        backgroundColor: _isRunning
            ? colorScheme.errorContainer
            : colorScheme.primaryContainer,
        foregroundColor: _isRunning
            ? colorScheme.onErrorContainer
            : colorScheme.onPrimaryContainer,
      ),
    );
  }

  Widget _buildServiceStatusCard(ColorScheme colorScheme, TextTheme textTheme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: _isRunning ? colorScheme.primary : colorScheme.outlineVariant,
          width: _isRunning ? 2 : 1,
        ),
      ),
      color: _isRunning
          ? colorScheme.primaryContainer.withOpacity(0.3)
          : colorScheme.surfaceVariant,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Icon(
              _isRunning ? Icons.sync : Icons.pause_circle_outline,
              size: 48,
              color: _isRunning ? colorScheme.primary : colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              _isRunning ? "Service is Active" : "Service is Inactive",
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: _isRunning
                    ? colorScheme.onSurface
                    : colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Background process will auto-send requests at 12:00 AM Beijing Time.",
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: _isRunning
                    ? colorScheme.onSurface
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigCard(ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: colorScheme.outlineVariant, width: 1),
      ),
      // Use surfaceVariant or surface instead of surfaceContainerLow
      color: colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            TextField(
              controller: _tokenController,
              decoration: const InputDecoration(
                labelText: "Service Token",
                prefixIcon: Icon(Icons.key),
                helperText: "Cookie: new_bbs_serviceToken",
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _popRunTokenController,
              decoration: const InputDecoration(
                labelText: "PopRun Token",
                prefixIcon: Icon(Icons.vpn_key_outlined),
                helperText: "From Chrome JS snippet (Optional)",
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _timeShiftController,
              decoration: const InputDecoration(
                labelText: "Time Shift (ms)",
                prefixIcon: Icon(Icons.timer),
                helperText: "Pre-execution offset (e.g., 500)",
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsCard(ColorScheme colorScheme) {
    return Column(
      children: [
        FilledButton.icon(
          onPressed: _checkAccountStatus,
          icon: const Icon(Icons.verified_user_outlined),
          label: const Text("Check Account Status"),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            backgroundColor: colorScheme.secondaryContainer,
            foregroundColor: colorScheme.onSecondaryContainer,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.secondaryContainer.withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: colorScheme.secondary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Account Status: $_status",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
