import 'dart:async';
import 'package:nsd/nsd.dart';

Future<String?> discoverServer() async {
  const serviceType = '_lensflow._tcp';
  Discovery? discovery;

  try {
    discovery = await startDiscovery(serviceType);

    final completer = Completer<String?>();

    discovery.addListener(() {
      final services = discovery!.services;
      if (services.isEmpty) return;

      for (final service in services) {
        final host = service.host;
        final port = service.port;

        if (host != null && port != null) {
          final url = 'http://$host:$port';
          if (!completer.isCompleted) completer.complete(url);
        }
      }
    });

    // aguarda até 8 segundos pelo servidor
    final result = await completer.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () => null,
    );

    return result;
  } catch (e) {
    return null;
  } finally {
    if (discovery != null) {
      await stopDiscovery(discovery);
    }
  }
}