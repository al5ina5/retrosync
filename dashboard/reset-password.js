const { PrismaClient } = require('@prisma/client');
const bcrypt = require('bcryptjs');

const prisma = new PrismaClient();

async function main() {
  const email = 'Test1@me.com';
  const newPassword = 'test@test.com';

  const passwordHash = await bcrypt.hash(newPassword, 10);

  const user = await prisma.user.update({
    where: { email },
    data: { passwordHash },
  });

  console.log(`Password reset for user: ${user.email}`);
}

main()
  .catch(console.error)
  .finally(() => prisma.$disconnect());
