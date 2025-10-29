# 🚀 Schnell-Fix für Docker/Playwright Problem (Windows 11)

**Problem:** `ENOTFOUND playwright.azureedge.net` beim Docker Build

**Lösung:** 2 Minuten ⏱️

---

## Option 1: Automatischer Fix (Empfohlen) ✅

```bash
# 1. Backup erstellen
mv Dockerfile Dockerfile.backup

# 2. Fixiertes Dockerfile verwenden
mv Dockerfile.fixed Dockerfile

# 3. Build neu starten
docker-compose down
docker-compose build --no-cache swp
docker-compose up
```

**Das war's!** 🎉

---

## Option 2: Manueller Fix (Falls Option 1 nicht klappt)

### Schritt 1: Docker Desktop DNS setzen

1. **Docker Desktop öffnen** (Rechtsklick auf Tray-Icon)
2. **Settings** → **Docker Engine**
3. JSON bearbeiten - füge hinzu:

```json
{
  "dns": ["8.8.8.8", "8.8.4.4"]
}
```

4. **Apply & Restart**

### Schritt 2: Build neu starten

```bash
docker-compose build --no-cache
```

---

## Option 3: Alternative docker-compose (Falls Option 1+2 nicht klappen)

```bash
# Nutze die DNS-fixierte Compose-Datei
docker-compose -f docker-compose.dns-fix.yml up --build
```

---

## Testen ob es funktioniert

```bash
# Nach erfolgreichem Build:
docker-compose exec swp python -c "from playwright.sync_api import sync_playwright; print('✅ Playwright funktioniert!')"
```

**Erwartete Ausgabe:** `✅ Playwright funktioniert!`

---

## Wenn nichts funktioniert 🆘

**Zeig mir diese Infos:**

```bash
# 1. Docker-Version
docker --version

# 2. WSL-Version
wsl --version

# 3. DNS-Test
docker run --rm alpine ping -c 3 8.8.8.8

# 4. Build-Log (letzte 50 Zeilen)
docker-compose build swp 2>&1 | tail -n 50
```

Dann kann ich dir spezifisch helfen!
