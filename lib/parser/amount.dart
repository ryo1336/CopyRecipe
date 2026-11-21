/// 分量の文字列と人数の換算。
///
/// 分量は原文のまま保存しているので、表示するときに文字列の中の数値だけを
/// 掛け算し直す。「少々」「適量」など数値のない分量はそのまま残す。
library;

/// 分量の中の数値。前から順に試すので、長い書き方を先に置く
final _quantity = RegExp(
  r'(\d+)\s*[と・]\s*(\d+)/(\d+)' // 1と1/2、1・1/2
  r'|(\d+)/(\d+)' // 1/2
  r'|(\d+)分の(\d+)' // 3分の1
  r'|(\d{1,3}(?:,\d{3})+|\d+(?:\.\d+)?)' // 1,000、1.5
  r'|([½⅓⅔¼¾])',
);

const _unicodeFractions = {
  '½': 1 / 2,
  '⅓': 1 / 3,
  '⅔': 2 / 3,
  '¼': 1 / 4,
  '¾': 3 / 4,
};

/// 重さ・容量の単位。これらは分数ではなく小数で書く（「150g」「7.5ml」）
final _metricUnit = RegExp(
  r'^\s*(?:kg|mg|g|ml|mL|cc|l|L|ℓ|グラム|キロ|ミリリットル|リットル)',
);

/// 掛け算してはいけない数値（割合や温度）
final _notQuantity = RegExp(r'^\s*(?:%|％|℃|°|度)');

/// [amount] の中の数値すべてに [factor] を掛けた文字列を返す。
///
/// - 「大さじ1と1/2」のような帯分数、「2〜3個」のような範囲も扱う
/// - 大さじ・個数などは「1と1/2」のような分数、g・ml などは小数で書く
/// - [factor] が 1 なら原文をそのまま返す
String scaleAmount(String amount, double factor) {
  if (factor == 1) return amount;
  return amount.replaceAllMapped(_quantity, (m) {
    final rest = amount.substring(m.end);
    if (_notQuantity.hasMatch(rest)) return m[0]!;
    final value = _valueOf(m);
    if (value == null) return m[0]!;
    return formatQuantity(value * factor, metric: _metricUnit.hasMatch(rest));
  });
}

double? _valueOf(Match m) {
  int n(int group) => int.parse(m[group]!);
  if (m[1] != null) {
    return n(3) == 0 ? null : n(1) + n(2) / n(3);
  }
  if (m[4] != null) return n(5) == 0 ? null : n(4) / n(5);
  if (m[6] != null) return n(6) == 0 ? null : n(7) / n(6);
  if (m[8] != null) return double.parse(m[8]!.replaceAll(',', ''));
  return _unicodeFractions[m[9]];
}

/// 換算した数値を、分量として読みやすい形にする。
///
/// - [metric]（g・ml など）: 10 以上は整数、それ未満は小数第1位まで
/// - それ以外: 1/2・1/3・1/4・1/6・1/8 などに近ければ「1と1/2」のような分数、
///   どれにも近くなければ小数第1位まで
String formatQuantity(double value, {required bool metric}) {
  if (metric) {
    return value >= 10 ? '${value.round()}' : _decimal(value);
  }
  var whole = value.floor();
  final fraction = value - whole;
  const tolerance = 0.02;
  if (fraction < tolerance) return '$whole';
  if (fraction > 1 - tolerance) return '${whole + 1}';
  for (final d in const [2, 3, 4, 6, 8]) {
    final n = (fraction * d).round();
    if (n > 0 && n < d && (fraction - n / d).abs() < tolerance) {
      return whole == 0 ? '$n/$d' : '$wholeと$n/$d';
    }
  }
  return _decimal(value);
}

String _decimal(double value) {
  final text = value.toStringAsFixed(1);
  return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
}

final _singleServings = RegExp(r'^\s*(\d+)\s*人(?:分|前)\s*$');

/// 「2人分」「4人前」から人数を取り出す。「2〜3人分」のような範囲や、
/// 人数として読めないものは null（そのときは倍率で換算する）
int? parseServingsCount(String? servings) {
  if (servings == null) return null;
  final m = _singleServings.firstMatch(servings);
  if (m == null) return null;
  final count = int.parse(m[1]!);
  return count == 0 ? null : count;
}

/// 倍率の表示（「1/2」「1.5」「2」）
String formatFactor(double factor) => factor == 0.5 ? '1/2' : _decimal(factor);

/// 換算後の人数の表示。
///
/// - 人数が読めるとき: 「3人分」
/// - 読めないとき: 元の表記に倍率を添える（「2〜3人分 ×2」「×2」）
/// - 換算していないときは元の表記のまま（なければ null）
String? scaledServingsLabel(String? servings, double factor) {
  if (factor == 1) return servings;
  final count = parseServingsCount(servings);
  if (count != null) return '${(count * factor).round()}人分';
  final times = '×${formatFactor(factor)}';
  return servings == null ? times : '$servings $times';
}
