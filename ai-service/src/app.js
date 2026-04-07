const express      = require("express");
const helmet       = require("helmet");
const cors         = require("cors");
const morgan       = require("morgan");
const config       = require("./config");
const routes       = require("./api/routes");
const errorHandler = require("./api/middleware/errorHandler");
const rateLimiter  = require("./api/middleware/rateLimiter");

const app = express();

app.use(helmet());

app.use(cors({
  origin(origin, cb) {
    if (!origin) return cb(null, true);
    const allowed = config.cors.allowedOrigins.some((o) => origin.startsWith(o));
    allowed ? cb(null, true) : cb(new Error(`CORS: origin '${origin}' not allowed`));
  },
  methods: ["GET", "POST"],
}));

app.use(express.json({ limit: "20kb" }));

if (config.env !== "test") {
  app.use(morgan("short"));
}

app.use(rateLimiter);
app.use(routes);

app.use((req, res) => {
  res.status(404).json({ success: false, error: "Route not found." });
});

app.use(errorHandler);

module.exports = app;
