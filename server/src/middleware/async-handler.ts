import type { NextFunction, Request, RequestHandler, Response } from "express";

/**
 * Express 4 does not await async handlers, so rejected promises must be
 * forwarded to the error middleware explicitly.
 */
export function asyncHandler(
  handler: (req: Request, res: Response, next: NextFunction) => Promise<unknown>,
): RequestHandler {
  return (req, res, next) => {
    handler(req, res, next).catch(next);
  };
}
