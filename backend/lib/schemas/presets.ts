import { z } from "zod";

export const BusinessCardPresetsResponseSchema = z.object({
  emailTypes: z
    .array(z.string())
    .describe("Preset email type labels"),
  phoneTypes: z
    .array(z.string())
    .describe("Preset phone type labels"),
  socialProfiles: z
    .array(z.string())
    .describe("Preset social media platform names"),
  instantMessaging: z
    .array(z.string())
    .describe("Preset instant messaging service names"),
  walletNetworks: z
    .array(z.string())
    .describe("Preset wallet network names"),
});
