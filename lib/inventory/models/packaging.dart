/// Five packaging levels, biggest to smallest. Stock is always counted in pieces.
/// Each level says how many of the next smaller *switched-on* level it holds (same rule as the server).
class PackTier {
  PackTier({required this.tier, required this.name, this.enabled = false, this.per = 1, this.pieces = 1});

  final String tier; // primary | secondary | box | mini_box | piece
  String name;
  bool enabled;
  int per;
  int pieces; // pieces in one of this level (filled by Packaging.normalize)

  factory PackTier.fromJson(Map<String, dynamic> j) => PackTier(
        tier: (j['tier'] ?? 'piece') as String,
        name: (j['name'] ?? '') as String,
        enabled: (j['enabled'] ?? false) as bool,
        per: ((j['per'] ?? 1) as num).round(),
        pieces: ((j['pieces'] ?? 1) as num).round(),
      );

  Map<String, dynamic> toJson() => {'tier': tier, 'name': name, 'enabled': enabled, 'per': per};
}

class Packaging {
  static const order = ['primary', 'secondary', 'box', 'mini_box', 'piece'];
  static const defaultNames = {
    'primary': 'Case',
    'secondary': 'Carton',
    'box': 'Box',
    'mini_box': 'Mini box',
    'piece': 'Piece',
  };

  /// What the person sees in the editor for each level (the default names are only a starting point; they can rename them).
  static const labels = {
    'primary': 'Primary packaging',
    'secondary': 'Secondary packaging',
    'box': 'Boxes',
    'mini_box': 'Mini-boxes',
    'piece': 'Pieces',
  };

  static List<PackTier> normalize(List<PackTier>? input) {
    final given = {for (final t in input ?? const <PackTier>[]) t.tier: t};
    final out = [
      for (final k in order)
        PackTier(
          tier: k,
          name: (given[k]?.name.trim().isNotEmpty ?? false) ? given[k]!.name.trim() : defaultNames[k]!,
          enabled: k == 'piece' ? true : (given[k]?.enabled ?? false),
          per: k == 'piece' ? 1 : ((given[k]?.per ?? 1) < 1 ? 1 : (given[k]?.per ?? 1)),
        ),
    ];
    var acc = 1;
    for (var i = out.length - 1; i >= 0; i--) {
      if (out[i].tier != 'piece' && out[i].enabled) acc *= out[i].per;
      out[i].pieces = acc;
    }
    return out;
  }

  static List<PackTier> fromJson(dynamic j) =>
      normalize([for (final e in (j as List? ?? const [])) PackTier.fromJson(e as Map<String, dynamic>)]);

  static List<Map<String, dynamic>> toJson(List<PackTier> t) => [for (final x in normalize(t)) x.toJson()];

  /// True when at least one level above pieces is switched on.
  static bool isActive(List<PackTier> t) => normalize(t).any((x) => x.enabled && x.tier != 'piece');

  static List<PackTier> enabledTiers(List<PackTier> t) => normalize(t).where((x) => x.enabled).toList();

  /// 130 pieces -> "2 Case + 1 Carton + 10 Piece", biggest first, using only switched-on levels.
  static String breakdown(List<PackTier> t, num pieces) {
    var left = pieces.round();
    final parts = <String>[];
    for (final x in normalize(t)) {
      if (!x.enabled) continue;
      final n = left ~/ x.pieces;
      if (n > 0) parts.add('$n ${x.name}');
      left -= n * x.pieces;
    }
    return parts.isEmpty ? '0' : parts.join(' + ');
  }
}
