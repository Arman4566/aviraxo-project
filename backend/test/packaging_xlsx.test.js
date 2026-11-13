const test = require('node:test');
const assert = require('node:assert');
const pk = require('../src/services/packaging');
const x = require('../src/utils/xlsx');
const ex = require('../src/services/exporter');

// ai.js pulls in the database stack through other services; load only the pure helper when those packages are present
let ai = null;
try { ai = require('../src/services/ai.js'); } catch { /* dependencies not installed in this environment */ }

test('packaging: pieces multiply down the enabled levels', () => {
  const n = pk.normalize([{ tier: 'primary', enabled: true, per: 4 }, { tier: 'secondary', enabled: true, per: 3 }, { tier: 'box', enabled: false, per: 99 }, { tier: 'mini_box', enabled: true, per: 10 }]);
  const by = Object.fromEntries(n.map((t) => [t.tier, t]));
  assert.equal(by.piece.pieces, 1);
  assert.equal(by.mini_box.pieces, 10);
  assert.equal(by.secondary.pieces, 30);
  assert.equal(by.primary.pieces, 120);
  assert.equal(pk.toPieces(n, 'primary', 2), 240);
  assert.equal(pk.toPieces(n, 'box', 2), null);          // switched off
  assert.equal(pk.breakdown(n, 275), '2 Case + 1 Carton + 5 Piece');
});

test('packaging: empty / junk input gives pieces only', () => {
  for (const bad of [undefined, null, 'x', [{ tier: 'nope' }], []]) {
    const n = pk.normalize(bad);
    assert.equal(n.length, 5);
    assert.ok(n.filter((t) => t.enabled).length === 1 && n[4].enabled);
    assert.equal(pk.breakdown(n, 7), '7 Piece');
  }
});

test('xlsx round trip and csv', () => {
  const rows = [['Name', 'Qty'], ['Soap "A", <b>', 3.5], ['=cmd', 0]];
  const back = x.readXlsx(x.writeXlsx([{ name: 'S', rows }]))[0].rows;
  assert.deepEqual(back, rows);
  const csv = x.toCsv(rows);
  assert.match(csv, /'=cmd/);
  assert.deepEqual(x.parseCsv(csv)[1], ['Soap "A", <b>', '3.5']);
});

test('export: P&L and stock tables, csv + xlsx render', async () => {
  const db = { query: async (sql) => {
    if (/FROM invoices i WHERE/.test(sql) && /SUM\(i.taxable_value\)/.test(sql)) return { rows: [{ sales: 100000, tax_collected: 18000, invoices: 2 }] };
    if (/SUM\(ROUND\(l.qty/.test(sql)) return { rows: [{ cogs: 60000, lines_without_cost: 0 }] };
    if (/GROUP BY category/.test(sql)) return { rows: [{ category: 'Rent', total: 10000 }] };
    if (/kind = 'income'/.test(sql)) return { rows: [{ total: 0 }] };
    if (/FROM items i/.test(sql) || /FROM \(/.test(sql) || /stock_movements/.test(sql)) return { rows: [{ id: 1, name: 'Soap', unit: 'pcs', purchase_price: 1000, selling_price: 1500, stock_qty: 10, packaging: [] }] };
    return { rows: [] };
  } };
  const pl = await ex.table(db, { id: 'b', gst_registered: true }, 'profit-loss', { from: '2026-11-01', to: '2026-11-30' });
  assert.equal(pl.columns[1], 'Amount (Rs)');
  assert.equal(pl.rows.find((r) => r[0] === 'Net profit')[1], 300);   // 1000 - 600 - 100 + 0
  const st = await ex.table(db, { id: 'b' }, 'stock', {});
  assert.deepEqual(st.rows[0], ['Soap', 'pcs', 10, 10, 100, 15]);
  assert.match(ex.render(pl, 'csv').body, /Net profit,300/);
  assert.ok(Buffer.isBuffer(ex.render(pl, 'xlsx').body));
  assert.equal(ex.render(pl, 'json'), null);
});

test('scan clean-up: case counts, totals and mismatches', { skip: !ai }, () => {
  const r = ai.cleanScan({ bill_total: 500, items: [
    { name: 'Biscuit', cases: 2, units_per_case: 12, rate: 10, gst_percent: 18, line_total: 283.2 },
    { name: 'Oil', qty: 5, rate: 100, gst_percent: 5, line_total: 900 },
    { name: '' },
  ] });
  assert.equal(r.items.length, 2);
  assert.equal(r.items[0].qty, 24);
  assert.equal(r.items[0].rate, 1000);
  assert.equal(r.items[0].needs_check, false);
  assert.equal(r.items[1].needs_check, true);
  assert.equal(r.total_mismatch, true);
});
