# Django 5.1 Upgrade Plan für SWP WebAssistant

**Stand:** 2025-01-22
**Ziel:** Migration von Django 4.1.13 → Django 5.1.x
**Geschätzter Aufwand:** 2-3 Entwicklungstage + 1 Woche Testing
**Risiko:** 🟡 Medium (hauptsächlich Third-Party Dependencies)

---

## 📋 Inhaltsverzeichnis

1. [Pre-Migration Checks](#1-pre-migration-checks)
2. [Breaking Changes Overview](#2-breaking-changes-overview)
3. [Code-Änderungen pro Bereich](#3-code-änderungen-pro-bereich)
4. [Dependency Updates](#4-dependency-updates)
5. [Migration Script](#5-migration-script)
6. [Testing-Strategie](#6-testing-strategie)
7. [Rollback-Plan](#7-rollback-plan)
8. [Post-Migration Tasks](#8-post-migration-tasks)

---

## 1. Pre-Migration Checks ✅

### 1.1 Umgebungs-Vorbereitung

```bash
# Backup erstellen
cd /home/user/webassistant
git checkout -b django5-upgrade
pg_dump swp > backup_before_django5.sql

# Test-Branch erstellen
git add -A
git commit -m "Pre-Django 5 upgrade snapshot"
```

### 1.2 Kompatibilitäts-Check

**Deine aktuelle Konfiguration:**
- Python: 3.8 (❌ **MUSS auf 3.10+ aktualisiert werden!**)
- PostgreSQL: 13+ (✅ Kompatibel)
- Elasticsearch: 8.4.3 (✅ Kompatibel)
- Redis: 4 (✅ Kompatibel)

**Aktion:**
```bash
# Python 3.11 installieren (empfohlen für beste Performance)
python --version  # Muss >= 3.10 sein
```

---

## 2. Breaking Changes Overview 🚨

### 2.1 Django 4.1 → 4.2 (Intermediate Step)

| Breaking Change | Dein Code betroffen? | Aktion |
|----------------|---------------------|--------|
| `USE_L10N` deprecated | ✅ Ja (`base.py:110`) | Entfernen |
| `index_together` → `indexes` | ❌ Nein | Keine |
| `use_natural_foreign_keys` | ❌ Nein | Keine |

### 2.2 Django 4.2 → 5.0 (Major Changes)

| Breaking Change | Dein Code betroffen? | Aktion |
|----------------|---------------------|--------|
| Python 3.10+ required | ✅ Ja | Python upgraden |
| `DEFAULT_AUTO_FIELD` empfohlen | ✅ Fehlt | Hinzufügen |
| PostgreSQL 12 dropped | ✅ Check Server | Verifizieren |
| `django.contrib.gis` changes | ❌ Nein | Keine |

### 2.3 Django 5.0 → 5.1 (Latest)

| Breaking Change | Dein Code betroffen? | Aktion |
|----------------|---------------------|--------|
| Admin HTML structure changes | ⚠️ Ggf. CSS | Check Admin-Styles |
| `collapse.js` removed | ❌ Nein | Keine |
| Test assertion changes | ⚠️ Minimal | Tests anpassen |

---

## 3. Code-Änderungen pro Bereich 🔧

### 3.1 Settings (`swp/settings/base.py`)

#### Änderung 1: `USE_L10N` entfernen (Zeile 110)

**Vorher:**
```python
USE_I18N = True
USE_L10N = True  # ❌ Deprecated in Django 4.0, entfernt in 5.0
LANGUAGE_CODE = 'de'
```

**Nachher:**
```python
USE_I18N = True
# USE_L10N ist jetzt immer True und die Einstellung wurde entfernt
LANGUAGE_CODE = 'de'
```

#### Änderung 2: `DEFAULT_AUTO_FIELD` hinzufügen

**Nach Zeile 90 hinzufügen:**
```python
WSGI_APPLICATION = 'swp.wsgi.application'

# Default primary key field type
# https://docs.djangoproject.com/en/5.1/ref/settings/#default-auto-field
DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'
```

**Warum?** Django 5.0+ empfiehlt BigAutoField für zukunftssichere PKs.

#### Änderung 3: Security-Verbesserungen

**Nach Zeile 19 hinzufügen:**
```python
SECRET_KEY = env('SECRET_KEY')

# Validierung für Production
if not SECRET_KEY or SECRET_KEY == 'changeme':
    from django.core.exceptions import ImproperlyConfigured
    raise ImproperlyConfigured(
        'SECRET_KEY must be set in environment variables!'
    )
```

### 3.2 Models (Keine Breaking Changes!)

✅ **Gute Nachricht:** Deine Models sind bereits kompatibel!

- ✅ Alle ForeignKeys haben `on_delete` definiert
- ✅ Keine deprecated Model-APIs
- ✅ Custom QuerySets verwenden moderne Syntax

**Optional - Aber empfohlen:** Explizite Meta-Klasse für Primary Keys

**Datei:** Alle Models ohne explizites `id` Field

**Beispiel für `swp/models/publication.py`:**
```python
class Publication(UpdateModel):
    """
    Single published article.
    """

    # Explizit definieren (optional, aber Best Practice):
    # id = models.BigAutoField(primary_key=True)

    thinktank = models.ForeignKey(...)
    # ... rest bleibt gleich
```

### 3.3 URLs (Bereits kompatibel!)

✅ **Keine Änderungen nötig!** Du verwendest bereits `path()` statt deprecated `url()`.

**Datei:** `swp/urls.py`
```python
# ✅ Gut - path() ist die moderne API
from django.urls import include, path

urlpatterns = [
    path('admin/', admin.site.urls),
    # ...
]
```

### 3.4 Admin (Potenzielle CSS-Anpassungen)

⚠️ **Check erforderlich:** Admin HTML-Struktur hat sich geändert.

**Betroffene Dateien:**
- `swp/admin/*.py` (alle Admin-Klassen)
- Eigene Admin-Templates in `swp/templates/admin/` (falls vorhanden)
- Admin CSS-Overrides

**Test nach Upgrade:**
```bash
# Nach dem Upgrade im Browser testen:
# 1. Admin-Panel öffnen
# 2. Filter-Sidebar prüfen (jetzt <nav> statt <div>)
# 3. Fieldsets mit collapse prüfen (jetzt <details>/<summary>)
```

### 3.5 Tests (Minimale Anpassungen)

**Betroffene Methoden:**
- `assertURLEqual()`
- `assertInHTML()`

**Beispiel-Anpassung in `swp/tests/*.py`:**

**Vorher:**
```python
self.assertURLEqual(url1, url2, msg_prefix='URLs do not match')
# Output: "URLs do not matchURL1 != URL2"
```

**Nachher:**
```python
self.assertURLEqual(url1, url2, msg_prefix='URLs do not match')
# Output: "URLs do not match: URL1 != URL2"  (mit ": " Trenner)
```

**Aktion:** Tests laufen lassen und nur bei Fehlern anpassen.

---

## 4. Dependency Updates 📦

### 4.1 Python Requirements

**Datei:** `requirements.txt`

**Vorher:**
```txt
Django==4.1.13
djangorestframework==3.12.2
celery==5.0.5
django-elasticsearch-dsl==8.0
django-filter==2.4.0
psycopg2==2.8.6
redis==3.5.3
```

**Nachher:**
```txt
Django==5.1.4
djangorestframework==3.15.2
celery==5.4.0
django-elasticsearch-dsl==8.0  # Kompatibel mit Django 5.1
django-filter==24.3
psycopg[binary]==3.2.3  # psycopg2 → psycopg3
redis==5.2.0
```

### 4.2 Kompatibilitäts-Matrix

| Package | Django 4.1 | Django 5.1 | Status |
|---------|-----------|-----------|---------|
| **djangorestframework** 3.12.2 | ✅ | ❌ | Upgrade auf 3.15.2 |
| **djangorestframework** 3.15.2 | ✅ | ✅ | ✅ Kompatibel |
| **celery** 5.0.5 | ✅ | ⚠️ | Upgrade empfohlen |
| **celery** 5.4.0 | ✅ | ✅ | ✅ Kompatibel |
| **django-elasticsearch-dsl** 8.0 | ✅ | ✅ | ✅ Kompatibel (Django >= 4.2) |
| **django-filter** 2.4.0 | ✅ | ❌ | Upgrade auf 24.3 |
| **psycopg2** 2.8.6 | ✅ | ⚠️ | psycopg3 empfohlen |
| **redis** 3.5.3 | ✅ | ⚠️ | Upgrade empfohlen |

### 4.3 Breaking Changes in Dependencies

#### **psycopg2 → psycopg3**

**Vorher (`settings/base.py`):**
```python
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'HOST': env('DATABASE_HOST', '127.0.0.1'),
        'NAME': env('DATABASE_NAME', 'swp'),
        'USER': env('DATABASE_USER', 'swp'),
        'PASSWORD': env('DATABASE_PASSWORD', 'swp'),
    },
}
```

**Nachher (psycopg3 - optional):**
```python
# Wenn du psycopg3 nutzen willst:
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',  # Bleibt gleich!
        # Alle anderen Einstellungen bleiben gleich
        # psycopg3 ist kompatibel mit psycopg2 Config
    },
}
```

**Empfehlung:** Starte mit `psycopg[binary]==3.2.3` (Drop-in Replacement).

---

## 5. Migration Script 🚀

### 5.1 Stufenweise Migration (Empfohlen!)

**Strategie:** Nicht direkt 4.1 → 5.1, sondern:
1. Django 4.1 → **4.2** (LTS)
2. Django 4.2 → **5.0**
3. Django 5.0 → **5.1**

**Warum?** Reduziert Fehlerrisiko und erlaubt schrittweises Testing.

### 5.2 Automatisiertes Upgrade-Script

**Datei:** `scripts/upgrade_django5.sh` (erstellen)

```bash
#!/bin/bash
set -e  # Exit on error

echo "🚀 Starting Django 5.1 Upgrade..."

# Farben für Output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 1. Pre-Checks
echo -e "${YELLOW}Step 1/8: Pre-flight checks...${NC}"

# Python Version Check
PYTHON_VERSION=$(python3 --version | cut -d' ' -f2 | cut -d'.' -f1,2)
if (( $(echo "$PYTHON_VERSION < 3.10" | bc -l) )); then
    echo -e "${RED}ERROR: Python 3.10+ required, found $PYTHON_VERSION${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Python version OK: $PYTHON_VERSION${NC}"

# Git Status Check
if [[ -n $(git status -s) ]]; then
    echo -e "${RED}ERROR: Uncommitted changes detected. Commit or stash first.${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Git working directory clean${NC}"

# 2. Backup Database
echo -e "${YELLOW}Step 2/8: Creating database backup...${NC}"
BACKUP_FILE="backup_django5_$(date +%Y%m%d_%H%M%S).sql"
pg_dump $DATABASE_NAME > "$BACKUP_FILE"
echo -e "${GREEN}✓ Database backed up to $BACKUP_FILE${NC}"

# 3. Update Django to 4.2 (intermediate)
echo -e "${YELLOW}Step 3/8: Upgrading to Django 4.2 (LTS)...${NC}"
pip install Django==4.2.17
python manage.py check
python manage.py migrate
python manage.py test --parallel --failfast
echo -e "${GREEN}✓ Django 4.2 upgrade successful${NC}"

# 4. Update Django to 5.0
echo -e "${YELLOW}Step 4/8: Upgrading to Django 5.0...${NC}"
pip install Django==5.0.10
python manage.py check
python manage.py migrate
python manage.py test --parallel --failfast
echo -e "${GREEN}✓ Django 5.0 upgrade successful${NC}"

# 5. Update Django to 5.1 + all dependencies
echo -e "${YELLOW}Step 5/8: Upgrading to Django 5.1 + dependencies...${NC}"
pip install --upgrade -r requirements.txt
echo -e "${GREEN}✓ All packages updated${NC}"

# 6. Run Django checks
echo -e "${YELLOW}Step 6/8: Running Django system checks...${NC}"
python manage.py check --deploy
echo -e "${GREEN}✓ System checks passed${NC}"

# 7. Migrate database
echo -e "${YELLOW}Step 7/8: Running migrations...${NC}"
python manage.py makemigrations --check --dry-run
python manage.py migrate
echo -e "${GREEN}✓ Migrations completed${NC}"

# 8. Run test suite
echo -e "${YELLOW}Step 8/8: Running full test suite...${NC}"
coverage run manage.py test --parallel
coverage report
echo -e "${GREEN}✓ All tests passed${NC}"

# Rebuild search index
echo -e "${YELLOW}Rebuilding Elasticsearch index...${NC}"
python manage.py search_index --rebuild -f

# Collect static files
echo -e "${YELLOW}Collecting static files...${NC}"
python manage.py collectstatic --noinput

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
echo -e "${GREEN}🎉 Django 5.1 Upgrade completed successfully!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
echo ""
echo "Next steps:"
echo "1. Test application manually"
echo "2. Check admin interface styling"
echo "3. Test Celery tasks"
echo "4. Monitor error logs"
echo ""
echo "Backup location: $BACKUP_FILE"
```

**Ausführbar machen:**
```bash
chmod +x scripts/upgrade_django5.sh
```

### 5.3 Code-Änderungen Script

**Datei:** `scripts/apply_code_changes.py`

```python
#!/usr/bin/env python
"""
Automatische Code-Änderungen für Django 5.1 Upgrade
"""
import re
from pathlib import Path

def remove_use_l10n(settings_file):
    """Entfernt USE_L10N aus settings"""
    content = settings_file.read_text()

    # Zeile mit USE_L10N entfernen
    content = re.sub(r'^USE_L10N = .*\n', '', content, flags=re.MULTILINE)

    settings_file.write_text(content)
    print(f"✓ Removed USE_L10N from {settings_file}")

def add_default_auto_field(settings_file):
    """Fügt DEFAULT_AUTO_FIELD hinzu"""
    content = settings_file.read_text()

    # Prüfen ob schon vorhanden
    if 'DEFAULT_AUTO_FIELD' in content:
        print(f"✓ DEFAULT_AUTO_FIELD already present in {settings_file}")
        return

    # Nach WSGI_APPLICATION suchen und danach einfügen
    wsgi_pattern = r"(WSGI_APPLICATION = ['\"].*['\"])"
    replacement = r"\1\n\n# Default primary key field type\nDEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'"

    content = re.sub(wsgi_pattern, replacement, content)
    settings_file.write_text(content)
    print(f"✓ Added DEFAULT_AUTO_FIELD to {settings_file}")

def add_secret_key_validation(settings_file):
    """Fügt SECRET_KEY Validierung hinzu"""
    content = settings_file.read_text()

    if 'ImproperlyConfigured' in content and 'SECRET_KEY must be set' in content:
        print(f"✓ SECRET_KEY validation already present in {settings_file}")
        return

    # Nach SECRET_KEY = env('SECRET_KEY') suchen
    pattern = r"(SECRET_KEY = env\('SECRET_KEY'\))"
    replacement = """\\1

# Validate SECRET_KEY is properly set
if not SECRET_KEY or SECRET_KEY == 'changeme':
    from django.core.exceptions import ImproperlyConfigured
    raise ImproperlyConfigured('SECRET_KEY must be set in environment variables!')"""

    content = re.sub(pattern, replacement, content)
    settings_file.write_text(content)
    print(f"✓ Added SECRET_KEY validation to {settings_file}")

def main():
    base_dir = Path(__file__).parent.parent
    settings_base = base_dir / 'swp' / 'settings' / 'base.py'

    print("Starting code modifications for Django 5.1...")
    print("=" * 50)

    if settings_base.exists():
        remove_use_l10n(settings_base)
        add_default_auto_field(settings_base)
        add_secret_key_validation(settings_base)
    else:
        print(f"ERROR: {settings_base} not found!")
        return 1

    print("=" * 50)
    print("✓ All code changes applied successfully!")
    print("\nPlease review the changes with: git diff")
    return 0

if __name__ == '__main__':
    exit(main())
```

**Ausführen:**
```bash
python scripts/apply_code_changes.py
git diff  # Änderungen überprüfen
```

---

## 6. Testing-Strategie 🧪

### 6.1 Automatisierte Tests

**Test-Matrix:**

| Test-Typ | Command | Geschätzter Aufwand |
|----------|---------|-------------------|
| Unit Tests | `python manage.py test` | 5-10 min |
| Integration Tests | `python manage.py test --tag=integration` | 10-20 min |
| API Tests | `python manage.py test swp.api.tests` | 5 min |
| Migration Tests | `python manage.py migrate --fake-initial` | 2 min |
| Coverage Report | `coverage run && coverage report` | 10 min |

**Full Test Suite:**
```bash
#!/bin/bash
# scripts/test_django5.sh

set -e

echo "🧪 Running Django 5.1 Test Suite..."

# 1. Unit Tests
echo "1. Running unit tests..."
python manage.py test --parallel --keepdb

# 2. Check for migration issues
echo "2. Checking migrations..."
python manage.py makemigrations --check --dry-run

# 3. Check deployment readiness
echo "3. Running deployment checks..."
python manage.py check --deploy --settings=swp.settings.production

# 4. Test Celery tasks
echo "4. Testing Celery tasks..."
celery -A swp inspect ping

# 5. Test Elasticsearch connection
echo "5. Testing Elasticsearch..."
python manage.py search_index --create --populate

# 6. Coverage Report
echo "6. Generating coverage report..."
coverage run --source='.' manage.py test
coverage report --skip-covered
coverage html

echo "✅ All tests passed!"
```

### 6.2 Manuelle Test-Checkliste

#### Backend Tests
- [ ] Admin-Login funktioniert
- [ ] User-Authentifizierung OK
- [ ] API-Endpoints erreichbar
  - [ ] `/api/publication/`
  - [ ] `/api/monitor/`
  - [ ] `/api/thinktank/`
  - [ ] `/api/scraper/`
- [ ] Suche funktioniert (Elasticsearch)
- [ ] Publication-Listen laden
- [ ] RIS-Export funktioniert

#### Celery Tasks
- [ ] Scraper-Tasks starten
- [ ] Monitor-Schedule läuft
- [ ] Pollux-Tasks ausführbar
- [ ] Error-Report-Emails
- [ ] Embedding-Processing

#### Frontend Tests
- [ ] Homepage lädt
- [ ] Navigation funktioniert
- [ ] Search funktioniert
- [ ] Monitor-Ansichten OK
- [ ] Thinktank-Ansichten OK
- [ ] Publication-Details anzeigen

#### Admin Interface
- [ ] Layout korrekt (keine CSS-Fehler)
- [ ] Filter-Sidebar funktional
- [ ] Fieldsets mit collapse OK
- [ ] Inline-Formulare funktionieren

### 6.3 Performance-Tests

**Vor Upgrade:**
```bash
# Baseline erstellen
python manage.py test --timing
ab -n 100 -c 10 http://localhost:8000/api/publication/
```

**Nach Upgrade:**
```bash
# Performance vergleichen
python manage.py test --timing
ab -n 100 -c 10 http://localhost:8000/api/publication/
```

**Erwartung:** Django 5.x ist ~10-20% schneller bei ORM-Queries.

---

## 7. Rollback-Plan 🔄

### 7.1 Schneller Rollback (< 5 Minuten)

**Bei kritischen Problemen in Production:**

```bash
#!/bin/bash
# scripts/rollback_django5.sh

set -e

echo "🚨 Rolling back to Django 4.1.13..."

# 1. Code zurücksetzen
git reset --hard HEAD~1  # oder spezifischer commit

# 2. Dependencies zurücksetzen
pip install Django==4.1.13 djangorestframework==3.12.2 celery==5.0.5

# 3. Database wiederherstellen (falls Migrations gelaufen)
psql $DATABASE_NAME < backup_before_django5.sql

# 4. Server neustarten
sudo systemctl restart uwsgi
sudo systemctl restart celery

echo "✅ Rollback completed"
```

### 7.2 Checkpoint-System

**Vor jeder kritischen Phase:**

```bash
# Checkpoint 1: Nach Django 4.2
git tag django-4.2-checkpoint
pg_dump swp > checkpoint_4.2.sql

# Checkpoint 2: Nach Django 5.0
git tag django-5.0-checkpoint
pg_dump swp > checkpoint_5.0.sql

# Checkpoint 3: Nach Django 5.1
git tag django-5.1-success
pg_dump swp > checkpoint_5.1.sql
```

**Rollback zu Checkpoint:**
```bash
git checkout django-4.2-checkpoint
psql swp < checkpoint_4.2.sql
pip install -r requirements.txt
```

---

## 8. Post-Migration Tasks 📝

### 8.1 Immediate (Tag 1)

- [ ] Update `requirements.txt` committen
- [ ] Code-Änderungen committen
- [ ] CI/CD Pipeline testen
- [ ] Deployment-Dokumentation aktualisieren
- [ ] Team informieren über Änderungen

### 8.2 Short-term (Woche 1)

- [ ] Error-Logs monitoren (Sentry)
- [ ] Performance-Metriken vergleichen
- [ ] User-Feedback sammeln
- [ ] Admin-Interface Style-Fixes (falls nötig)
- [ ] Deployment auf Staging durchführen

### 8.3 Medium-term (Monat 1)

- [ ] Production-Deployment planen
- [ ] Load-Testing durchführen
- [ ] Backup-Strategie verifizieren
- [ ] Dokumentation vervollständigen
- [ ] Python 3.11+ in Production deployen

---

## 9. Häufige Probleme & Lösungen 🔧

### Problem 1: Tests schlagen fehl mit `AssertionError`

**Symptom:**
```
AssertionError: URLs do not matchExpected != Actual
```

**Lösung:**
```python
# Alte Test-Syntax anpassen
# Vorher:
self.assertURLEqual(url1, url2, msg_prefix='URLs do not match')

# Nachher (kein Code-Change nötig, nur Erwartung anpassen):
# Django 5.1 fügt automatisch ": " nach msg_prefix ein
```

### Problem 2: `psycopg2` Import-Fehler

**Symptom:**
```
ImportError: cannot import name 'connection' from 'psycopg2'
```

**Lösung:**
```bash
# Option 1: Bei psycopg2 bleiben
pip install psycopg2-binary==2.9.9

# Option 2: Auf psycopg3 upgraden
pip uninstall psycopg2 psycopg2-binary
pip install psycopg[binary]==3.2.3
```

### Problem 3: Admin CSS kaputt

**Symptom:**
Filter-Sidebar sieht falsch aus

**Lösung:**
```bash
# Statische Files neu sammeln
python manage.py collectstatic --clear --noinput

# Browser-Cache leeren
# Oder CSS-Overrides in eigenen Templates anpassen
```

### Problem 4: Celery Tasks starten nicht

**Symptom:**
```
kombu.exceptions.VersionMismatch: Redis transport requires redis-py versions >= 4.2.0
```

**Lösung:**
```bash
pip install redis==5.2.0 celery==5.4.0
sudo systemctl restart celery
```

---

## 10. Timeline & Milestones 📅

### Woche 1: Vorbereitung
- **Tag 1-2:** Python 3.11 auf Dev/Staging installieren
- **Tag 3:** Dependencies-Audit durchführen
- **Tag 4:** Code-Änderungen in Feature-Branch
- **Tag 5:** Lokale Tests durchführen

### Woche 2: Staging-Migration
- **Tag 1:** Staging-Upgrade durchführen
- **Tag 2-3:** Intensive Staging-Tests
- **Tag 4:** Performance-Tests
- **Tag 5:** Rollback-Test auf Staging

### Woche 3: Production-Vorbereitung
- **Tag 1-2:** Production-Runbook erstellen
- **Tag 3:** Team-Briefing
- **Tag 4:** Backup-Strategie testen
- **Tag 5:** Go/No-Go Meeting

### Woche 4: Production-Rollout
- **Tag 1:** Production-Migration (Wartungsfenster)
- **Tag 2-5:** Monitoring & Hotfix-Bereitschaft

---

## 11. Ressourcen & Links 🔗

### Offizielle Dokumentation
- [Django 5.1 Release Notes](https://docs.djangoproject.com/en/5.1/releases/5.1/)
- [Django 5.0 Release Notes](https://docs.djangoproject.com/en/5.0/releases/5.0/)
- [Django 4.2 Release Notes](https://docs.djangoproject.com/en/4.2/releases/4.2/)
- [Upgrade Guide](https://docs.djangoproject.com/en/5.1/howto/upgrade-version/)

### Third-Party Package Docs
- [DRF 3.15 Release Notes](https://www.django-rest-framework.org/community/release-notes/)
- [Celery 5.4 Changelog](https://docs.celeryq.dev/en/stable/changelog.html)
- [django-elasticsearch-dsl Docs](https://django-elasticsearch-dsl.readthedocs.io/)

### Hilfreiche Tools
- [Django Upgrade Tool](https://github.com/adamchainz/django-upgrade) - Automatische Code-Migrations
- [Django Check Deployment](https://docs.djangoproject.com/en/5.1/howto/deployment/checklist/)

---

## 12. Checkliste für Go-Live ✅

### Pre-Deployment
- [ ] Alle Tests grün (100% pass rate)
- [ ] Code-Review abgeschlossen
- [ ] Backup-Strategie getestet
- [ ] Rollback-Plan dokumentiert
- [ ] Monitoring/Alerting konfiguriert
- [ ] Team informiert über Deployment-Fenster

### Deployment
- [ ] Wartungsmodus aktivieren
- [ ] Database-Backup erstellen
- [ ] Code deployen
- [ ] Dependencies installieren
- [ ] Migrations ausführen
- [ ] Static Files sammeln
- [ ] Services neustarten
- [ ] Smoke-Tests durchführen

### Post-Deployment
- [ ] Health-Checks grün
- [ ] Error-Rate normal
- [ ] Performance-Metriken normal
- [ ] Celery-Tasks laufen
- [ ] Admin-Interface erreichbar
- [ ] User-Feedback sammeln (erste 24h)

---

## Zusammenfassung

**Geschätzter Gesamt-Aufwand:**
- **Entwicklung:** 2-3 Tage
- **Testing:** 1 Woche
- **Deployment:** 1 Tag
- **Monitoring:** 1 Woche

**Haupt-Risiken:**
1. 🟡 **Medium:** Third-Party Package-Inkompatibilitäten
2. 🟢 **Low:** Breaking Changes im Core-Code (wenige)
3. 🟡 **Medium:** Admin-Interface CSS-Anpassungen

**Empfohlener Ansatz:**
Stufenweise Migration (4.1 → 4.2 → 5.0 → 5.1) mit ausführlichen Tests nach jeder Stufe.

**Nächster Schritt:**
```bash
# 1. Python 3.11 installieren
# 2. Feature-Branch erstellen
git checkout -b django5-upgrade

# 3. Code-Änderungen anwenden
python scripts/apply_code_changes.py

# 4. Upgrade starten
bash scripts/upgrade_django5.sh
```

---

**Fragen oder Probleme?** Dokumentiere sie in: `docs/django5-upgrade-issues.md`

**Erfolg!** 🎉 Nach dem Upgrade hast du:
- ✅ Moderne, zukunftssichere Django-Version
- ✅ Bessere Performance (10-20% schnellere Queries)
- ✅ Security-Updates für die nächsten 3+ Jahre (bis Django 5.x EOL)
- ✅ Vorbereitung für Python 3.13+
