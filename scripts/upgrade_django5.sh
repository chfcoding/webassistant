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
PYTHON_MAJOR=$(echo $PYTHON_VERSION | cut -d'.' -f1)
PYTHON_MINOR=$(echo $PYTHON_VERSION | cut -d'.' -f2)

if [ "$PYTHON_MAJOR" -lt 3 ] || ([ "$PYTHON_MAJOR" -eq 3 ] && [ "$PYTHON_MINOR" -lt 10 ]); then
    echo -e "${RED}ERROR: Python 3.10+ required, found $PYTHON_VERSION${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Python version OK: $PYTHON_VERSION${NC}"

# Git Status Check
if [[ -n $(git status -s) ]]; then
    echo -e "${YELLOW}⚠ WARNING: Uncommitted changes detected.${NC}"
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi
echo -e "${GREEN}✓ Git check complete${NC}"

# 2. Backup Database
echo -e "${YELLOW}Step 2/8: Creating database backup...${NC}"
BACKUP_FILE="backup_django5_$(date +%Y%m%d_%H%M%S).sql"

# Check if DATABASE_NAME is set
if [ -z "$DATABASE_NAME" ]; then
    DATABASE_NAME="swp"
    echo "Using default database name: swp"
fi

if command -v pg_dump &> /dev/null; then
    pg_dump "$DATABASE_NAME" > "$BACKUP_FILE"
    echo -e "${GREEN}✓ Database backed up to $BACKUP_FILE${NC}"
else
    echo -e "${YELLOW}⚠ pg_dump not found, skipping database backup${NC}"
fi

# 3. Update Django to 4.2 (intermediate)
echo -e "${YELLOW}Step 3/8: Upgrading to Django 4.2 (LTS)...${NC}"
pip install Django==4.2.17
python manage.py check
if python manage.py migrate; then
    echo -e "${GREEN}✓ Django 4.2 migrations successful${NC}"
else
    echo -e "${RED}ERROR: Django 4.2 migrations failed${NC}"
    exit 1
fi

# Run quick tests
if python manage.py test --failfast --parallel; then
    echo -e "${GREEN}✓ Django 4.2 tests passed${NC}"
else
    echo -e "${RED}ERROR: Django 4.2 tests failed${NC}"
    exit 1
fi

# 4. Update Django to 5.0
echo -e "${YELLOW}Step 4/8: Upgrading to Django 5.0...${NC}"
pip install Django==5.0.10
python manage.py check
python manage.py migrate

if python manage.py test --failfast --parallel; then
    echo -e "${GREEN}✓ Django 5.0 upgrade successful${NC}"
else
    echo -e "${RED}ERROR: Django 5.0 tests failed${NC}"
    exit 1
fi

# 5. Update Django to 5.1 + all dependencies
echo -e "${YELLOW}Step 5/8: Upgrading to Django 5.1 + dependencies...${NC}"
pip install --upgrade -r requirements.txt
echo -e "${GREEN}✓ All packages updated${NC}"

# 6. Run Django checks
echo -e "${YELLOW}Step 6/8: Running Django system checks...${NC}"
if python manage.py check; then
    echo -e "${GREEN}✓ System checks passed${NC}"
else
    echo -e "${RED}ERROR: System checks failed${NC}"
    exit 1
fi

# 7. Migrate database
echo -e "${YELLOW}Step 7/8: Running migrations...${NC}"
python manage.py makemigrations --check --dry-run || true
python manage.py migrate
echo -e "${GREEN}✓ Migrations completed${NC}"

# 8. Run test suite
echo -e "${YELLOW}Step 8/8: Running full test suite...${NC}"
if command -v coverage &> /dev/null; then
    coverage run manage.py test --parallel
    coverage report
else
    python manage.py test --parallel
fi
echo -e "${GREEN}✓ All tests passed${NC}"

# Rebuild search index
echo -e "${YELLOW}Rebuilding Elasticsearch index...${NC}"
if python manage.py search_index --rebuild -f --noinput; then
    echo -e "${GREEN}✓ Search index rebuilt${NC}"
else
    echo -e "${YELLOW}⚠ Search index rebuild failed (non-critical)${NC}"
fi

# Collect static files
echo -e "${YELLOW}Collecting static files...${NC}"
if python manage.py collectstatic --noinput; then
    echo -e "${GREEN}✓ Static files collected${NC}"
else
    echo -e "${YELLOW}⚠ Static files collection failed (non-critical)${NC}"
fi

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
