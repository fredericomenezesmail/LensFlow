import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

class BackupService {
  final String serverUrl;

  BackupService(this.serverUrl);

  Future<bool> pingServer() async {
    try {
      final res = await http
          .get(Uri.parse('$serverUrl/ping'))
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Envia uma lista de arquivos para uma pasta no servidor.
  /// [onProgress] recebe (enviados, total).
  Future<void> uploadFiles(
      List<File> files,
      String folderName, {
        void Function(int sent, int total)? onProgress,
      }) async {
    for (int i = 0; i < files.length; i++) {
      final file = files[i];
      final req = http.MultipartRequest(
        'POST',
        Uri.parse('$serverUrl/upload'),
      );
      req.fields['folder'] = folderName;
      req.files.add(await http.MultipartFile.fromPath(
        'files',
        file.path,
        filename: p.basename(file.path),
      ));

      final res = await req.send();
      if (res.statusCode != 200) {
        throw Exception('Falha ao enviar ${file.path}: ${res.statusCode}');
      }
      onProgress?.call(i + 1, files.length);
    }
  }
}