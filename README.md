# RetroSync

Cloud sync service for retro gaming save files across Miyoo devices.

## Project Structure

```
retrosync/
├── dashboard/          # Next.js web dashboard and API
│   ├── src/            # Source code
│   ├── prisma/         # Database schema
│   └── package.json
├── client/             # LOVE2D client app
│   ├── main.lua        # Main game file
│   ├── conf.lua        # LOVE2D config
│   ├── build/          # Build scripts
│   │   └── portmaster/
│   │       ├── build.sh
│   │       └── deploy.sh
│   └── dist/           # Build output
└── package.json        # Root package.json with commands
```

## Quick Start

### Dashboard (Server)

```bash
# Install dependencies
npm run dashboard:install

# Setup database
npm run dashboard:db:generate
npm run dashboard:db:push

# Start development server
npm run dashboard:dev
```

Dashboard will be available at http://localhost:3000

### Client (MIYO Device)

```bash
# Build PortMaster package
npm run client:build

# Deploy to device
npm run client:deploy

# Or build and deploy in one command
npm run deploy
```

## Available Commands

### Dashboard Commands
- `npm run dashboard:dev` - Start development server
- `npm run dashboard:build` - Build for production
- `npm run dashboard:start` - Start production server
- `npm run dashboard:install` - Install dependencies
- `npm run dashboard:db:generate` - Generate Prisma client
- `npm run dashboard:db:push` - Push database schema
- `npm run dashboard:db:migrate` - Run database migrations

### Client Commands
- `npm run client:build` - Build PortMaster package
- `npm run client:deploy` - Deploy to MIYO device
- `npm run client:build:deploy` - Build and deploy

### Root Commands
- `npm run dev` - Start dashboard dev server
- `npm run build` - Build both dashboard and client
- `npm run deploy` - Build and deploy client

## Usage

1. Start the dashboard: `npm run dashboard:dev`
2. Open http://localhost:3000 in your browser
3. Register/login and create a pairing code
4. Build and deploy client: `npm run deploy`
5. Launch RetroSync from Ports menu on your MIYO device
6. Enter the pairing code from the web dashboard
7. Upload save files!

## License

MIT
