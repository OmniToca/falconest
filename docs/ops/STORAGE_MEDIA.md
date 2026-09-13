# Storage – private `falconest_media`

## Stav po P0

| Vlastnost | Hodnota |
|-----------|---------|
| Bucket ID | `falconest_media` |
| Public | **`false`** (migrace `20260913120000_…`) |
| Cesta uploadu | `{tenant_id}/{modul}/…` (např. `tasks/`, podpisy, účtenky) |
| RLS | První folder cesty = `my_tenant_id()::text` (nebo `is_super_admin()`) |
| Klient | `MediaService` / `SignatureService` → `createSignedUrl` |

TTL signed URL v Dartu: **10 let** (`MediaService._signedUrlTtlSeconds`) — prakticky „stabilní“ odkaz pro UI/PDF bez veřejného bucketu.

---

## Provozní důsledky

1. **Staré public URL** (`…/object/public/falconest_media/…`) po `public=false` **přestanou fungovat** v prohlížeči.  
2. Nové uploady ukládají do DB už **signed** URL.  
3. Historická data: buď  
   - jednorázový skript (service role) vygeneruje signed URL a UPDATE `media_urls` / `receipt_image_url` / metadata, nebo  
   - uživatel soubor znovu nahraje.  

### Příklad regenerace (opatrně, service role / SQL Editor s Edge)

Preferujte malý admin skript / Edge s service role:

1. Vyberte path z URL (`tenant_id/…/file.jpg`).  
2. `storage.from('falconest_media').createSignedUrl(path, ttl)`.  
3. UPDATE příslušného sloupce.

Nepoužívejte anon klienta pro cizí tenant path — RLS to zakáže.

---

## Upload z aplikace (správné použití)

```text
MediaService.upload…
  → storage.from('falconest_media').upload(path, bytes)
  → createSignedUrl(path, 10y)
  → uložit signed URL do tasks.media_urls / metadata / cash tx
```

Cesta **musí** začínat `tenantId/` aktuálního uživatele (`SupabaseService` / auth). Jinak INSERT storage RLS selže.

---

## Zobrazení v UI

Používejte `FalconestNetworkImage` (cache + `memCacheWidth/Height`) pro náhledy.  
Signed URL funguje i bez session cookie — kdo má URL, vidí soubor do expirace. Proto:

- nesdílejte signed URL veřejně zbytečně;  
- při úniku URL rotujte objekt (nový upload) nebo snižte TTL v budoucí změně kódu.

---

## Kontrola po migraci

```sql
SELECT id, name, public FROM storage.buckets WHERE id = 'falconest_media';

SELECT policyname, cmd
FROM pg_policies
WHERE schemaname = 'storage' AND tablename = 'objects'
  AND policyname LIKE 'falconest_media%';
```

Očekávané politiky: `falconest_media_insert_tenant`, `_select_tenant`, `_update_tenant`, `_delete_tenant`.

---

## QA checklist médií

- [ ] Admin: fotka k úkolu → náhled v Kanbanu / detailu  
- [ ] Worker: podpis hosta → URL v metadata, náhled  
- [ ] Worker: účtenka firemního výdaje → 40×40 náhled + dialog  
- [ ] Owner: fotky checklistu v detailu úkolu  
- [ ] Cizí tenant JWT nemůže `select` objektů s jiným `tenant_id/` prefixem  
