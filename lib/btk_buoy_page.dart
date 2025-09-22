import 'dart:convert';
import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'auth_page.dart';

/// =======================
/// Clase de autenticación
/// =======================
class BtkBuoyAuthenticator {
  static const Duration CONNECTION_TIMEOUT = Duration(seconds: 10);
  static const Duration AUTH_TIMEOUT = Duration(seconds: 5);

  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _writeCharacteristic;
  BluetoothCharacteristic? _notifyCharacteristic;
  StreamSubscription<List<int>>? _notifySub;

  String? _pendingResponse;
  bool _isAuthenticated = false;

  // Indica si deberíamos usar Write With Response (true) o WithoutResponse (false)
  bool _preferWriteWithResponse = false;

  Future<bool> connectAndAuthenticate(
    BluetoothDevice device,
    String password,
  ) async {
    try {
      debugPrint('Conectando a ${device.platformName}...');
      await device.connect(timeout: CONNECTION_TIMEOUT, autoConnect: false);

      if (Platform.isAndroid) {
        await device.requestMtu(185);
      }

      _connectedDevice = device;

      List<BluetoothService> services = await device.discoverServices();
      await _findCharacteristics(services);

      if (_writeCharacteristic == null) {
        throw Exception('No se encontró characteristic de escritura');
      }

      if (_notifyCharacteristic != null) {
        await _notifyCharacteristic!.setNotifyValue(true);
        _notifySub = _notifyCharacteristic!.lastValueStream.listen(
          _onDataReceived,
        );
      }

      // 👉 Despertar micro
      await _sendActivationCommand();
      // 👉 Autenticación
      bool authSuccess = await _authenticate(password);

      _isAuthenticated = authSuccess;
      return authSuccess;
    } catch (e, st) {
      debugPrint('Error en connectAndAuthenticate: $e\n$st');
      await disconnect();
      return false;
    }
  }

  Future<void> _findCharacteristics(List<BluetoothService> services) async {
    for (final service in services) {
      for (final c in service.characteristics) {
        final uuid = c.uuid.toString().toLowerCase();

        // Buscamos la 704 (igual que tenías)
        if (uuid.endsWith('703')) {
          // preferimos write (with response) si está disponible
          if (c.properties.write) {
            _writeCharacteristic = c;
            _preferWriteWithResponse = true;
            debugPrint('➡️ Usando característica 704 (write WITH response)');
          } else if (c.properties.writeWithoutResponse &&
              _writeCharacteristic == null) {
            _writeCharacteristic = c;
            _preferWriteWithResponse = false;
            debugPrint('➡️ Usando característica 704 (write WITHOUT response)');
          }

          if (c.properties.notify) {
            _notifyCharacteristic = c;
            debugPrint('➡️ Usando característica de notificación 704');
            // setNotify lo volveremos a hacer al conectar (por seguridad)
            await c.setNotifyValue(true);
          }
        }
      }
    }

    if (_writeCharacteristic == null) {
      throw Exception('No se encontró la característica 704 para escritura');
    }
  }

  Future<void> _sendActivationCommand() async {
    const wake = '@@@@@@@@@@@@@@@'; // sin \r\n
    await _writeCharacteristic!.write(utf8.encode(wake), withoutResponse: true);
    debugPrint('🔔 Wake enviado');
    await Future.delayed(const Duration(seconds: 2));
  }

  // Autenticación con clave
  Future<bool> _authenticate(String password) async {
    try {
      final authCommand = '@FF,50,"$password"';
      _pendingResponse = ':FF,50'; // esperamos respuesta que empiece así
      await _writeCommand(
        authCommand,
        preferResponse: _preferWriteWithResponse,
      );

      final start = DateTime.now();
      while (_pendingResponse != null) {
        if (DateTime.now().difference(start) > AUTH_TIMEOUT) {
          debugPrint('⏱️ Timeout de autenticación');
          return false;
        }
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return _isAuthenticated;
    } catch (e) {
      debugPrint('Error en _authenticate: $e');
      return false;
    }
  }

  // Escritura con fragmentación adaptada y fallback en caso de GATT_INVALID_ATTRIBUTE_LENGTH
  Future<void> _writeCommand(String command, {bool? preferResponse}) async {
    if (_writeCharacteristic == null) {
      throw Exception('No hay característica de escritura');
    }

    final fullCommand = command.endsWith('\r\n') ? command : '$command\r\n';
    final data = utf8.encode(fullCommand);

    final useWithResponse = preferResponse ?? _preferWriteWithResponse;

    int chunkSizeWithResponse = 16;
    int chunkSizeWithoutResponse = 16;
    final int pacingWithResponseMs = 50;
    final int pacingWithoutResponseMs = 120;

    Future<void> _doWriteChunks(
      bool withResp,
      int chunkSize,
      int pacingMs,
    ) async {
      for (int i = 0; i < data.length; i += chunkSize) {
        final end = (i + chunkSize < data.length) ? i + chunkSize : data.length;
        final chunk = data.sublist(i, end);
        await _writeCharacteristic!.write(chunk, withoutResponse: !withResp);
        debugPrint(
          '📦 Chunk (${withResp ? "withResponse" : "noResponse"}) enviado: ${chunk.length} bytes',
        );
        await Future.delayed(Duration(milliseconds: pacingMs));
      }
    }

    try {
      if (useWithResponse) {
        try {
          await _doWriteChunks(
            true,
            chunkSizeWithResponse,
            pacingWithResponseMs,
          );
        } on Exception catch (e) {
          // Si falla por longitud de atributo o similar, intentamos fallback a withoutResponse
          final errStr = e.toString();
          debugPrint('❌ Error escribiendo (withResponse): $errStr');
          if (errStr.contains('GATT_INVALID_ATTRIBUTE_LENGTH') ||
              errStr.contains('android-code: 13') ||
              errStr.contains('13')) {
            debugPrint(
              '🔁 Fallback: reintentando con WITHOUT_RESPONSE y chunks más pequeños',
            );
            // reintento con withoutResponse y chunks más pequeños y pacing mayor
            await _doWriteChunks(
              false,
              (chunkSizeWithoutResponse <= 0 ? 12 : chunkSizeWithoutResponse),
              pacingWithoutResponseMs,
            );
          } else {
            rethrow;
          }
        }
      } else {
        // Si caller pide specifically withoutResponse, usamos el modo conservador con pacing
        await _doWriteChunks(
          false,
          chunkSizeWithoutResponse,
          pacingWithoutResponseMs,
        );
      }

      debugPrint('✅ Comando completo enviado: $fullCommand');
    } catch (e) {
      debugPrint('❌ Error en _writeCommand (final): $e');
      rethrow;
    }
  }

  void _onDataReceived(List<int> data) {
    String message;
    try {
      message = utf8.decode(data).trim();
    } catch (e) {
      debugPrint('Error decodificando notificación: $e');
      return;
    }

    debugPrint('📩 Mensaje recibido: $message');

    if (_pendingResponse != null && message.startsWith(_pendingResponse!)) {
      if (message.contains(':FF,50,01')) {
        _isAuthenticated = true;
        debugPrint('🔑 Autenticación OK');
      } else if (message.contains(':FF,50,00')) {
        _isAuthenticated = false;
        debugPrint('❌ Autenticación ERROR');
      }
      _pendingResponse = null;
    }
  }

  Future<void> disconnect() async {
    try {
      await _notifySub?.cancel();
      _notifySub = null;

      if (_connectedDevice != null) {
        await _connectedDevice!.disconnect();
      }
    } catch (e) {
      debugPrint('Error en disconnect: $e');
    }
    _connectedDevice = null;
    _writeCharacteristic = null;
    _notifyCharacteristic = null;
    _isAuthenticated = false;
    _pendingResponse = null;
  }

  bool get isAuthenticated => _isAuthenticated;
  bool get isConnected => _connectedDevice?.isConnected ?? false;

  Future<void> sendCommand(String command) async {
    await _writeCommand(command, preferResponse: _preferWriteWithResponse);
  }
}

/// =======================
/// Widget principal
/// =======================
class BtkBuoyPage extends StatefulWidget {
  const BtkBuoyPage({super.key});

  @override
  State<BtkBuoyPage> createState() => _BtkBuoyPageState();
}

class _BtkBuoyPageState extends State<BtkBuoyPage> {
  final BtkBuoyAuthenticator authenticator = BtkBuoyAuthenticator();
  bool _scanning = false;
  List<BluetoothDevice> _devices = [];

  Future<void> _checkPermissions() async {
    if (await Permission.bluetoothScan.isDenied) {
      await Permission.bluetoothScan.request();
    }
    if (await Permission.bluetoothConnect.isDenied) {
      await Permission.bluetoothConnect.request();
    }
    if (await Permission.locationWhenInUse.isDenied) {
      await Permission.locationWhenInUse.request();
    }
  }

  Future<void> _startScan() async {
    await _checkPermissions();
    setState(() {
      _devices.clear();
      _scanning = true;
    });

    FlutterBluePlus.startScan(timeout: const Duration(seconds: 8));
    FlutterBluePlus.onScanResults.listen((results) {
      for (final r in results) {
        if (!_devices.contains(r.device)) {
          setState(() => _devices.add(r.device));
        }
      }
    });

    await Future.delayed(const Duration(seconds: 8));
    await FlutterBluePlus.stopScan();
    if (mounted) setState(() => _scanning = false);
  }

  Future<void> _sendExampleCommand() async {
    if (authenticator.isAuthenticated) {
      await authenticator.sendCommand('@FF,60,STATUS\r\n');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Comando STATUS enviado")));
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("No autenticado todavía")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Boya BTK - Autenticación")),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: _scanning ? null : _startScan,
            child: Text(_scanning ? "Buscando..." : "Buscar dispositivos"),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _devices.length,
              itemBuilder: (context, index) {
                final d = _devices[index];
                return ListTile(
                  title: Text(
                    d.platformName.isNotEmpty ? d.platformName : "Sin nombre",
                  ),
                  subtitle: Text(d.remoteId.toString()),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => AuthPage(device: d)),
                    );
                  },
                );
              },
            ),
          ),
          ElevatedButton(
            onPressed: _sendExampleCommand,
            child: const Text("Enviar comando STATUS"),
          ),
        ],
      ),
    );
  }
}
