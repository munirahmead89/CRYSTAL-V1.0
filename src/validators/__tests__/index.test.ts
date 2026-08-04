import {
  fullNameSchema,
  phoneSchema,
  onboardingSchema,
  profileUpdateSchema,
  messageSchema,
  chatCreateSchema,
  contactAddSchema,
  validateSchema,
  getValidationErrors,
} from '../index';

describe('fullNameSchema', () => {
  it('accepts a valid full name', () => {
    expect(fullNameSchema.safeParse("John O'Connor-Smith").success).toBe(true);
  });

  it('rejects an empty full name', () => {
    expect(fullNameSchema.safeParse('').success).toBe(false);
  });

  it('rejects a name with digits', () => {
    expect(fullNameSchema.safeParse('John 123').success).toBe(false);
  });
});

describe('phoneSchema', () => {
  it('accepts a valid phone number', () => {
    expect(phoneSchema.safeParse('+14155552671').success).toBe(true);
  });

  it('rejects an invalid phone number', () => {
    expect(phoneSchema.safeParse('abc123').success).toBe(false);
  });
});

describe('onboardingSchema', () => {
  it('accepts valid onboarding data', () => {
    const result = onboardingSchema.safeParse({
      fullName: 'John Doe',
      phone: '+14155552671',
    });
    expect(result.success).toBe(true);
  });

  it('accepts onboarding data with bio', () => {
    const result = onboardingSchema.safeParse({
      fullName: 'John Doe',
      phone: '+14155552671',
      bio: 'Hello world',
    });
    expect(result.success).toBe(true);
  });

  it('rejects missing full name', () => {
    const result = onboardingSchema.safeParse({
      phone: '+14155552671',
    });
    expect(result.success).toBe(false);
  });

  it('rejects missing phone', () => {
    const result = onboardingSchema.safeParse({
      fullName: 'John Doe',
    });
    expect(result.success).toBe(false);
  });
});

describe('profileUpdateSchema', () => {
  it('accepts a partial update', () => {
    expect(profileUpdateSchema.safeParse({ bio: 'Hello world' }).success).toBe(true);
  });

  it('rejects an invalid avatar URL', () => {
    expect(profileUpdateSchema.safeParse({ avatarUrl: 'not-a-url' }).success).toBe(false);
  });
});

describe('messageSchema', () => {
  it('accepts a valid text message', () => {
    const result = messageSchema.safeParse({ content: 'Hello', messageType: 'text' });
    expect(result.success).toBe(true);
  });

  it('rejects an empty message', () => {
    const result = messageSchema.safeParse({ content: '', messageType: 'text' });
    expect(result.success).toBe(false);
  });

  it('rejects an invalid message type', () => {
    const result = messageSchema.safeParse({ content: 'Hello', messageType: 'carrier-pigeon' });
    expect(result.success).toBe(false);
  });
});

describe('chatCreateSchema', () => {
  it('accepts a direct chat without a name', () => {
    const result = chatCreateSchema.safeParse({
      participantIds: ['00000000-0000-4000-8000-000000000000'],
      isGroup: false,
    });
    expect(result.success).toBe(true);
  });

  it('requires a name for group chats', () => {
    const result = chatCreateSchema.safeParse({
      participantIds: ['00000000-0000-4000-8000-000000000000'],
      isGroup: true,
    });
    expect(result.success).toBe(false);
  });

  it('accepts a group chat with a name', () => {
    const result = chatCreateSchema.safeParse({
      participantIds: ['00000000-0000-4000-8000-000000000000'],
      isGroup: true,
      name: 'Family',
    });
    expect(result.success).toBe(true);
  });

  it('rejects an empty participant list', () => {
    const result = chatCreateSchema.safeParse({ participantIds: [], isGroup: false });
    expect(result.success).toBe(false);
  });
});

describe('contactAddSchema', () => {
  it('accepts a valid contact', () => {
    const result = contactAddSchema.safeParse({ contactId: '00000000-0000-4000-8000-000000000000' });
    expect(result.success).toBe(true);
  });

  it('rejects an invalid contact ID', () => {
    const result = contactAddSchema.safeParse({ contactId: 'nope' });
    expect(result.success).toBe(false);
  });
});

describe('validateSchema', () => {
  it('returns data on success', () => {
    const result = validateSchema(onboardingSchema, { fullName: 'John Doe', phone: '+14155552671' });
    expect(result.success).toBe(true);
    if (!result.success) {
      throw new Error('Expected success');
    }
    expect(result.data.fullName).toBe('John Doe');
  });

  it('returns errors on failure', () => {
    const result = validateSchema(onboardingSchema, { fullName: 'John Doe' });
    expect(result.success).toBe(false);
  });
});

describe('getValidationErrors', () => {
  it('maps issues to path-message records', () => {
    const result = onboardingSchema.safeParse({
      fullName: '',
      phone: 'abc',
    });
    if (result.success) {
      throw new Error('Expected validation to fail');
    }
    const errors = getValidationErrors(result.error);
    expect(errors).toHaveProperty('fullName');
    expect(errors).toHaveProperty('phone');
  });

  it('flattens nested paths with dots', () => {
    const result = chatCreateSchema.safeParse({ participantIds: [], isGroup: true });
    if (result.success) {
      throw new Error('Expected validation to fail');
    }
    const errors = getValidationErrors(result.error);
    expect(errors['participantIds']).toBeTruthy();
  });
});
