import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'core/network/mdns_discovery.dart';
import 'core/service/backup_service.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'LensFlow',
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
    home: const BackupPage(),
  );
}

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});
  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  String _status = 'Aguardando...';
  String? _serverUrl;
  List<File> _selectedFiles = [];
  int _sent = 0;
  int _total = 0;
  bool _loading = false;

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      final sdkInt = int.parse(
        (await Process.run('getprop', ['ro.build.version.sdk'])).stdout.trim(),
      );
      if (sdkInt >= 33) {
        await [Permission.photos, Permission.videos, Permission.audio]
            .request();
      } else {
        await Permission.storage.request();
      }
    }
  }

  Future<void> _discoverServer() async {
    setState(() {
      _loading = true;
      _status = 'Procurando servidor na rede...';
    });
    final url = await discoverServer();
    if (url == null) {
      setState(() {
        _status = 'Servidor não encontrado automaticamente.';
        _loading = false;
      });

      _showManualIpDialog();
      return;
    }
    final svc = BackupService(url);
    final ok = await svc.pingServer();
    setState(() {
      _serverUrl = ok ? url : null;
      _status = ok ? 'Servidor encontrado: $url' : 'Servidor não respondeu ao ping.';
      _loading = false;
    });
  }

  Future<void> _pickFiles() async {
    await _requestPermissions();
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );
    if (result != null) {
      setState(() {
        _selectedFiles = result.paths
            .whereType<String>()
            .map(File.new)
            .toList();
        _status = '${_selectedFiles.length} arquivo(s) selecionado(s)';
      });
    }
  }

  Future<void> _startBackup() async {
    if (_serverUrl == null || _selectedFiles.isEmpty) return;
    final svc = BackupService(_serverUrl!);
    setState(() {
      _loading = true;
      _sent = 0;
      _total = _selectedFiles.length;
      _status = 'Enviando arquivos...';
    });
    try {
      await svc.uploadFiles(
        _selectedFiles,
        'backup_${DateTime.now().millisecondsSinceEpoch}',
        onProgress: (sent, total) => setState(() {
          _sent = sent;
          _status = 'Enviando $sent/$total...';
        }),
      );
      setState(() => _status = 'Backup concluído! $_total arquivo(s) enviado(s).');
    } catch (e) {
      setState(() => _status = 'Erro: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('LensFlow')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Status', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    Text(_status),
                    if (_serverUrl != null) ...[
                      const SizedBox(height: 4),
                      Text(_serverUrl!,
                          style: const TextStyle(
                              color: Colors.teal, fontSize: 12)),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _loading ? null : _discoverServer,
              icon: const Icon(Icons.wifi_find),
              label: const Text('Encontrar Servidor'),
            ),
            OutlinedButton.icon(
              onPressed: _loading ? null : _showManualIpDialog,
              icon: const Icon(Icons.edit),
              label: const Text('Inserir IP manualmente'),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _loading ? null : _pickFiles,
              icon: const Icon(Icons.folder_open),
              label: const Text('Selecionar Arquivos / Pasta'),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed:
              (_loading || _serverUrl == null || _selectedFiles.isEmpty)
                  ? null
                  : _startBackup,
              icon: const Icon(Icons.backup),
              label: const Text('Iniciar Backup'),
            ),
            if (_total > 0) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(value: _total > 0 ? _sent / _total : 0),
              const SizedBox(height: 4),
              Text('$_sent / $_total arquivos'),
            ],
            if (_loading) const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }

  Future<void> _connectManual(String url) async {

    setState(() {
      _loading = true;
      _status = 'Testando conexão...';
    });

    final svc = BackupService(url);
    final ok = await svc.pingServer();

    if (ok) {
      setState(() {
        _serverUrl = url;
        _status = 'Conectado manualmente: $url';
        _loading = false;
      });
    } else {
      setState(() {
        _status = 'Falha ao conectar. Verifique o IP.';
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Servidor não respondeu')),
      );
    }
  }

  void _showManualIpDialog() {

    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Servidor não encontrado'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Inserir IP manualmente'),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: 'Ex: 192.168.0.7:5000',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final input = controller.text.trim();

              if (input.isEmpty) return;

              final url = input.startsWith('http')
                  ? input
                  : 'http://$input';

              Navigator.pop(context);

              await _connectManual(url);
            },
            child: const Text('Conectar'),
          ),
        ],
      ),
    );
  }
}