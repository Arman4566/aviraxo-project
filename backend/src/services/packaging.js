// Five packaging levels, biggest to smallest. Stock is always kept in the smallest sellable unit (pieces);
// each level only says "how many of the next smaller level it holds", so a carton can be entered as 2 cartons and still count in pieces.
const TIERS = ['primary', 'secondary', 'box', 'mini_box', 'piece'];
const DEFAULT_NAMES = { primary: 'Case', secondary: 'Carton', box: 'Box', mini_box: 'Mini box', piece: 'Piece' };

/** Accepts [{tier, name?, enabled?, per?}] in any order, returns a clean list in tier order with `pieces` filled in. */
function normalize(input) {
  const given = new Map();
  for (const t of Array.isArray(input) ? input : []) {
    if (t && TIERS.includes(t.tier)) given.set(t.tier, t);
  }
  const out = TIERS.map((tier) => {
    const g = given.get(tier) || {};
    const per = tier === 'piece' ? 1 : Math.max(1, Math.min(100000, Math.floor(Number(g.per) || 1)));
    return {
      tier, name: String(g.name || DEFAULT_NAMES[tier]).trim().slice(0, 20) || DEFAULT_NAMES[tier],
      enabled: tier === 'piece' ? true : g.enabled === true, per,
    };
  });
  // `per` = how many of the next smaller ENABLED level one unit holds, so pieces multiply down the chain.
  let acc = 1;
  for (let i = out.length - 1; i >= 0; i--) {
    if (out[i].tier !== 'piece' && out[i].enabled) acc *= out[i].per;
    out[i].pieces = acc;
  }
  // a disabled tier still gets `pieces` for reference, but callers should only offer enabled ones
  return out;
}

/** Pieces for a quantity entered in a tier ("3 cartons"); null when that tier is not enabled. */
function toPieces(packaging, tier, qty) {
  const t = normalize(packaging).find((x) => x.tier === tier);
  if (!t || !t.enabled) return null;
  return Math.round(Number(qty) * t.pieces * 1000) / 1000;
}

/** 130 pieces -> "2 Carton + 1 Box + 10 Piece" using only enabled tiers, biggest first. */
function breakdown(packaging, pieces) {
  let left = Math.round(Number(pieces) || 0);
  const parts = [];
  for (const t of normalize(packaging)) {
    if (!t.enabled && t.tier !== 'piece') continue;
    const n = Math.floor(left / t.pieces);
    if (n > 0) parts.push(`${n} ${t.name}`);
    left -= n * t.pieces;
  }
  return parts.join(' + ') || '0';
}

module.exports = { TIERS, DEFAULT_NAMES, normalize, toPieces, breakdown };
