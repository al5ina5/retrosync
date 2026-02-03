export type UpgradeLimitCopy = {
  title: string;
  lead: string;
  body: string;
  limitLabel?: string | null;
};

type LimitInfo = {
  limit?: string;
  subject?: string;
};

function parseLimitInfo(message: string): LimitInfo {
  const match = message.match(/Free plan allows up to (\d+) ([^.]+)\./i);
  if (match) {
    return { limit: match[1], subject: match[2] };
  }

  if (/shared save/i.test(message)) return { subject: "shared saves" };
  if (/download/i.test(message)) return { subject: "downloads per week" };
  if (/device/i.test(message)) return { subject: "devices" };

  return {};
}

export function isUpgradeLimitError(message?: string | null): boolean {
  if (!message) return false;
  return /free plan allows up to/i.test(message) || /limit reached/i.test(message);
}

export function getUpgradeLimitCopy(message?: string | null): UpgradeLimitCopy {
  const safeMessage = message ?? "";
  const { limit, subject } = parseLimitInfo(safeMessage);
  const limitLabel = limit && subject ? `${limit} ${subject}` : null;

  let title = "Upgrade to Pro";
  if (subject?.includes("shared save")) title = "Shared Save Limit Reached";
  else if (subject?.includes("download")) title = "Download Limit Reached";
  else if (subject?.includes("device")) title = "Device Limit Reached";

  const lead = limitLabel
    ? `You have reached the free plan cap: ${limitLabel}.`
    : "You have reached a free plan limit.";

  const body = limitLabel
    ? `Upgrade to Pro to bypass the ${limitLabel} limit and keep syncing without speed bumps.`
    : "Upgrade to Pro to remove the cap and keep syncing without speed bumps.";

  return { title, lead, body, limitLabel };
}
