import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BLE Auto Scan Listener',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: const ScanPage(),
    );
  }
}

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  bool _scanning = false;
  List<BluetoothDevice> _devices = [];

  Future<void> _checkPermissions() async {
    // Android 12+
    if (await Permission.bluetoothScan.isDenied) {
      await Permission.bluetoothScan.request();
    }
    if (await Permission.bluetoothConnect.isDenied) {
      await Permission.bluetoothConnect.request();
    }

    // Localización requerida para escaneo BLE
    if (await Permission.locationWhenInUse.isDenied) {
      await Permission.locationWhenInUse.request();
    }
  }

  Future<void> _startScan() async {
    await _checkPermissions();

    final state = await FlutterBluePlus.adapterState.first;

    if (!mounted) return;

    if (state != BluetoothAdapterState.on) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Bluetooth no está encendido todavía. Intenta de nuevo.',
          ),
        ),
      );
      return;
    }

    setState(() => _scanning = true);
    _devices.clear();

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 12));

    FlutterBluePlus.onScanResults.listen((results) {
      for (final r in results) {
        if (!_devices.contains(r.device)) {
          if (mounted) {
            setState(() => _devices.add(r.device));
          }
        }
      }
    });

    await Future.delayed(const Duration(seconds: 12));
    if (mounted) {
      await FlutterBluePlus.stopScan();
      setState(() => _scanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // UI como lo tenías...
    return Scaffold(
      appBar: AppBar(title: const Text('BLE Listener Chat')),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: _scanning ? null : _startScan,
            child: Text(_scanning ? 'Escaneando...' : 'Buscar dispositivos'),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _devices.length,
              itemBuilder: (context, index) {
                final d = _devices[index];
                return ListTile(
                  title: Text(
                    d.platformName.isNotEmpty
                        ? d.platformName
                        : d.remoteId.toString(),
                  ),
                  subtitle: Text(d.remoteId.toString()),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class DevicePage extends StatefulWidget {
  const DevicePage({super.key, required this.device});
  final BluetoothDevice device;

  @override
  State<DevicePage> createState() => _DevicePageState();
}

class _DevicePageState extends State<DevicePage> {
  List<BluetoothService> _services = [];
  BluetoothCharacteristic? _notifyChar;
  BluetoothCharacteristic? _writeChar;
  final _messages = <String>[];
  final _txController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    await widget.device.connect();
    _services = await widget.device.discoverServices();
    setState(() {});
  }

  void _subscribeTo(BluetoothCharacteristic c) async {
    await c.setNotifyValue(true);
    c.onValueReceived.listen((value) {
      try {
        setState(() => _messages.insert(0, utf8.decode(value)));
      } catch (_) {
        setState(() => _messages.insert(0, value.toString()));
      }
    });
    _notifyChar = c;
  }

  void _sendText() async {
    if (_writeChar == null) return;
    final data = utf8.encode(_txController.text);
    await _writeChar!.write(data, withoutResponse: true);
    _txController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.device.platformName.isEmpty
              ? widget.device.remoteId.str
              : widget.device.platformName,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                for (final s in _services)
                  ExpansionTile(
                    title: Text('Service ${s.uuid.str128}'),
                    children: [
                      for (final c in s.characteristics)
                        ListTile(
                          title: Text('Char ${c.uuid.str128}'),
                          subtitle: Text('props: ${c.properties}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (c.properties.notify)
                                IconButton(
                                  icon: const Icon(Icons.waves),
                                  onPressed: () => _subscribeTo(c),
                                ),
                              if (c.properties.write ||
                                  c.properties.writeWithoutResponse)
                                IconButton(
                                  icon: const Icon(Icons.send),
                                  onPressed: () {
                                    _writeChar = c;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Característica de escritura seleccionada',
                                        ),
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
          if (_notifyChar != null) ...[
            const Divider(),
            const Text('Mensajes recibidos:'),
            for (final m in _messages.take(5)) ListTile(title: Text(m)),
          ],
          if (_writeChar != null) ...[
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _txController,
                      decoration: const InputDecoration(
                        labelText: 'Mensaje al dispositivo',
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _sendText,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
