import { AppError, isAppError, isOperationalError, handleError, withErrorHandling } from '../errors';

describe('AppError', () => {
  it('creates an error with defaults', () => {
    const error = new AppError('Something broke', 'INTERNAL_ERROR');
    expect(error.message).toBe('Something broke');
    expect(error.code).toBe('INTERNAL_ERROR');
    expect(error.statusCode).toBe(500);
    expect(error.isOperational).toBe(true);
    expect(error.name).toBe('AppError');
    expect(error).toBeInstanceOf(Error);
    expect(isAppError(error)).toBe(true);
  });

  it('sets the prototype correctly so instanceof works', () => {
    const error = AppError.unauthorized();
    expect(error instanceof AppError).toBe(true);
  });

  describe('factories', () => {
    it('unauthorized', () => {
      const error = AppError.unauthorized('Nope');
      expect(error.code).toBe('UNAUTHORIZED');
      expect(error.statusCode).toBe(401);
      expect(error.message).toBe('Nope');
    });

    it('forbidden', () => {
      const error = AppError.forbidden();
      expect(error.code).toBe('FORBIDDEN');
      expect(error.statusCode).toBe(403);
    });

    it('notFound', () => {
      const error = AppError.notFound();
      expect(error.code).toBe('NOT_FOUND');
      expect(error.statusCode).toBe(404);
    });

    it('validation', () => {
      const error = AppError.validation('Invalid', { field: 'email' });
      expect(error.code).toBe('VALIDATION_ERROR');
      expect(error.statusCode).toBe(400);
      expect(error.details).toEqual({ field: 'email' });
    });

    it('conflict', () => {
      const error = AppError.conflict();
      expect(error.code).toBe('CONFLICT');
      expect(error.statusCode).toBe(409);
    });

    it('internal is non-operational', () => {
      const error = AppError.internal('Database down', { cause: 'x' });
      expect(error.code).toBe('INTERNAL_ERROR');
      expect(error.statusCode).toBe(500);
      expect(error.isOperational).toBe(false);
      expect(error.details).toEqual({ cause: 'x' });
    });

    it('network', () => {
      const error = AppError.network();
      expect(error.code).toBe('NETWORK_ERROR');
      expect(error.statusCode).toBe(0);
    });

    it('timeout', () => {
      const error = AppError.timeout();
      expect(error.code).toBe('TIMEOUT');
      expect(error.statusCode).toBe(408);
    });

    it('rateLimited', () => {
      const error = AppError.rateLimited();
      expect(error.code).toBe('RATE_LIMITED');
      expect(error.statusCode).toBe(429);
    });
  });
});

describe('isAppError', () => {
  it('returns true for AppError instances', () => {
    expect(isAppError(AppError.notFound())).toBe(true);
  });

  it('returns false for other values', () => {
    expect(isAppError(new Error('x'))).toBe(false);
    expect(isAppError('string')).toBe(false);
    expect(isAppError(undefined)).toBe(false);
    expect(isAppError(null)).toBe(false);
  });
});

describe('isOperationalError', () => {
  it('returns true for operational errors', () => {
    expect(isOperationalError(AppError.notFound())).toBe(true);
  });

  it('returns false for non-operational errors', () => {
    expect(isOperationalError(AppError.internal())).toBe(false);
  });

  it('returns false for non-AppError values', () => {
    expect(isOperationalError(new Error('x'))).toBe(false);
  });
});

describe('handleError', () => {
  it('returns AppError instances as-is', () => {
    const original = AppError.rateLimited();
    expect(handleError(original)).toBe(original);
  });

  it('maps network TypeError to a network error', () => {
    const error = new TypeError('Network request failed');
    const handled = handleError(error);
    expect(handled.code).toBe('NETWORK_ERROR');
  });

  it('maps abort errors to a timeout error', () => {
    const error = new Error('Aborted');
    error.name = 'AbortError';
    const handled = handleError(error);
    expect(handled.code).toBe('TIMEOUT');
  });

  it('wraps other errors as internal', () => {
    const handled = handleError(new Error('boom'));
    expect(handled.code).toBe('INTERNAL_ERROR');
    expect(handled.message).toBe('boom');
    expect(handled.isOperational).toBe(false);
  });

  it('handles non-Error values', () => {
    const handled = handleError({ weird: true });
    expect(handled.code).toBe('INTERNAL_ERROR');
    expect(handled.message).toBe('Unknown error');
  });
});

describe('withErrorHandling', () => {
  it('returns the result on success', async () => {
    const [result, error] = await withErrorHandling(async () => 42);
    expect(result).toBe(42);
    expect(error).toBeNull();
  });

  it('returns a handled error on failure', async () => {
    const [result, error] = await withErrorHandling(async () => {
      throw new Error('boom');
    });
    expect(result).toBeNull();
    expect(error).not.toBeNull();
    expect(error?.code).toBe('INTERNAL_ERROR');
  });

  it('preserves AppErrors thrown by the operation', async () => {
    const [result, error] = await withErrorHandling(async () => {
      throw AppError.unauthorized();
    });
    expect(result).toBeNull();
    expect(error?.code).toBe('UNAUTHORIZED');
  });
});
