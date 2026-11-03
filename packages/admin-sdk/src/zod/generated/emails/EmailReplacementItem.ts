// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const EmailReplacementItemSchema = z.object({
  id: z.unknown(),
  quantity: z.number(),
  name: z.string().nullable(),
  options_text: z.string().nullable(),
});

export type EmailReplacementItem = z.infer<typeof EmailReplacementItemSchema>;
