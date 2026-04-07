/**
 * respond.js â€” Normalised API response helpers.
 */
function ok(res, data, statusCode = 200) {
  return res.status(statusCode).json({ success: true, data });
}

function fail(res, message, statusCode = 500) {
  return res.status(statusCode).json({ success: false, error: message });
}

module.exports = { ok, fail };
