import { generateId } from '../id';

describe('generateId', () => {
  it('returns a non-empty string', () => {
    expect(typeof generateId()).toBe('string');
    expect(generateId().length).toBeGreaterThan(0);
  });

  it('returns the same UUID while crypto is mocked', () => {
    const first = generateId();
    const second = generateId();
    expect(first).toBe('00000000-0000-4000-8000-000000000000');
    expect(second).toBe(first);
  });
});
