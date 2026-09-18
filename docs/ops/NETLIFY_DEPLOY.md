# Netlify – nasazení Flutter webu z GitHubu

## Co je v repu

| Soubor | Účel |
|--------|------|
| `netlify.toml` | Build command + `publish = build/web` + SPA redirect |
| `scripts/netlify_build.sh` | Instalace Flutter, zápis `assets/config.env`, `flutter build web` |

`assets/config.env` **není v Gitu** (tajné klíče). Na Netlify se vytvoří z env vars.

## Jednorázové napojení (pokud ještě není)

Produkční web: **https://admin.falconestapp.com** (Netlify site `lambent-kelpie-42b7df`), GitHub **`OmniToca/falconest`**, branch **`main`**.

1. Netlify → **Add new site** → Import from Git → GitHub → **`OmniToca/falconest`**, branch **`main`**.  
2. Build settings se načtou z `netlify.toml` (neměň Publish directory ručně na `web/` – to je zdroj, ne výstup).  
3. **Site configuration → Environment variables** (pro Production i Deploy previews):

| Key | Value |
|-----|--------|
| `SUPABASE_URL` | `https://YOUR_PROJECT.supabase.co` |
| `SUPABASE_ANON_KEY` | anon/public key z Supabase API |
| `APP_URL` | volitelně `https://your-site.netlify.app` |

4. Trigger deploy (push na `main` nebo „Clear cache and deploy site“).

## Po každém pushi na `main`

GitHub → Netlify webhook → `scripts/netlify_build.sh` → artefakt v `build/web`.

První build trvá déle (klon Flutter SDK). Další mohou využít cache adresáře.

## Typické chyby

| Symptom | Příčina | Řešení |
|---------|---------|--------|
| `ERROR: Nastav … SUPABASE_URL` | Chybí env vars | Doplň v Netlify UI, redeploy |
| `Unable to load asset: assets/config.env` | Skript nevytvořil soubor / starý build command | Ověř `netlify.toml` command = `bash scripts/netlify_build.sh` |
| Publish složka prázdná / 404 | Publish = `web` místo `build/web` | Oprav v toml / UI |
| Timeout | Cold Flutter clone | Zvyš build timeout v Netlify / nech doběhnout 2. deploy s cache |
| `Secrets scanning found secrets` + `AIza` | Firebase klientský klíč v `firebase_options.dart` / `google-services.json` | Očekávané. `SECRETS_SCAN_OMIT_PATHS` je v `netlify.toml`. |

## Ověření lokálně (stejný skript)

```bash
export SUPABASE_URL='https://xxx.supabase.co'
export SUPABASE_ANON_KEY='eyJ…'
bash scripts/netlify_build.sh
```

(nebo použij hodnoty z lokálního `assets/config.env`).
