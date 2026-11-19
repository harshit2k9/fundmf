import type { ErrorRequestHandler, RequestHandler } from "express";

import { HttpError } from "../http-error";
import { logger } from "../logger";

export const notFound: RequestHandler = (req, res) => {
  res.status(404).json({
    error: "not-found",
    message: `No route for ${req.method} ${req.path}`,
  });
};

export const errorHandler: ErrorRequestHandler = (error, _req, res, _next) => {
  if (error instanceof HttpError) {
    res.status(error.status).json({ error: error.code, message: error.message });
    return;
  }

  logger.error("Unhandled API error", error);
  res.status(500).json({
    error: "internal",
    message: "Something went wrong on the server.",
  });
};
