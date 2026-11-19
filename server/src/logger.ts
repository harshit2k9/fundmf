type Level = "debug" | "info" | "warn" | "error";

function serialise(meta: unknown): unknown {
  if (meta === undefined) return undefined;
  if (meta instanceof Error) {
    return { name: meta.name, message: meta.message };
  }
  if (meta && typeof meta === "object") {
    const output: Record<string, unknown> = {};
    for (const [key, value] of Object.entries(meta as Record<string, unknown>)) {
      output[key] = value instanceof Error
        ? { name: value.name, message: value.message }
        : value;
    }
    return output;
  }
  return meta;
}

function write(level: Level, message: string, meta?: unknown): void {
  const entry: Record<string, unknown> = {
    severity: level.toUpperCase(),
    message,
    time: new Date().toISOString(),
  };
  const details = serialise(meta);
  if (details !== undefined) entry.details = details;

  const line = JSON.stringify(entry);
  if (level === "error") console.error(line);
  else if (level === "warn") console.warn(line);
  else console.log(line);
}

/** Structured logs: Render captures stdout/stderr as the service log stream. */
export const logger = {
  debug: (message: string, meta?: unknown) => write("debug", message, meta),
  info: (message: string, meta?: unknown) => write("info", message, meta),
  warn: (message: string, meta?: unknown) => write("warn", message, meta),
  error: (message: string, meta?: unknown) => write("error", message, meta),
};
