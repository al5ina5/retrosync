/**
 * One-off: print User rows (email, subscriptionTier, stripeCustomerId).
 * Run from dashboard: node -r dotenv/config scripts/check-upgrade-status.js
 * Or with env already set: node scripts/check-upgrade-status.js
 */
const path = require("path");
const fs = require("fs");

// Load .env from dashboard root if present (so DATABASE_URL is set)
const envPath = path.resolve(__dirname, "..", ".env");
if (fs.existsSync(envPath)) {
  const content = fs.readFileSync(envPath, "utf8");
  for (const line of content.split("\n")) {
    const m = line.match(/^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$/);
    if (m) process.env[m[1]] = m[2].replace(/^["']|["']$/g, "").trim();
  }
}

const { PrismaClient } = require("@prisma/client");
const prisma = new PrismaClient();

async function main() {
  const users = await prisma.user.findMany({
    select: {
      id: true,
      email: true,
      subscriptionTier: true,
      stripeCustomerId: true,
    },
    orderBy: { createdAt: "desc" },
  });
  console.log(JSON.stringify(users, null, 2));
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
