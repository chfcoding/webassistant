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
    original_content = content
    content = re.sub(r'^USE_L10N = .*\n', '', content, flags=re.MULTILINE)

    if content != original_content:
        settings_file.write_text(content)
        print(f"✓ Removed USE_L10N from {settings_file}")
    else:
        print(f"ℹ USE_L10N not found in {settings_file}")

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

    new_content = re.sub(wsgi_pattern, replacement, content)

    if new_content != content:
        settings_file.write_text(new_content)
        print(f"✓ Added DEFAULT_AUTO_FIELD to {settings_file}")
    else:
        print(f"⚠ Could not find WSGI_APPLICATION in {settings_file}")

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

    new_content = re.sub(pattern, replacement, content)

    if new_content != content:
        settings_file.write_text(new_content)
        print(f"✓ Added SECRET_KEY validation to {settings_file}")
    else:
        print(f"⚠ Could not find SECRET_KEY pattern in {settings_file}")

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
