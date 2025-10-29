# Docker Build Network Isolation Fix (Windows 11)

## Problem-Diagnose

Du erhältst: `ENOTFOUND playwright.azureedge.net`
**ABER:** Google DNS ist bereits konfiguriert

**Root Cause:** Docker Build-Prozess hat keinen Internet-Zugriff, NICHT DNS!

---

## Schritt 1: Problem verifizieren

### Test A: Hat Docker-Build Internet-Zugriff?

```bash
docker build --progress=plain --no-cache -t test-network -f- . << 'EOF'
FROM python:3.9
RUN apt-get update && apt-get install -y curl
RUN echo "Testing network connectivity..."
RUN curl -v https://www.google.com || echo "FAILED: No internet"
RUN ping -c 3 8.8.8.8 || echo "FAILED: No ping"
RUN curl -v https://playwright.azureedge.net || echo "FAILED: Playwright CDN blocked"
EOF
```

**Erwartete Ausgabe wenn Netzwerk funktioniert:**
```
< HTTP/2 200
...
```

**Wenn es fehlschlägt:** Build-Netzwerk ist blockiert!

---

## Schritt 2: Identifiziere die Blockade

### Mögliche Ursachen:

| Ursache | Symptom | Test |
|---------|---------|------|
| **Windows Firewall** | Nur Docker-Build blockiert | Test A schlägt fehl |
| **Antivirus** | Alle Downloads blockiert | Test A schlägt fehl |
| **Corporate Proxy** | Nur HTTPS fehlschlägt | curl http:// funktioniert |
| **Docker BuildKit Isolation** | Build isoliert vom Host | Test A schlägt fehl |
| **WSL2 Network Bug** | WSL hat kein Internet | `wsl ping 8.8.8.8` fehlschlägt |

### Test B: WSL2 Netzwerk-Check

**In PowerShell:**
```powershell
wsl ping -c 3 8.8.8.8
wsl curl https://www.google.com
```

**Wenn das fehlschlägt:** WSL2-Netzwerk-Problem!

### Test C: Docker-Container (nicht Build) Netzwerk

```bash
docker run --rm alpine ping -c 3 8.8.8.8
docker run --rm alpine wget -O- https://www.google.com
```

**Wenn das funktioniert:** Nur Build-Netzwerk ist blockiert!

---

## Lösung 1: Docker BuildKit Network Mode ändern

### Option A: BuildKit ausschalten (Legacy Builder)

**In PowerShell:**
```powershell
$env:DOCKER_BUILDKIT=0
docker-compose build --no-cache swp
```

**Oder permanent in docker-compose.yml:**
```yaml
version: '3.9'

services:
  swp:
    build:
      context: .
      network: host  # Nutze Host-Netzwerk statt BuildKit-Isolation
```

### Option B: BuildKit mit Host-Netzwerk

**Neue Datei:** `docker-compose.override.yml`

```yaml
version: '3.9'

services:
  swp:
    build:
      network: host
```

**Build:**
```bash
docker-compose build --no-cache
```

---

## Lösung 2: Windows Firewall-Regel erstellen

### PowerShell (als Administrator):

```powershell
# Erlaube Docker Desktop ausgehende Verbindungen
New-NetFirewallRule -DisplayName "Docker Desktop - Playwright Download" `
  -Direction Outbound `
  -Program "C:\Program Files\Docker\Docker\resources\bin\docker.exe" `
  -Action Allow

# Erlaube WSL ausgehende Verbindungen
New-NetFirewallRule -DisplayName "WSL2 - Outbound" `
  -Direction Outbound `
  -Program "C:\Windows\System32\wsl.exe" `
  -Action Allow

# Docker neu starten
Restart-Service docker
```

---

## Lösung 3: WSL2 Netzwerk zurücksetzen

### In PowerShell (als Administrator):

```powershell
# WSL komplett beenden
wsl --shutdown

# Windows-Netzwerk zurücksetzen
netsh winsock reset
netsh int ip reset all
ipconfig /release
ipconfig /renew
ipconfig /flushdns

# Docker Desktop beenden
Stop-Process -Name "Docker Desktop" -Force

# 30 Sekunden warten
Start-Sleep -Seconds 30

# Docker Desktop neu starten
Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"

# 1 Minute warten bis Docker läuft
Start-Sleep -Seconds 60

# Test
docker run --rm alpine ping -c 3 8.8.8.8
```

---

## Lösung 4: Playwright zur Laufzeit installieren (Umgeht Build-Problem)

### Neues Dockerfile:

```dockerfile
FROM python:3.9

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

RUN curl 'https://raw.githubusercontent.com/vishnubob/wait-for-it/master/wait-for-it.sh' -o /wait-for-it.sh && \
    chmod 755 /wait-for-it.sh

RUN --mount=type=cache,target=/var/cache/apt apt-get update && apt-get install -y gettext libqpdf-dev \
    libnss3 libnspr4 libatk1.0-0 libatk-bridge2.0-0 libcups2 libdbus-1-3 libatspi2.0-0 libxcomposite1  \
    libxdamage1 libxfixes3 libxrandr2 libgbm1 libdrm2 libxkbcommon0 libasound2 libwayland-client0

COPY requirements.txt /app
RUN --mount=type=cache,target=/root/.cache pip install --upgrade pip && pip install -r requirements.txt

# NICHT zur Build-Zeit installieren!
# RUN playwright install chromium  <-- ENTFERNT

RUN git config --system --replace-all safe.directory '*'

# Entrypoint-Script das Playwright zur Laufzeit installiert
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["python", "manage.py", "runserver", "0.0.0.0:8000"]
```

### Neue Datei: `docker-entrypoint.sh`

```bash
#!/bin/bash
set -e

# Installiere Playwright-Browser beim ersten Start
if [ ! -d "/ms-playwright" ]; then
    echo "📦 Installing Playwright browsers (first run)..."
    playwright install chromium
    echo "✅ Playwright installation complete!"
fi

# Führe den ursprünglichen Befehl aus
exec "$@"
```

**Build:**
```bash
docker-compose build --no-cache
```

**Vorteil:** Container-Netzwerk funktioniert, auch wenn Build-Netzwerk blockiert ist!

---

## Lösung 5: Proxy-Konfiguration (Falls hinter Corporate Firewall)

### Prüfe ob Proxy aktiv ist:

**PowerShell:**
```powershell
Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" | Select-Object ProxyEnable, ProxyServer
```

**Wenn ProxyEnable = 1:**

### docker-compose.yml erweitern:

```yaml
version: '3.9'

services:
  swp:
    build:
      context: .
      args:
        - HTTP_PROXY=${HTTP_PROXY}
        - HTTPS_PROXY=${HTTPS_PROXY}
        - NO_PROXY=localhost,127.0.0.1
    environment:
      - HTTP_PROXY=${HTTP_PROXY}
      - HTTPS_PROXY=${HTTPS_PROXY}
```

**Dockerfile erweitern (Anfang):**

```dockerfile
FROM python:3.9

ARG HTTP_PROXY
ARG HTTPS_PROXY

ENV HTTP_PROXY=${HTTP_PROXY}
ENV HTTPS_PROXY=${HTTPS_PROXY}
ENV NO_PROXY=localhost,127.0.0.1

# Rest bleibt gleich...
```

**In PowerShell setzen:**
```powershell
$env:HTTP_PROXY="http://proxy.firma.de:8080"
$env:HTTPS_PROXY="http://proxy.firma.de:8080"
docker-compose build
```

---

## Lösung 6: Docker Desktop Network Mode ändern

### Docker Desktop Settings:

1. **Docker Desktop öffnen**
2. **Settings** → **Resources** → **WSL Integration**
3. **Alle Distributionen aktivieren**
4. **Apply & Restart**

### Dann:

1. **Settings** → **General**
2. **✅ Use the WSL 2 based engine** (sicherstellen dass aktiv)
3. **Apply & Restart**

---

## Lösung 7: Manueller Chromium-Download (Last Resort)

### Dockerfile mit offline Installation:

```dockerfile
FROM python:3.9

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

RUN curl 'https://raw.githubusercontent.com/vishnubob/wait-for-it/master/wait-for-it.sh' -o /wait-for-it.sh && \
    chmod 755 /wait-for-it.sh

RUN --mount=type=cache,target=/var/cache/apt apt-get update && apt-get install -y gettext libqpdf-dev \
    libnss3 libnspr4 libatk1.0-0 libatk-bridge2.0-0 libcups2 libdbus-1-3 libatspi2.0-0 libxcomposite1  \
    libxdamage1 libxfixes3 libxrandr2 libgbm1 libdrm2 libxkbcommon0 libasound2 libwayland-client0

COPY requirements.txt /app
RUN --mount=type=cache,target=/root/.cache pip install --upgrade pip && pip install -r requirements.txt

# Chromium manuell von anderem Mirror laden
RUN mkdir -p /ms-playwright/chromium-1028/chrome-linux && \
    apt-get install -y wget && \
    wget --timeout=60 --tries=3 \
      https://storage.googleapis.com/chromium-browser-snapshots/Linux_x64/1028/chrome-linux.zip \
      -O /tmp/chromium.zip && \
    unzip /tmp/chromium.zip -d /ms-playwright/chromium-1028/ && \
    rm /tmp/chromium.zip

ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright

RUN git config --system --replace-all safe.directory '*'
```

---

## Schnell-Diagnose Script

**Erstelle:** `diagnose-docker-network.ps1`

```powershell
# Docker Network Diagnose für Windows 11
Write-Host "🔍 Docker Network Diagnose" -ForegroundColor Cyan
Write-Host "=========================" -ForegroundColor Cyan

# Test 1: WSL2 Internet
Write-Host "`n1️⃣ Testing WSL2 Internet..." -ForegroundColor Yellow
wsl ping -c 3 8.8.8.8
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ WSL2 Internet: OK" -ForegroundColor Green
} else {
    Write-Host "❌ WSL2 Internet: FAILED" -ForegroundColor Red
}

# Test 2: Docker Container Internet
Write-Host "`n2️⃣ Testing Docker Container Internet..." -ForegroundColor Yellow
docker run --rm alpine ping -c 3 8.8.8.8
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Docker Container Internet: OK" -ForegroundColor Green
} else {
    Write-Host "❌ Docker Container Internet: FAILED" -ForegroundColor Red
}

# Test 3: Docker Build Internet
Write-Host "`n3️⃣ Testing Docker Build Internet..." -ForegroundColor Yellow
docker build --progress=plain --no-cache -t test-net -f- . << 'EOF' 2>&1 | Select-String "Connected"
FROM alpine
RUN ping -c 3 8.8.8.8 && echo "Connected"
EOF

# Test 4: Proxy Check
Write-Host "`n4️⃣ Checking Proxy Settings..." -ForegroundColor Yellow
$proxy = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
if ($proxy.ProxyEnable -eq 1) {
    Write-Host "⚠️ Proxy aktiv: $($proxy.ProxyServer)" -ForegroundColor Yellow
} else {
    Write-Host "✅ Kein Proxy" -ForegroundColor Green
}

# Test 5: Firewall Check
Write-Host "`n5️⃣ Checking Firewall..." -ForegroundColor Yellow
$fwProfile = Get-NetFirewallProfile -Profile Domain,Public,Private | Where-Object {$_.Enabled -eq $true}
Write-Host "Aktive Firewall-Profile: $($fwProfile.Name -join ', ')"

Write-Host "`n=========================" -ForegroundColor Cyan
Write-Host "📊 Diagnose abgeschlossen" -ForegroundColor Cyan
```

**Ausführen:**
```powershell
powershell -ExecutionPolicy Bypass -File diagnose-docker-network.ps1
```

---

## Empfohlener Fix-Workflow

```bash
# 1. Problem verifizieren
docker run --rm alpine ping -c 3 playwright.azureedge.net

# Wenn das FUNKTIONIERT → Nur Build-Problem → Lösung 4 (Runtime Install)
# Wenn das FEHLSCHLÄGT → Netzwerk-Problem → Lösung 3 (WSL Reset)

# 2. Schnellster Fix: Runtime Installation
# Erstelle docker-entrypoint.sh (siehe Lösung 4)

# 3. Dockerfile anpassen (siehe Lösung 4)

# 4. Build
docker-compose build --no-cache

# 5. Test
docker-compose up
```

---

## Was ist dein genaues Problem?

**Zeig mir bitte:**

```bash
# Test 1
docker run --rm alpine ping -c 3 8.8.8.8

# Test 2
docker run --rm alpine ping -c 3 playwright.azureedge.net

# Test 3 (in PowerShell)
wsl ping -c 3 playwright.azureedge.net

# Test 4
docker --version
wsl --version
```

**Dann kann ich dir die EXAKTE Lösung geben!** 🎯
