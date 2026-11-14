import 'package:flutter_test/flutter_test.dart';
import 'package:galla_pro/inventory/models/packaging.dart';

void main() {
  test('pieces multiply down the switched-on levels', () {
    final n = Packaging.normalize([
      PackTier(tier: 'primary', name: '', enabled: true, per: 4),
      PackTier(tier: 'secondary', name: '', enabled: true, per: 3),
      PackTier(tier: 'box', name: '', enabled: false, per: 99),
      PackTier(tier: 'mini_box', name: '', enabled: true, per: 10),
    ]);
    int pieces(String t) => n.firstWhere((x) => x.tier == t).pieces;
    expect(pieces('piece'), 1);
    expect(pieces('mini_box'), 10);
    expect(pieces('secondary'), 30);
    expect(pieces('primary'), 120);
    expect(Packaging.breakdown(n, 275), '2 Case + 1 Carton + 5 Piece');
  });

  test('empty input leaves only pieces switched on', () {
    final n = Packaging.normalize(null);
    expect(n.length, 5);
    expect(Packaging.isActive(n), false);
    expect(Packaging.breakdown(n, 7), '7 Piece');
  });
}
