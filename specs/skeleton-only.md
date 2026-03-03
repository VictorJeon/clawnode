## Goal
Create a route-based ClawNode website skeleton only.

## Context
- Project root: `~/.openclaw/workspace-sol/clawnode/website-v2/`
- This task is strictly scaffold/skeleton. Content will be filled later by Sol.
- Must run immediately with `npm run dev`.

## Acceptance Criteria
1. Next.js App Router + Tailwind CSS + TypeScript project is initialized in this directory.
2. Routes exist and render:
   - `/`
   - `/product`
   - `/security`
   - `/process`
   - `/pricing`
3. Shared components exist:
   - `Nav`
   - `Footer`
   - `CTAButton`
   - `SectionHeading`
4. Nav includes links to all 5 pages.
5. Footer includes links/placeholders for Telegram, Twitter, Email.
6. Each route page is a minimal template and includes text/comment:
   - `TODO: Sol fills content`
7. `public/images/` directory exists.
8. Tailwind custom tokens registered and used:
   - `bg: #050505`
   - `accent: #FF6B00`
   - `text: #ffffff`
9. Fonts wired:
   - Pretendard (Korean)
   - Inter (English)
10. `npm run dev` starts without errors.

## Constraints
- Do not implement final marketing copy/content.
- Do not add extra pages beyond requested routes.
- Keep code clean and minimal.

BOLT_APPROVAL: APPROVED
