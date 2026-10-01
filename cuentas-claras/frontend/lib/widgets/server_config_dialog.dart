import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../config/theme.dart';

class ServerConfigDialog extends StatefulWidget {
  final VoidCallback? onServerChanged;

  const ServerConfigDialog({super.key, this.onServerChanged});

  static Future<void> show(BuildContext context, {VoidCallback? onServerChanged}) {
    return showDialog(
      context: context,
      builder: (_) => ServerConfigDialog(onServerChanged: onServerChanged),
    );
  }

  @override
  State<ServerConfigDialog> createState() => _ServerConfigDialogState();
}

class _ServerConfigDialogState extends State<ServerConfigDialog> {
  late TextEditingController _controller;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Mostramos la URL base actual sin el /api final para que sea más natural de escribir
    String current = ApiConfig.baseUrl;
    if (current.endsWith('/api')) {
      current = current.substring(0, current.length - 4);
    }
    _controller = TextEditingController(text: current);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, ingresá una URL válida')),
      );
      return;
    }

    setState(() => _isSaving = true);
    await ApiConfig.setCustomBaseUrl(text);
    setState(() => _isSaving = false);

    if (mounted) {
      widget.onServerChanged?.call();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Servidor configurado: ${ApiConfig.baseUrl}'),
          backgroundColor: AppTheme.incomeColor,
        ),
      );
    }
  }

  Future<void> _reset() async {
    setState(() => _isSaving = true);
    await ApiConfig.setCustomBaseUrl(null);
    setState(() => _isSaving = false);

    if (mounted) {
      widget.onServerChanged?.call();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Servidor restablecido a los valores por defecto')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: AppTheme.surface(context),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.dns_rounded, color: AppTheme.primaryColor, size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Servidor Backend',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ingresá la URL del backend donde tenés alojada la API de Cuentas Claras (Vercel, Render, Railway, VPS o red local):',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary(context),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: 'URL del servidor',
                hintText: 'https://mi-backend.vercel.app',
                prefixIcon: const Icon(Icons.link, size: 20),
                helperText: 'No es necesario agregar /api al final',
                helperMaxLines: 2,
                filled: true,
                fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.grey300(context)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (ApiConfig.isCustomUrlSet)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, size: 14, color: AppTheme.incomeColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'URL personalizada activa',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.incomeColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        if (ApiConfig.isCustomUrlSet)
          TextButton(
            onPressed: _isSaving ? null : _reset,
            style: TextButton.styleFrom(foregroundColor: AppTheme.expenseColor),
            child: const Text('Restablecer'),
          ),
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}
