import cors from "cors";
import express from "express";
import rateLimit from "express-rate-limit";
import helmet from "helmet";

import { config } from "./config";
import { initFirebase } from "./firebase";
import { errorHandler, notFound } from "./middleware/errors";
import { syncRouter } from "./routes/sync";

export function createApp(): express.Express {
  initFirebase();

  const app = express();
  app.disable("x-powered-by");
  // Render terminates TLS in front of the service.
  app.set("trust proxy", 1);

  app.use(helmet());
  app.use(
    cors({
      origin: config.allowedOrigins.includes("*") ? true : config.allowedOrigins,
      methods: ["GET", "POST", "OPTIONS"],
      allowedHeaders: ["Authorization", "Content-Type"],
      maxAge: 86400,
    }),
  );
  app.use(express.json({ limit: "32kb" }));

  // Liveness/readiness probe used by Render and uptime monitors.
  app.get("/health", (_req, res) => {
    res.status(200).json({
      status: "ok",
      service: "fundmf-api",
      uptimeSeconds: Math.round(process.uptime()),
      timestamp: new Date().toISOString(),
    });
  });

  // The sync scans Gmail and writes Firestore, so keep manual triggers rare.
  const syncLimiter = rateLimit({
    windowMs: 60_000,
    limit: 10,
    standardHeaders: "draft-7",
    legacyHeaders: false,
    message: {
      error: "rate-limited",
      message: "Too many sync requests. Wait a minute and try again.",
    },
  });

  app.use("/api", syncLimiter, syncRouter);

  app.use(notFound);
  app.use(errorHandler);

  return app;
}
