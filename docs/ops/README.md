# Provozní dokumentace FalcoNest (`docs/ops/`)

Návody pro nasazení, konfiguraci a diagnostiku změn z auditu **bezpečnost + výkon (P0–P2, 2026-09)**.  
Architektura a schéma DB zůstávají v `docs/ai_context/` — tady je **co udělat v produkci**.

| Dokument | Kdy číst |
|----------|----------|
| [DEPLOY_SECURITY_P0_P2.md](./DEPLOY_SECURITY_P0_P2.md) | Nasazení migrací + Edge funkcí (checklist pořadí) |
| [EDGE_FUNCTIONS.md](./EDGE_FUNCTIONS.md) | Která funkce jak autentizuje, `verify_jwt`, env secrets |
| [CRON_AND_AUTOMATION.md](./CRON_AND_AUTOMATION.md) | `cron_edge_config`, service-role Bearer, idle skip dispatch |
| [STORAGE_MEDIA.md](./STORAGE_MEDIA.md) | Private bucket `falconest_media`, signed URL, cesty |
| [RLS_AND_ROLES.md](./RLS_AND_ROLES.md) | Role-split (tasks / cash / invitations / wallet RPC) |
| [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) | Typické 401/403/RLS chyby a co kontrolovat |
| [NETLIFY_DEPLOY.md](./NETLIFY_DEPLOY.md) | Netlify + GitHub: Flutter web build, env vars |

**Související SSOT:**

- `docs/ai_context/database_schema.md` – tabulky, indexy, Storage RLS  
- `docs/ai_context/slovnik_modulu.md` – providery a logické bloky  
- `docs/audits/ENGINEERING_STABILIZATION_ROADMAP.md` – širší engineering plán  

**Zásada:** Service role JWT a Stripe klíče **nikdy do Gitu**. Ukládejte je do Supabase Dashboard secrets / `cron_edge_config` (jen v DB instance).
