const router = require('express').Router();
const { query } = require('../db');
const asyncHandler = require('../utils/asyncHandler');
const { notFound } = require('../utils/errors');
const svc = require('../services/inventory');

// Out-of-stock and low-stock items with a suggested reorder quantity (feeds the dashboard badge and alert list).
router.get('/low-stock', asyncHandler(async (req, res) => res.json(await svc.lowStock({ query }, req.business.id))));

// Barcode scanner lookup: returns the item to add to the bill.
router.get('/barcode/:code', asyncHandler(async (req, res) => {
  const item = await svc.byBarcode({ query }, req.business.id, req.params.code);
  if (!item) throw notFound('No item with this barcode');
  res.json({ item });
}));

module.exports = router;
