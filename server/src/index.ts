import { createApp } from "./app";
import { config } from "./config";
import { logger } from "./logger";

const app = createApp();

const server = app.listen(config.port, "0.0.0.0", () => {
  logger.info("Fundmf API listening", { port: config.port });
});

// Render sends SIGTERM before replacing an instance; finish in-flight work.
for (const signal of ["SIGTERM", "SIGINT"] as const) {
  process.on(signal, () => {
    logger.info("Shutting down", { signal });
    server.close(() => process.exit(0));
    setTimeout(() => process.exit(1), 10_000).unref();
  });
}
