/**
 * An error that already carries the HTTP status and machine code the client
 * should see. Anything else becomes a generic 500.
 */
export class HttpError extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
    message: string,
  ) {
    super(message);
    this.name = "HttpError";
  }

  static unauthenticated(message: string): HttpError {
    return new HttpError(401, "unauthenticated", message);
  }

  static forbidden(message: string): HttpError {
    return new HttpError(403, "permission-denied", message);
  }

  static conflict(message: string): HttpError {
    return new HttpError(409, "conflict", message);
  }

  static unavailable(message: string): HttpError {
    return new HttpError(503, "failed-precondition", message);
  }
}
