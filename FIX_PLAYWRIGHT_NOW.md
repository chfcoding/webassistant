# ⚡ Sofort-Fix für Playwright Problem (kein DNS)

Da du bereits Google DNS nutzt, ist es ein **Netzwerk-Isolation-Problem** im Docker Build.

---

## 🚀 Schnellste Lösung (3 Befehle, 5 Minuten)

### Lösung: Browser zur Laufzeit installieren, nicht beim Build

```bash
# 1. Backup
cp Dockerfile Dockerfile.backup-original

# 2. Nutze das netzwerk-fixierte Dockerfile
cp Dockerfile.network-fix Dockerfile

# 3. docker-entrypoint.sh ist bereits vorhanden

# 4. Build mit network=host
docker-compose -f docker-compose.network-fix.yml build --no-cache

# 5. Starten
docker-compose -f docker-compose.network-fix.yml up
```

**Was passiert:**
- ✅ Playwright wird NICHT beim Build installiert (umgeht Build-Netzwerk-Problem)
- ✅ Installation erfolgt beim ersten Container-Start (Container-Netzwerk funktioniert)
- ✅ Browser werden in Volume gespeichert (nur einmal download)

---

## 🧪 Wenn das nicht funktioniert: Diagnose

### Test 1: Hat Container-Netzwerk Internet?

```bash
docker run --rm alpine ping -c 3 8.8.8.8
docker run --rm alpine ping -c 3 playwright.azureedge.net
```

**Wenn das funktioniert:** Runtime-Installation wird funktionieren! ✅

**Wenn das fehlschlägt:** Grundlegendes Netzwerk-Problem → siehe unten

---

## 🔧 Alternative: BuildKit ausschalten

Falls Runtime-Installation auch nicht klappt:

```powershell
# In PowerShell
$env:DOCKER_BUILDKIT=0
docker-compose build --no-cache swp
```

---

## 🆘 Grundlegendes Netzwerk-Problem?

### Wenn auch Container kein Internet haben:

**In PowerShell (als Admin):**

```powershell
# WSL komplett zurücksetzen
wsl --shutdown

# Netzwerk zurücksetzen
netsh winsock reset
netsh int ip reset
ipconfig /flushdns

# Docker Desktop neu starten
Stop-Process -Name "Docker Desktop" -Force
Start-Sleep -Seconds 10
Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"

# 1 Minute warten
Start-Sleep -Seconds 60

# Erneut testen
docker run --rm alpine ping -c 3 8.8.8.8
```

---

## 📊 Was ist jetzt anders?

### Altes Dockerfile (funktioniert NICHT):
```dockerfile
RUN playwright install chromium  # Läuft im Build → Netzwerk-Problem
```

### Neues Dockerfile (funktioniert):
```dockerfile
# playwright install wird NICHT beim Build ausgeführt
COPY docker-entrypoint.sh /docker-entrypoint.sh
ENTRYPOINT ["/docker-entrypoint.sh"]
# → Installation erfolgt beim ersten Start → Container-Netzwerk OK
```

---

## ✅ Erfolgreich wenn du siehst:

```
🚀 Starting SWP WebAssistant...
📦 Installing Playwright Chromium (first run)...
   This may take a few minutes...
✅ Playwright installation successful!
🎯 Starting application...
```

---

## 💡 Bonus: Wenn du Windows Defender hast

**Temporär testen:**

```powershell
# Als Admin
Set-MpPreference -DisableRealtimeMonitoring $true

# Docker build testen
docker-compose build

# Defender wieder aktivieren
Set-MpPreference -DisableRealtimeMonitoring $false
```

**Wenn das hilft:** Defender blockiert Docker → Ausnahme erstellen

---

**Probier die Schnellste Lösung aus und sag mir was passiert!** 🎯
