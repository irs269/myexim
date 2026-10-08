/// Formatage des montants sans dépendance externe : « 125 000,50 KMF ».
/// Devises qui s'affichent sans décimales.
const zeroDecimalCurrencies = {'KMF', 'XOF', 'XAF', 'MGA', 'TZS', 'UGX', 'RWF'};

String formatAmount(double value, String currency, {bool withCode = true}) {
  final decimals = zeroDecimalCurrencies.contains(currency) ? 0 : 2;
  final negative = value < 0;
  final fixed = value.abs().toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final intPart = parts[0];

  final buf = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) buf.write(' ');
    buf.write(intPart[i]);
  }
  var out = buf.toString();
  if (decimals > 0) out = '$out,${parts[1]}';
  if (negative) out = '-$out';
  return withCode ? '$out ${currencySymbol(currency)}' : out;
}

String currencySymbol(String code) => switch (code) {
      'EUR' => '€',
      'USD' => '\$',
      _ => code,
    };

String currencyFlag(String code) => switch (code) {
      'KMF' => '🇰🇲',
      'EUR' => '🇪🇺',
      'USD' => '🇺🇸',
      'MGA' => '🇲🇬',
      'TZS' => '🇹🇿',
      'KES' => '🇰🇪',
      'GHS' => '🇬🇭',
      'UGX' => '🇺🇬',
      'RWF' => '🇷🇼',
      // Francs CFA : plusieurs pays, le drapeau du pays de destination est passé à part.
      'XOF' || 'XAF' => '🌍',
      _ => '🏳️',
    };

String initials(String name) {
  final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return '?';
  if (words.length == 1) return words.first[0].toUpperCase();
  return (words[0][0] + words[1][0]).toUpperCase();
}

const _monthsFr = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];
const _monthsEn = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

String _two(int n) => n.toString().padLeft(2, '0');

/// « 8 octobre » / « October 8 », avec l'année si elle diffère de l'année en cours.
String formatDate(DateTime d, {required bool french}) {
  final month = (french ? _monthsFr : _monthsEn)[d.month - 1];
  final year = d.year == DateTime.now().year ? '' : ' ${d.year}';
  return french ? '${d.day} $month$year' : '$month ${d.day}$year';
}

String formatTime(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

String formatDateTime(DateTime d, {required bool french}) =>
    '${formatDate(d, french: french)} ${french ? 'à' : 'at'} ${formatTime(d)}';

DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

/// Taux de change avec la virgule décimale en français : « 453,22 ».
String formatRate(double value, int decimals, {required bool french}) {
  final text = value.toStringAsFixed(decimals);
  return french ? text.replaceAll('.', ',') : text;
}
