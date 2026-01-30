## Client UX policy (all agents)

**No typing or file browsing on the Lua client.** Text input and path picking are handled on the web dashboard only. See `client/UX.md` for details. Exception: Mac may support keyboard/file dialogs in future.

---

## Dashboard Redesign Agent

This agent is focused on **redesigning the web dashboard UI/UX** for this project.

Use it when you want to:
- Improve layout and information hierarchy of the dashboard pages
- Apply modern, responsive web design patterns
- Refine Tailwind CSS usage and component structure
- Enhance overall usability and aesthetics without breaking existing behavior

### Relevant skills

This agent is intended to work together with these installed skills:
- `web-design-guidelines` (from `vercel-labs/agent-skills`) – high-level web design best practices
- `ui-ux-pro-max` (from `nextlevelbuilder/ui-ux-pro-max-skill`) – practical UI/UX improvement patterns
- `baseline-ui` (from `ibelick/ui-skills`) – modern UI patterns and component ideas

### How to use in Cursor

- Open a dashboard page (e.g., `dashboard/src/app/dashboard/page.tsx` or `dashboard/src/app/dashboard/saves/page.tsx`)
- Invoke the **Dashboard Redesign Agent** from the agents menu / command palette
- Give it a concrete goal, such as:
  - “Redesign the main dashboard overview for better readability and responsive layout.”
  - “Refine the saves dashboard to make sync status and actions clearer.”
  - “Apply a more opinionated, modern visual style while keeping the existing functionality.”

