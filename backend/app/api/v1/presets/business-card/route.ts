import { NextResponse } from "next/server";
import { BusinessCardPresetsResponseSchema } from "@/lib/schemas/presets";

const BUSINESS_CARD_PRESETS = {
  emailTypes: ["Work", "Personal", "School", "Other"],
  phoneTypes: [
    "Mobile",
    "Home",
    "Work",
    "School",
    "Main",
    "Home Fax",
    "Work Fax",
    "Pager",
    "Other",
  ],
  socialProfiles: [
    "Twitter",
    "LinkedIn",
    "Facebook",
    "Instagram",
    "Weibo",
    "GitHub",
    "YouTube",
    "TikTok",
  ],
  instantMessaging: [
    "WeChat",
    "QQ",
    "Telegram",
    "WhatsApp",
    "Signal",
    "Discord",
    "Slack",
    "LINE",
  ],
  walletNetworks: [
    "Ethereum",
    "Bitcoin",
    "Solana",
    "Polygon",
    "Base",
    "Arbitrum",
    "Tron",
    "TON",
  ],
};

/**
 * Get business card presets
 * @operationId getBusinessCardPresets
 * @description Returns preset options for business card fields (email types, phone types, social profiles, instant messaging services)
 * @response BusinessCardPresetsResponseSchema
 * @tag Presets
 * @openapi
 */
export async function GET() {
  const response = BusinessCardPresetsResponseSchema.parse(BUSINESS_CARD_PRESETS);
  return NextResponse.json(response);
}
