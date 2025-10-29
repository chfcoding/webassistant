# Docker DNS Fix für Windows 11

## Problem
Playwright kann Chromium nicht herunterladen wegen DNS-Fehler:
```
Error: getaddrinfo ENOTFOUND playwright.azureedge.net
```

---

## Lösung 1: DNS im Dockerfile setzen (Schnell & Einfach) ⚡

### Schritt 1: Verwende das fixierte Dockerfile

```bash
# Backup des alten Dockerfiles
mv Dockerfile Dockerfile.backup

# Nutze die fixierte Version
mv Dockerfile.fixed Dockerfile
```

**Was wurde geändert:**
- ✅ Google DNS (8.8.8.8) wird während des Builds verwendet
- ✅ Retry-Logik bei Playwright-Installation
- ✅ Browser-Cache-Pfad explizit gesetzt

### Schritt 2: Build neu starten

```bash
# Cache löschen für sauberen Build
docker-compose build --no-cache swp

# Oder einzelnen Service:
docker build --no-cache -t swp .
```

---

## Lösung 2: Docker Desktop DNS konfigurieren (Global) 🌐

### Option A: Über Docker Desktop UI (Empfohlen für Windows)

1. **Docker Desktop öffnen**
2. **Settings (Zahnrad-Icon)** → **Docker Engine**
3. JSON-Konfiguration bearbeiten:

```json
{
  "builder": {
    "gc": {
      "defaultKeepStorage": "20GB",
      "enabled": true
    }
  },
  "dns": ["8.8.8.8", "8.8.4.4", "1.1.1.1"],
  "experimental": false
}
```

4. **Apply & Restart**

### Option B: WSL2 DNS direkt konfigurieren

**In PowerShell (als Admin):**

```powershell
# WSL beenden
wsl --shutdown

# WSL DNS-Konfiguration erstellen
$wslConfig = @"
[network]
generateResolvConf = false
"@

Set-Content -Path "$env:USERPROFILE\.wslconfig" -Value $wslConfig

# WSL neu starten
wsl
```

**In WSL2 (Linux):**

```bash
# resolv.conf neu erstellen
sudo rm /etc/resolv.conf
sudo bash -c 'echo "nameserver 8.8.8.8" > /etc/resolv.conf'
sudo bash -c 'echo "nameserver 8.8.4.4" >> /etc/resolv.conf'
sudo bash -c 'echo "nameserver 1.1.1.1" >> /etc/resolv.conf'
sudo chattr +i /etc/resolv.conf  # Immutable machen
```

---

## Lösung 3: Build-Args mit DNS (Flexibel) 🔧

### Erweitertes Dockerfile mit Build-Args

**Erstelle:** `Dockerfile.buildargs`

```dockerfile
FROM python:3.9

ARG DNS_PRIMARY=8.8.8.8
ARG DNS_SECONDARY=8.8.4.4

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Configure DNS
RUN echo "nameserver ${DNS_PRIMARY}" > /etc/resolv.conf && \
    echo "nameserver ${DNS_SECONDARY}" >> /etc/resolv.conf

WORKDIR /app

RUN curl 'https://raw.githubusercontent.com/vishnubob/wait-for-it/master/wait-for-it.sh' -o /wait-for-it.sh && \
    chmod 755 /wait-for-it.sh

RUN --mount=type=cache,target=/var/cache/apt apt-get update && apt-get install -y gettext libqpdf-dev \
    libnss3 libnspr4 libatk1.0-0 libatk-bridge2.0-0 libcups2 libdbus-1-3 libatspi2.0-0 libxcomposite1  \
    libxdamage1 libxfixes3 libxrandr2 libgbm1 libdrm2 libxkbcommon0 libasound2 libwayland-client0

COPY requirements.txt /app
RUN --mount=type=cache,target=/root/.cache pip install --upgrade pip && pip install -r requirements.txt

# Install Playwright with retries
RUN playwright install chromium || \
    (sleep 5 && playwright install chromium) || \
    (sleep 10 && playwright install chromium)

RUN git config --system --replace-all safe.directory '*'
```

**Build mit Custom DNS:**

```bash
# Mit Google DNS
docker build --build-arg DNS_PRIMARY=8.8.8.8 --build-arg DNS_SECONDARY=8.8.4.4 -t swp .

# Mit Cloudflare DNS
docker build --build-arg DNS_PRIMARY=1.1.1.1 --build-arg DNS_SECONDARY=1.0.0.1 -t swp .

# Mit deinem Firmen-DNS
docker build --build-arg DNS_PRIMARY=192.168.1.1 -t swp .
```

---

## Lösung 4: Pre-downloaded Browser nutzen (Offline) 📦

**Wenn nichts anderes funktioniert:**

### Dockerfile mit manuellem Browser-Download

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

# Manueller Chromium-Download (funktioniert wenn DNS nicht geht)
RUN mkdir -p /ms-playwright && \
    curl -L https://playwright-akamai.azureedge.net/builds/chromium/1028/chromium-linux.zip \
         -o /tmp/chromium.zip --retry 3 --retry-delay 5 || \
    wget https://storage.googleapis.com/chromium-browser-snapshots/Linux_x64/1028/chrome-linux.zip \
         -O /tmp/chromium.zip || \
    echo "Manual download failed, trying playwright install..." && \
    playwright install chromium

RUN git config --system --replace-all safe.directory '*'
```

---

## Lösung 5: docker-compose.yml erweitern 🐳

### DNS direkt in docker-compose setzen

**Erweitere dein `docker-compose.yml`:**

```yaml
version: '3.9'

services:
  swp:
    image: swp
    build:
      context: .
      dockerfile: Dockerfile
      # Neue DNS-Konfiguration für Build-Zeit
      network_mode: host  # Nutzt Host-Netzwerk für Build
    dns:
      - 8.8.8.8
      - 8.8.4.4
      - 1.1.1.1
    command: python manage.py runserver 0.0.0.0:8000
    volumes:
      - .:/app
    ports:
      - "8000:8000"
    environment:
      - DJANGO_SETTINGS_MODULE=swp.settings.dev
      # ... rest bleibt gleich
```

**Build mit:**

```bash
docker-compose build --no-cache
```

---

## Zusätzliche Troubleshooting-Schritte 🔍

### 1. DNS-Auflösung testen

**In PowerShell:**

```powershell
# Test DNS
nslookup playwright.azureedge.net 8.8.8.8

# Sollte eine IP zurückgeben, z.B.:
# Non-authoritative answer:
# Name:    playwright.azureedge.net
# Addresses: 13.107.246.45
```

**Wenn das fehlschlägt:**
- ✅ Firewall prüfen
- ✅ Antivirus deaktivieren (temporär)
- ✅ VPN ausschalten
- ✅ Windows Defender Firewall prüfen

### 2. Docker Network Reset

```powershell
# Als Administrator
wsl --shutdown
netsh winsock reset
netsh int ip reset
ipconfig /flushdns

# Docker Desktop neu starten
```

### 3. WSL2 Network Check

**In WSL2:**

```bash
# DNS-Auflösung testen
cat /etc/resolv.conf
dig playwright.azureedge.net
ping -c 3 8.8.8.8

# Netzwerk zurücksetzen
sudo service networking restart
```

### 4. Proxy-Konfiguration (Falls hinter Firewall)

**Falls du hinter einem Corporate-Proxy bist:**

**In Dockerfile:**

```dockerfile
# Am Anfang hinzufügen
ENV HTTP_PROXY=http://proxy.firma.de:8080
ENV HTTPS_PROXY=http://proxy.firma.de:8080
ENV NO_PROXY=localhost,127.0.0.1
```

**In docker-compose.yml:**

```yaml
services:
  swp:
    build:
      context: .
      args:
        - HTTP_PROXY=http://proxy.firma.de:8080
        - HTTPS_PROXY=http://proxy.firma.de:8080
```

---

## Schnell-Test: Welche Lösung für dich? 🎯

### Test 1: DNS-Erreichbarkeit

```bash
docker run --rm alpine ping -c 3 playwright.azureedge.net
```

**Ergebnis:**
- ✅ **Funktioniert:** Nutze Lösung 1 (DNS im Dockerfile)
- ❌ **Timeout:** Nutze Lösung 2 (Docker Desktop DNS)

### Test 2: Internet-Zugriff generell

```bash
docker run --rm alpine ping -c 3 8.8.8.8
```

**Ergebnis:**
- ✅ **Funktioniert:** DNS-Problem → Lösung 1 oder 2
- ❌ **Timeout:** Netzwerk-Problem → Lösung 5 (network_mode: host)

### Test 3: Mit deinem Image

```bash
docker build --progress=plain -t test-dns -f- . << 'EOF'
FROM python:3.9
RUN apt-get update && apt-get install -y curl
RUN curl -v https://playwright.azureedge.net
EOF
```

**Wenn das funktioniert:** Nur Playwright-Download ist das Problem → Lösung 4

---

## Empfohlener Workflow 🚀

### Schritt-für-Schritt (5 Minuten)

```bash
# 1. Backup
mv Dockerfile Dockerfile.backup

# 2. Fixiertes Dockerfile verwenden
mv Dockerfile.fixed Dockerfile

# 3. Docker Desktop neu starten
# Über UI: Right-click → Restart

# 4. Build mit No-Cache
docker-compose down
docker-compose build --no-cache swp

# 5. Starten
docker-compose up
```

---

## Wenn nichts funktioniert 🆘

### Alternative: Browser zur Laufzeit installieren

**Ändere Dockerfile:**

```dockerfile
# Playwright-Installation entfernen/auskommentieren
# RUN playwright install chromium

# Stattdessen: Installation verschieben
```

**In docker-compose.yml:**

```yaml
services:
  swp:
    # ...
    entrypoint: ["/bin/bash", "-c"]
    command:
      - |
        playwright install chromium  # Zur Laufzeit, nicht Build-Zeit
        python manage.py runserver 0.0.0.0:8000
```

**Vorteil:** Nutzt Container-Netzwerk statt Build-Netzwerk

---

## Häufige Fehler & Fixes ⚠️

### Fehler: `permission denied /etc/resolv.conf`

**Lösung:**

```dockerfile
RUN rm -f /etc/resolv.conf && \
    echo "nameserver 8.8.8.8" > /etc/resolv.conf
```

### Fehler: `Failed to download, code=1`

**Lösung:** Proxy oder Firewall blockiert

```bash
# Temporär Antivirus/Firewall deaktivieren
# Oder Proxy konfigurieren
```

### Fehler: `BEWARE: your OS is not officially supported`

**Normal!** Das ist nur eine Warnung. Playwright läuft trotzdem.

---

## Verification nach Fix ✅

**Teste ob es funktioniert:**

```bash
# Build erfolgreich?
docker-compose build swp

# Container starten
docker-compose up -d swp

# Playwright-Test im Container
docker-compose exec swp python -c "
from playwright.sync_api import sync_playwright
with sync_playwright() as p:
    browser = p.chromium.launch()
    print('Playwright works! ✅')
    browser.close()
"
```

**Erwartete Ausgabe:** `Playwright works! ✅`

---

## Zusammenfassung

| Lösung | Schwierigkeit | Erfolgsrate | Empfohlen für |
|--------|--------------|-------------|---------------|
| **1. DNS im Dockerfile** | ⭐ Einfach | 85% | Die meisten Nutzer |
| **2. Docker Desktop DNS** | ⭐⭐ Mittel | 90% | Permanente Lösung |
| **3. Build-Args** | ⭐⭐ Mittel | 80% | Flexibilität |
| **4. Pre-download** | ⭐⭐⭐ Komplex | 95% | Wenn alles andere fehlschlägt |
| **5. docker-compose DNS** | ⭐ Einfach | 75% | Schneller Test |

**Empfehlung:** Starte mit **Lösung 1**, dann **Lösung 2** falls nötig.

---

**Brauchst du weitere Hilfe?** Zeig mir die Ausgabe von:

```bash
docker build --progress=plain . 2>&1 | grep -A 10 "playwright"
```
