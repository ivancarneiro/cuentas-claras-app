import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CurrencyInfo {
  final String code;
  final String name;
  final String symbol;
  final IconData icon;
  final Color color;
  final int decimalDigits;

  const CurrencyInfo({
    required this.code,
    required this.name,
    required this.symbol,
    required this.icon,
    required this.color,
    this.decimalDigits = 2,
  });
}

/// Supported currencies for the app.
/// First currency (ARS) is the default for transactions.
const List<CurrencyInfo> supportedCurrencies = [
  CurrencyInfo(
    code: 'ARS',
    name: 'Peso argentino',
    symbol: r'$',
    icon: Icons.attach_money,
    color: Color(0xFF1A73E8),
    decimalDigits: 0,
  ),
  CurrencyInfo(
    code: 'USD',
    name: 'Dólar estadounidense',
    symbol: r'US$',
    icon: Icons.attach_money,
    color: Color(0xFF0D9E4E),
    decimalDigits: 2,
  ),
  CurrencyInfo(
    code: 'BRL',
    name: 'Real brasileño',
    symbol: r'R$',
    icon: Icons.monetization_on,
    color: Color(0xFF0D9E4E),
    decimalDigits: 2,
  ),
  CurrencyInfo(
    code: 'BTC',
    name: 'Bitcoin',
    symbol: r'₿',
    icon: Icons.currency_bitcoin,
    color: Color(0xFFF7931A),
    decimalDigits: 8,
  ),
  CurrencyInfo(
    code: 'ETH',
    name: 'Ethereum',
    symbol: r'ETH',
    icon: Icons.currency_bitcoin,
    color: Color(0xFF627EEA),
    decimalDigits: 6,
  ),
  CurrencyInfo(
    code: 'BNB',
    name: 'Binance Coin',
    symbol: r'BNB',
    icon: Icons.currency_bitcoin,
    color: Color(0xFFF0B90B),
    decimalDigits: 4,
  ),
  CurrencyInfo(
    code: 'PEPE',
    name: 'Pepe',
    symbol: r'PEPE',
    icon: Icons.currency_bitcoin,
    color: Color(0xFF3CB371),
    decimalDigits: 0,
  ),
  CurrencyInfo(
    code: 'USDT',
    name: 'Tether',
    symbol: r'USDT',
    icon: Icons.attach_money,
    color: Color(0xFF26A17B),
    decimalDigits: 2,
  ),
  CurrencyInfo(
    code: 'SOL',
    name: 'Solana',
    symbol: r'SOL',
    icon: Icons.currency_bitcoin,
    color: Color(0xFF9945FF),
    decimalDigits: 4,
  ),
];

/// Lookup currency info by code. Returns ARS as fallback.
CurrencyInfo getCurrencyInfo(String? code) {
  if (code == null) return supportedCurrencies[0];
  return supportedCurrencies.firstWhere(
    (c) => c.code == code.toUpperCase(),
    orElse: () => CurrencyInfo(
      code: code.toUpperCase(),
      name: code.toUpperCase(),
      symbol: code.toUpperCase(),
      icon: Icons.currency_bitcoin,
      color: const Color(0xFF7B1FA2),
      decimalDigits: 4,
    ),
  );
}

/// Format an amount with the given currency code.
/// Shows full value (no abbreviation).
String formatAmount(double amount, String? currencyCode) {
  final currency = getCurrencyInfo(currencyCode);
  final digits = currency.decimalDigits;

  // Format the number with the right decimal places
  String formatted;
  if (digits == 0) {
    formatted = NumberFormat('#,##0', 'es_AR').format(amount.round());
  } else {
    final pattern = '#,##0.${'0' * digits}';
    formatted = NumberFormat(pattern, 'es_AR').format(amount);
  }

  // Show symbol + amount
  if (currency.code == 'ARS') {
    return '\$$formatted';
  }
  return '${currency.symbol} $formatted';
}

/// Compact format for charts: e.g. "$150k", "US$ 50k"
String formatAmountCompact(double amount, String? currencyCode) {
  final currency = getCurrencyInfo(currencyCode);
  final abs = amount.abs();

  String compact;
  if (abs >= 1000000) {
    compact = '${(amount / 1000000).toStringAsFixed(1)}M';
  } else if (abs >= 1000) {
    compact = '${(amount / 1000).toStringAsFixed(0)}k';
  } else {
    return formatAmount(amount, currencyCode);
  }

  if (currency.code == 'ARS') {
    return '\$$compact';
  }
  return '${currency.symbol} $compact';
}

/// Return the list of currencies as dropdown menu items
List<DropdownMenuItem<String>> currencyDropdownItems() {
  return supportedCurrencies.map((c) => DropdownMenuItem<String>(
    value: c.code,
    child: Text('${c.symbol} ${c.code} — ${c.name}'),
  )).toList();
}
