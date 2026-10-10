// India Standard Time "today" for SQL: dashboards must not flip day at 05:30 because the server runs in UTC.
const TODAY_SQL = `(now() AT TIME ZONE 'Asia/Kolkata')::date`;
const todayIST = () => new Date().toLocaleDateString('en-CA', { timeZone: 'Asia/Kolkata' }); // YYYY-MM-DD
module.exports = { TODAY_SQL, todayIST };
