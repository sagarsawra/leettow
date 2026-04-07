/**
 * asyncHandler.js â€” Forwards async rejections to Express next(err).
 */
const asyncHandler = (fn) => (req, res, next) =>
  Promise.resolve(fn(req, res, next)).catch(next);
module.exports = asyncHandler;
