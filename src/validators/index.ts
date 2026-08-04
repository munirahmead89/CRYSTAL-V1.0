import { z } from 'zod';

export const fullNameSchema = z
  .string()
  .min(1, 'Full name is required')
  .max(100, 'Full name must be at most 100 characters')
  .regex(/^[\p{L}\p{M}\s\-'.]+$/u, 'Full name can only contain letters, spaces, hyphens, apostrophes, and periods');

export const phoneSchema = z.string().regex(/^\+?[1-9]\d{1,14}$/, 'Invalid phone number format');

export const onboardingSchema = z.object({
  fullName: fullNameSchema,
  phone: phoneSchema,
  bio: z.string().max(500, 'Bio must be at most 500 characters').optional(),
  avatarUrl: z.string().url('Invalid avatar URL').optional(),
});

export const profileUpdateSchema = z.object({
  fullName: fullNameSchema.optional(),
  bio: z.string().max(500, 'Bio must be at most 500 characters').optional(),
  avatarUrl: z.string().url('Invalid avatar URL').optional(),
});

export const messageSchema = z.object({
  content: z.string().min(1, 'Message cannot be empty').max(4000, 'Message is too long'),
  messageType: z.enum(['text', 'image', 'video', 'audio', 'file', 'location', 'contact', 'sticker']),
  replyToId: z.string().uuid().optional(),
  attachments: z.array(z.any()).optional(),
});

export const chatCreateSchema = z.object({
  participantIds: z.array(z.string().uuid()).min(1, 'At least one participant is required'),
  isGroup: z.boolean(),
  name: z.string().min(1, 'Group name is required').max(100, 'Group name is too long').optional(),
  avatarUrl: z.string().url('Invalid avatar URL').optional(),
}).refine((data) => !data.isGroup || data.name, {
  message: 'Group name is required for group chats',
  path: ['name'],
});

export const contactAddSchema = z.object({
  contactId: z.string().uuid('Invalid contact ID'),
  displayName: z.string().max(100, 'Display name is too long').optional(),
});

export const settingsSchema = z.object({
  theme: z.enum(['light', 'dark', 'system']),
  notificationsEnabled: z.boolean(),
  soundEnabled: z.boolean(),
  vibrationEnabled: z.boolean(),
  autoDownloadMedia: z.boolean(),
  language: z.string().min(2).max(5),
  biometricEnabled: z.boolean(),
  pinEnabled: z.boolean(),
});

export type OnboardingInput = z.infer<typeof onboardingSchema>;
export type ProfileUpdateInput = z.infer<typeof profileUpdateSchema>;
export type MessageInput = z.infer<typeof messageSchema>;
export type ChatCreateInput = z.infer<typeof chatCreateSchema>;
export type ContactAddInput = z.infer<typeof contactAddSchema>;
export type SettingsInput = z.infer<typeof settingsSchema>;

export function validateSchema<T>(schema: z.ZodSchema<T>, data: unknown): { success: true; data: T } | { success: false; errors: z.ZodError } {
  const result = schema.safeParse(data);
  if (result.success) {
    return { success: true, data: result.data };
  }
  return { success: false, errors: result.error };
}

export function getValidationErrors(error: z.ZodError): Record<string, string> {
  const errors: Record<string, string> = {};
  error.issues.forEach((issue) => {
    const path = issue.path.join('.');
    errors[path] = issue.message;
  });
  return errors;
}