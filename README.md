# FalcoNest

Multi-tenant Flutter + Supabase SaaS (admin / worker / owner / HQ).

## Dokumentace

| Složka | Účel |
|--------|------|
| [`docs/ai_context/`](docs/ai_context/) | SSOT: schéma DB, slovník modulů, navigace |
| [`docs/ops/`](docs/ops/) | **Provoz:** deploy P0–P2, Edge auth, cron, Storage, RLS, troubleshooting |
| [`docs/audits/`](docs/audits/) | Audity a engineering roadmap |

Nasazení bezpečnostních oprav (2026-09): začněte **[docs/ops/DEPLOY_SECURITY_P0_P2.md](docs/ops/DEPLOY_SECURITY_P0_P2.md)**.

## Vývoj (Flutter)

```bash
flutter pub get
flutter analyze
flutter build web --release
```

Supabase migrace a Edge funkce: viz `docs/ops/` a složka `supabase/`.

## Locked business logic

Soubor `task_assignment_engine.dart` obsahuje zamčenou core logiku — **neupravovat** bez explicitního rozhodnutí.
