import { logger } from '@/utils/logger';

export class AppError extends Error {
  constructor(
    message: string,
    public code: string,
    public statusCode: number = 500,
    public details?: any,
    public isOperational: boolean = true
  ) {
    super(message);
    Object.setPrototypeOf(this, AppError.prototype);
    this.name = 'AppError';
  }

  static unauthorized(message = 'Unauthorized'): AppError {
    return new AppError(message, 'UNAUTHORIZED', 401);
  }

  static forbidden(message = 'Forbidden'): AppError {
    return new AppError(message, 'FORBIDDEN', 403);
  }

  static notFound(message = 'Not found'): AppError {
    return new AppError(message, 'NOT_FOUND', 404);
  }

  static validation(message: string, details?: any): AppError {
    return new AppError(message, 'VALIDATION_ERROR', 400, details);
  }

  static conflict(message = 'Conflict'): AppError {
    return new AppError(message, 'CONFLICT', 409);
  }

  static internal(message = 'Internal server error', details?: any): AppError {
    return new AppError(message, 'INTERNAL_ERROR', 500, details, false);
  }

  static network(message = 'Network error'): AppError {
    return new AppError(message, 'NETWORK_ERROR', 0);
  }

  static timeout(message = 'Request timeout'): AppError {
    return new AppError(message, 'TIMEOUT', 408);
  }

  static rateLimited(message = 'Too many requests'): AppError {
    return new AppError(message, 'RATE_LIMITED', 429);
  }
}

export function isAppError(error: unknown): error is AppError {
  return error instanceof AppError;
}

export function isOperationalError(error: unknown): boolean {
  if (isAppError(error)) {
    return error.isOperational;
  }
  return false;
}

export function handleError(error: unknown): AppError {
  if (isAppError(error)) {
    return error;
  }

  if (error instanceof Error) {
    if (error.name === 'TypeError' && error.message.includes('Network')) {
      return AppError.network();
    }
    if (error.name === 'AbortError') {
      return AppError.timeout();
    }
    return AppError.internal(error.message);
  }

  return AppError.internal('Unknown error', error);
}

export async function withErrorHandling<T>(
  operation: () => Promise<T>,
  context?: string
): Promise<[T | null, AppError | null]> {
  try {
    const result = await operation();
    return [result, null];
  } catch (error) {
    const appError = handleError(error);
    if (context) {
      logger.error(`Operation failed: ${context}`, {}, appError);
    }
    return [null, appError];
  }
}
