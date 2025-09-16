import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'btk_buoy_page.dart'; // tu clase que ya tienes

class AuthPage extends StatefulWidget {
  final BluetoothDevice device;

  const AuthPage({super.key, required this.device});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final BtkBuoyAuthenticator _authenticator = BtkBuoyAuthenticator();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  String _status = "Esperando autenticación...";

  Future<void> _authenticate() async {
    setState(() {
      _isLoading = true;
      _status = "Autenticando...";
    });

    final password = _passwordController.text.trim();

    final success = await _authenticator.connectAndAuthenticate(
      widget.device,
      password,
    );

    setState(() {
      _isLoading = false;
      _status = success
          ? "✅ Autenticación exitosa"
          : "❌ Falló la autenticación";
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _authenticator.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Autenticación Boya")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: "Clave de la boya",
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _authenticate,
              icon: const Icon(Icons.lock_open),
              label: const Text("Autenticar"),
            ),
            const SizedBox(height: 24),
            Text(_status, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
