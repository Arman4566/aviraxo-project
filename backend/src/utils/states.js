// GST state / UT codes. The app stores the state NAME; tax type (CGST+SGST vs IGST) needs the CODE.
const STATES = {
  '01': 'Jammu and Kashmir', '02': 'Himachal Pradesh', '03': 'Punjab', '04': 'Chandigarh', '05': 'Uttarakhand',
  '06': 'Haryana', '07': 'Delhi', '08': 'Rajasthan', '09': 'Uttar Pradesh', '10': 'Bihar', '11': 'Sikkim',
  '12': 'Arunachal Pradesh', '13': 'Nagaland', '14': 'Manipur', '15': 'Mizoram', '16': 'Tripura',
  '17': 'Meghalaya', '18': 'Assam', '19': 'West Bengal', '20': 'Jharkhand', '21': 'Odisha', '22': 'Chhattisgarh',
  '23': 'Madhya Pradesh', '24': 'Gujarat', '26': 'Dadra and Nagar Haveli and Daman and Diu', '27': 'Maharashtra',
  '29': 'Karnataka', '30': 'Goa', '31': 'Lakshadweep', '32': 'Kerala', '33': 'Tamil Nadu', '34': 'Puducherry',
  '35': 'Andaman and Nicobar Islands', '36': 'Telangana', '37': 'Andhra Pradesh', '38': 'Ladakh',
};
const ALIASES = {
  orissa: '21', uttaranchal: '05', pondicherry: '34', 'nct of delhi': '07', 'new delhi': '07',
  'jammu kashmir': '01', 'andaman nicobar islands': '35', 'andaman and nicobar': '35',
  'dadra and nagar haveli': '26', 'daman and diu': '26', 'dadra nagar haveli daman diu': '26',
};

const norm = (s) =>
  String(s || '').toLowerCase().replace(/&/g, ' and ').replace(/[^a-z ]/g, ' ').replace(/\s+/g, ' ').trim();

const BY_NAME = Object.fromEntries(Object.entries(STATES).map(([code, name]) => [norm(name), code]));

/** 'Uttarakhand' -> '05'. Also accepts a 2-digit code. Returns null when unknown/blank. */
function stateCodeFromName(name) {
  const raw = String(name || '').trim();
  if (/^[0-9]{2}$/.test(raw) && STATES[raw]) return raw;
  const n = norm(raw);
  if (!n) return null;
  return BY_NAME[n] || ALIASES[n] || null;
}

module.exports = { STATES, stateCodeFromName };
