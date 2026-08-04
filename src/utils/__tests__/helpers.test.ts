import {
  cn,
  formatDate,
  formatTime,
  formatDateTime,
  formatFileSize,
  truncate,
  debounce,
  throttle,
  isValidEmail,
  isValidPhone,
  isValidUsername,
  isValidPassword,
  getInitials,
  getColorForString,
  sleep,
  retry,
  omit,
  pick,
  groupBy,
  sortBy,
  uniqueBy,
  chunk,
  flatten,
  range,
  clamp,
  lerp,
} from '../helpers';

describe('cn', () => {
  it('merges conditional classes', () => {
    const isBold = false;
    expect(cn('a', isBold && 'b', 'c')).toBe('a c');
  });

  it('resolves tailwind conflicts', () => {
    expect(cn('p-2', 'p-4')).toBe('p-4');
  });
});

describe('formatDate', () => {
  it('formats a Date object containing the year', () => {
    expect(formatDate(new Date('2021-05-10T12:00:00Z'))).toMatch(/2021/);
  });

  it('formats a string date', () => {
    expect(formatDate('2021-05-10T12:00:00Z')).toMatch(/2021/);
  });
});

describe('formatTime', () => {
  it('includes the hour and minute', () => {
    expect(formatTime(new Date('2021-05-10T12:34:00Z'))).toMatch(/\d{1,2}:\d{2}/);
  });
});

describe('formatDateTime', () => {
  it('returns Just now for recent dates', () => {
    expect(formatDateTime(new Date(Date.now() - 30 * 1000))).toBe('Just now');
  });

  it('returns minutes ago', () => {
    expect(formatDateTime(new Date(Date.now() - 5 * 60 * 1000))).toBe('5m ago');
  });

  it('returns hours ago', () => {
    expect(formatDateTime(new Date(Date.now() - 2 * 60 * 60 * 1000))).toBe('2h ago');
  });

  it('returns days ago', () => {
    expect(formatDateTime(new Date(Date.now() - 3 * 24 * 60 * 60 * 1000))).toBe('3d ago');
  });

  it('falls back to a formatted date for older dates', () => {
    expect(formatDateTime(new Date('2020-01-15T12:00:00Z'))).toMatch(/2020/);
  });
});

describe('formatFileSize', () => {
  it('handles zero bytes', () => {
    expect(formatFileSize(0)).toBe('0 Bytes');
  });

  it('formats bytes', () => {
    expect(formatFileSize(500)).toBe('500 Bytes');
  });

  it('formats kilobytes', () => {
    expect(formatFileSize(1024)).toBe('1 KB');
  });

  it('formats megabytes', () => {
    expect(formatFileSize(2 * 1024 * 1024)).toBe('2 MB');
  });
});

describe('truncate', () => {
  it('leaves short strings untouched', () => {
    expect(truncate('hello', 10)).toBe('hello');
  });

  it('truncates long strings', () => {
    expect(truncate('hello world', 5)).toBe('hello...');
  });
});

describe('debounce', () => {
  beforeEach(() => {
    jest.useFakeTimers();
  });

  afterEach(() => {
    jest.useRealTimers();
  });

  it('only calls the function once after rapid invocations', () => {
    const fn = jest.fn();
    const debounced = debounce(fn, 100);
    debounced();
    debounced();
    debounced();
    jest.advanceTimersByTime(100);
    expect(fn).toHaveBeenCalledTimes(1);
  });

  it('passes through arguments', () => {
    const fn = jest.fn();
    const debounced = debounce(fn, 50);
    debounced('a', 1);
    jest.advanceTimersByTime(50);
    expect(fn).toHaveBeenCalledWith('a', 1);
  });
});

describe('throttle', () => {
  beforeEach(() => {
    jest.useFakeTimers();
  });

  afterEach(() => {
    jest.useRealTimers();
  });

  it('calls immediately and then rate-limits', () => {
    const fn = jest.fn();
    const throttled = throttle(fn, 100);
    throttled();
    throttled();
    expect(fn).toHaveBeenCalledTimes(1);
    jest.advanceTimersByTime(100);
    throttled();
    expect(fn).toHaveBeenCalledTimes(2);
  });
});

describe('validation helpers', () => {
  it('isValidEmail', () => {
    expect(isValidEmail('user@example.com')).toBe(true);
    expect(isValidEmail('not-an-email')).toBe(false);
    expect(isValidEmail('')).toBe(false);
  });

  it('isValidPhone', () => {
    expect(isValidPhone('+14155552671')).toBe(true);
    expect(isValidPhone('12345678901234567890')).toBe(false);
    expect(isValidPhone('abc123')).toBe(false);
  });

  it('isValidUsername', () => {
    expect(isValidUsername('john_doe')).toBe(true);
    expect(isValidUsername('ab')).toBe(false);
    expect(isValidUsername('john-doe')).toBe(false);
  });

  it('isValidPassword', () => {
    expect(isValidPassword('StrongPass1!')).toBe(true);
    expect(isValidPassword('weak')).toBe(false);
    expect(isValidPassword('StrongPass1')).toBe(false);
  });
});

describe('getInitials', () => {
  it('extracts two initials', () => {
    expect(getInitials('John Wick')).toBe('JW');
  });

  it('handles a single name', () => {
    expect(getInitials('Alice')).toBe('A');
  });

  it('handles empty input', () => {
    expect(getInitials('')).toBe('');
  });
});

describe('getColorForString', () => {
  it('returns an hsl color', () => {
    expect(getColorForString('crystal')).toMatch(/^hsl\(\d+, 70%, 50%\)$/);
  });

  it('is deterministic for the same input', () => {
    expect(getColorForString('crystal')).toBe(getColorForString('crystal'));
  });
});

describe('sleep', () => {
  it('resolves after the given delay', async () => {
    jest.useFakeTimers();
    const promise = sleep(50);
    jest.advanceTimersByTime(50);
    await expect(promise).resolves.toBeUndefined();
    jest.useRealTimers();
  });
});

describe('retry', () => {
  it('resolves once the function succeeds', async () => {
    const fn = jest
      .fn()
      .mockRejectedValueOnce(new Error('fail'))
      .mockRejectedValueOnce(new Error('fail'))
      .mockResolvedValue('ok');
    await expect(retry(fn, 2, 1)).resolves.toBe('ok');
    expect(fn).toHaveBeenCalledTimes(3);
  });

  it('throws after exhausting retries', async () => {
    const fn = jest.fn().mockRejectedValue(new Error('boom'));
    await expect(retry(fn, 1, 1)).rejects.toThrow('boom');
    expect(fn).toHaveBeenCalledTimes(2);
  });
});

describe('object helpers', () => {
  it('omit removes keys', () => {
    expect(omit({ a: 1, b: 2, c: 3 }, ['a', 'c'])).toEqual({ b: 2 });
  });

  it('pick selects keys', () => {
    expect(pick({ a: 1, b: 2, c: 3 }, ['a', 'c'])).toEqual({ a: 1, c: 3 });
  });

  it('pick ignores missing keys', () => {
    const source: Record<string, number> = { a: 1 };
    expect(pick(source, ['a', 'missing'])).toEqual({ a: 1 });
  });
});

describe('array helpers', () => {
  it('groupBy groups by key', () => {
    const items = [
      { group: 'a', v: 1 },
      { group: 'b', v: 2 },
      { group: 'a', v: 3 },
    ];
    expect(groupBy(items, 'group')).toEqual({
      a: [items[0], items[2]],
      b: [items[1]],
    });
  });

  it('sortBy sorts ascending and descending', () => {
    const items = [{ n: 3 }, { n: 1 }, { n: 2 }];
    expect(sortBy(items, 'n').map((i) => i.n)).toEqual([1, 2, 3]);
    expect(sortBy(items, 'n', 'desc').map((i) => i.n)).toEqual([3, 2, 1]);
  });

  it('does not mutate the input array', () => {
    const items = [{ n: 3 }, { n: 1 }];
    const copy = [...items];
    sortBy(items, 'n');
    expect(items).toEqual(copy);
  });

  it('uniqueBy removes duplicates', () => {
    expect(uniqueBy([{ id: 1 }, { id: 1 }, { id: 2 }], 'id')).toEqual([{ id: 1 }, { id: 2 }]);
  });

  it('chunk splits arrays', () => {
    expect(chunk([1, 2, 3, 4, 5], 2)).toEqual([[1, 2], [3, 4], [5]]);
  });

  it('flatten concatenates arrays', () => {
    expect(flatten([[1, 2], [3], [4, 5]])).toEqual([1, 2, 3, 4, 5]);
  });

  it('range generates a sequence', () => {
    expect(range(0, 5)).toEqual([0, 1, 2, 3, 4]);
    expect(range(0, 10, 3)).toEqual([0, 3, 6, 9]);
  });
});

describe('numeric helpers', () => {
  it('clamp bounds a value', () => {
    expect(clamp(5, 0, 10)).toBe(5);
    expect(clamp(-1, 0, 10)).toBe(0);
    expect(clamp(11, 0, 10)).toBe(10);
  });

  it('lerp interpolates', () => {
    expect(lerp(0, 10, 0.5)).toBe(5);
    expect(lerp(0, 10, 0)).toBe(0);
    expect(lerp(0, 10, 1)).toBe(10);
  });
});
