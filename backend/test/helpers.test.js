const test = require('node:test');
const assert = require('node:assert/strict');
const { stateCodeFromName } = require('../src/utils/states');
const { normalizeMode, isCreditMethod, termDays } = require('../src/utils/payments');
const { bind } = require('./helpers/psqlClient');

test('state names map to GST codes', () => {
  assert.equal(stateCodeFromName('Uttarakhand'), '05');
  assert.equal(stateCodeFromName('  maharashtra '), '27');
  assert.equal(stateCodeFromName('Jammu & Kashmir'), '01');
  assert.equal(stateCodeFromName('Orissa'), '21');
  assert.equal(stateCodeFromName('27'), '27');
  assert.equal(stateCodeFromName('Atlantis'), null);
  assert.equal(stateCodeFromName(''), null);
  assert.equal(stateCodeFromName(undefined), null);
});

test('payment method text from the app', () => {
  assert.equal(normalizeMode('Cash'), 'cash');
  assert.equal(normalizeMode('UPI'), 'upi');
  assert.equal(normalizeMode('Bank Transfer'), 'bank');
  assert.equal(normalizeMode('Credit (Pay Later)'), 'other');
  assert.equal(isCreditMethod('Credit (Pay Later)'), true);
  assert.equal(isCreditMethod('Credit'), true);
  assert.equal(isCreditMethod('Cash'), false);
  assert.equal(termDays('Net 15'), 15);
  assert.equal(termDays('Immediate'), 0);
});

test('test client quotes parameters safely', () => {
  assert.equal(bind('SELECT $1, $2, $3, $4', ["O'Brien", -5, null, [1, 2]]), "SELECT 'O''Brien', (-5), NULL, ARRAY[(1),(2)]");
});
