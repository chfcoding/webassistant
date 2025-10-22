# Django 5.1 Upgrade - Quick Start Guide

**Geschätzte Dauer:** 30-60 Minuten (ohne Tests)

---

## Voraussetzungen ✅

- [ ] Python 3.10 oder höher installiert
- [ ] Git-Repository sauber (alle Änderungen committed)
- [ ] Backup-Möglichkeit für Datenbank
- [ ] Test-Umgebung verfügbar

---

## Schritt-für-Schritt Anleitung

### 1. Python-Version prüfen

```bash
python3 --version
# Muss >= 3.10 sein
```

**Falls zu alt:**
```bash
# Ubuntu/Debian
sudo apt install python3.11 python3.11-venv

# macOS
brew install python@3.11
```

---

### 2. Feature-Branch erstellen

```bash
cd /home/user/webassistant
git checkout -b django5-upgrade
git add -A
git commit -m "Pre-Django 5 upgrade snapshot"
```

---

### 3. Code-Änderungen automatisch anwenden

```bash
python scripts/apply_code_changes.py
```

**Was wird geändert:**
- ❌ `USE_L10N` wird entfernt
- ➕ `DEFAULT_AUTO_FIELD` wird hinzugefügt
- ➕ `SECRET_KEY` Validierung wird hinzugefügt

**Prüfen:**
```bash
git diff swp/settings/base.py
```

---

### 4. Upgrade durchführen

**Option A: Automatisiertes Upgrade (empfohlen)**
```bash
# Setzt DATABASE_NAME falls noch nicht vorhanden
export DATABASE_NAME=swp

bash scripts/upgrade_django5.sh
```

**Option B: Manuelles Upgrade**
```bash
# Backup erstellen
pg_dump swp > backup_$(date +%Y%m%d).sql

# Requirements aktualisieren
pip install --upgrade -r requirements_django5.txt

# Django Checks
python manage.py check
python manage.py migrate
python manage.py test
```

---

### 5. Tests durchführen

```bash
# Vollständige Test-Suite
bash scripts/test_django5.sh

# Oder einzeln:
python manage.py test --parallel
python manage.py check --deploy
```

---

### 6. Manuelle Verifikation

**Backend:**
```bash
python manage.py runserver
# Öffne: http://localhost:8000/admin/
```

**Prüfe:**
- [ ] Admin-Login funktioniert
- [ ] Filter-Sidebar sieht korrekt aus
- [ ] API-Endpoints erreichbar: `/api/publication/`

**Frontend:**
```bash
npm run watch  # In separatem Terminal
# Öffne: http://localhost:8000/
```

**Celery:**
```bash
celery -A swp worker -l info
# Prüfe: Keine Fehler beim Start
```

---

## Bei Problemen 🔧

### Problem: Tests schlagen fehl

```bash
# Detaillierte Fehlerausgabe
python manage.py test --verbosity=2 --failfast

# Einzelnen Test ausführen
python manage.py test swp.tests.test_scraper.ScraperTestCase.test_form_save_minimal
```

### Problem: Import-Fehler

```bash
# Virtual Environment neu aufsetzen
python3.11 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements_django5.txt
```

### Problem: Migrations schlagen fehl

```bash
# Migrations zurücksetzen (nur Dev!)
python manage.py migrate --fake swp zero
python manage.py migrate
```

### Rollback durchführen

```bash
bash scripts/rollback_django5.sh
```

---

## Nach erfolgreichem Upgrade ✅

### 1. Änderungen committen

```bash
git add .
git commit -m "Upgrade to Django 5.1.4

- Updated Django from 4.1.13 to 5.1.4
- Updated all dependencies
- Removed deprecated USE_L10N setting
- Added DEFAULT_AUTO_FIELD configuration
- Added SECRET_KEY validation

Breaking changes:
- Python 3.10+ now required
- psycopg3 instead of psycopg2 (optional)

Tests: All passing
"
```

### 2. Requirements freezen

```bash
pip freeze > requirements_frozen_django5.txt
# Optional: In requirements.txt übernehmen
```

### 3. Dokumentation aktualisieren

Aktualisiere:
- `README.md` - Python-Version-Anforderung
- `docker-compose.yml` - Python-Image
- `.github/workflows/*.yml` - CI/CD Python-Version
- Deployment-Dokumentation

### 4. Team informieren

```markdown
## Django 5.1 Upgrade abgeschlossen ✅

**Änderungen:**
- Django 4.1.13 → 5.1.4
- Python 3.10+ jetzt erforderlich
- Alle Dependencies aktualisiert

**Breaking Changes:**
- Python 3.8 wird nicht mehr unterstützt
- `USE_L10N` setting wurde entfernt (jetzt immer aktiv)

**Nächste Schritte:**
- [ ] Staging-Deployment
- [ ] Performance-Tests
- [ ] Production-Deployment (Termin: TBD)
```

---

## Staging/Production Deployment

### Vorbereitung

```bash
# 1. Wartungsmodus aktivieren (wenn vorhanden)
# 2. Backup erstellen
ssh production "pg_dump swp > /backups/pre_django5_$(date +%Y%m%d).sql"

# 3. Code deployen
git push origin django5-upgrade
# Merge in main/master
```

### Deployment-Befehle

```bash
# Auf Server:
cd /var/www/webassistant

# Virtual Environment aktivieren
source venv/bin/activate

# Dependencies aktualisieren
pip install --upgrade -r requirements.txt

# Django Checks
python manage.py check --deploy

# Migrations
python manage.py migrate

# Static Files
python manage.py collectstatic --noinput

# Search Index
python manage.py search_index --rebuild -f

# Services neustarten
sudo systemctl restart uwsgi
sudo systemctl restart celery
sudo systemctl restart celery-beat
```

### Post-Deployment Monitoring

```bash
# Logs überwachen (erste 10 Minuten)
tail -f /var/log/uwsgi/app/swp.log
tail -f /var/log/celery/worker.log

# Health-Check
curl http://localhost:8000/api/publication/ -I
# Erwartung: HTTP 200

# Error-Rate in Sentry prüfen
# Performance-Metriken vergleichen
```

---

## Performance-Verbesserungen 🚀

Django 5.1 bietet automatisch:
- ✅ 10-20% schnellere ORM-Queries
- ✅ Verbesserte Query-Optimierung
- ✅ Besseres Caching
- ✅ Effizientere Database-Connections

**Messe Verbesserung:**
```bash
# Vor Upgrade
python manage.py test --timing > timings_before.txt

# Nach Upgrade
python manage.py test --timing > timings_after.txt

# Vergleichen
diff timings_before.txt timings_after.txt
```

---

## Nützliche Befehle

```bash
# Django-Version prüfen
python -c "import django; print(django.VERSION)"

# Alle installierten Packages
pip list

# Dependency-Tree anzeigen
pip install pipdeptree
pipdeptree -p Django

# Migrations-Status
python manage.py showmigrations

# SQL für Migration anzeigen
python manage.py sqlmigrate swp 0001

# Django Shell mit allen Models
python manage.py shell_plus
```

---

## Checkliste für Go-Live ✅

### Pre-Deployment
- [ ] Alle Tests grün
- [ ] Code-Review abgeschlossen
- [ ] Staging erfolgreich getestet
- [ ] Backup-Strategie bestätigt
- [ ] Rollback-Plan dokumentiert
- [ ] Team informiert über Deployment-Fenster
- [ ] Monitoring/Alerting scharf geschaltet

### Deployment
- [ ] Wartungsmodus aktivieren
- [ ] Database-Backup erstellen
- [ ] Code deployen
- [ ] Dependencies installieren
- [ ] Migrations ausführen
- [ ] Static Files sammeln
- [ ] Search Index rebuilden
- [ ] Services neustarten
- [ ] Smoke-Tests durchführen
- [ ] Wartungsmodus deaktivieren

### Post-Deployment (erste 24h)
- [ ] Error-Rate überwachen
- [ ] Performance-Metriken prüfen
- [ ] User-Feedback sammeln
- [ ] Logs auf Anomalien prüfen
- [ ] Celery-Tasks verifizieren
- [ ] API-Response-Times checken

---

## Support & Resources

**Dokumentation:**
- 📖 [DJANGO_5_UPGRADE_PLAN.md](DJANGO_5_UPGRADE_PLAN.md) - Vollständiger Plan
- 🔧 [scripts/](scripts/) - Helper-Scripts

**Hilfe bei Problemen:**
1. Prüfe `DJANGO_5_UPGRADE_PLAN.md` → Abschnitt 9 (Häufige Probleme)
2. Django 5.1 Release Notes: https://docs.djangoproject.com/en/5.1/releases/5.1/
3. Django Upgrade Guide: https://docs.djangoproject.com/en/5.1/howto/upgrade-version/

**Scripts:**
- `apply_code_changes.py` - Automatische Code-Anpassungen
- `upgrade_django5.sh` - Vollständiger Upgrade-Prozess
- `rollback_django5.sh` - Rollback bei Problemen
- `test_django5.sh` - Umfassende Test-Suite

---

**Viel Erfolg! 🚀**
