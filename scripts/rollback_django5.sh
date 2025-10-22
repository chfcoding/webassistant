#!/bin/bash
set -e

echo "🚨 Rolling back Django 5 upgrade..."

# Farben
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

# Warnung
echo -e "${RED}WARNING: This will rollback your code and database!${NC}"
echo -e "${YELLOW}Make sure you know what you're doing.${NC}"
echo ""
read -p "Are you sure you want to rollback? (type 'yes' to confirm): " -r
if [[ ! $REPLY == "yes" ]]; then
    echo "Rollback cancelled."
    exit 0
fi

# 1. Find the most recent backup
echo -e "${YELLOW}Step 1/5: Finding backup file...${NC}"
BACKUP_FILE=$(ls -t backup_django5_*.sql 2>/dev/null | head -n1)

if [ -z "$BACKUP_FILE" ]; then
    echo -e "${RED}ERROR: No backup file found!${NC}"
    echo "Please specify backup file path manually:"
    read -p "Backup file: " BACKUP_FILE

    if [ ! -f "$BACKUP_FILE" ]; then
        echo -e "${RED}ERROR: Backup file not found: $BACKUP_FILE${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}✓ Using backup: $BACKUP_FILE${NC}"

# 2. Rollback code
echo -e "${YELLOW}Step 2/5: Rolling back code...${NC}"

# Check if we're on a git branch
if git rev-parse --git-dir > /dev/null 2>&1; then
    echo "Current branch: $(git branch --show-current)"

    # Option 1: Reset to previous commit
    echo "Options:"
    echo "1) Reset to previous commit (hard)"
    echo "2) Checkout to specific tag/commit"
    echo "3) Keep current code"
    read -p "Choose option (1-3): " -n 1 -r
    echo

    case $REPLY in
        1)
            git reset --hard HEAD~1
            echo -e "${GREEN}✓ Code reset to previous commit${NC}"
            ;;
        2)
            git tag -l | grep django
            read -p "Enter tag or commit hash: " TAG
            git checkout "$TAG"
            echo -e "${GREEN}✓ Code checked out to $TAG${NC}"
            ;;
        3)
            echo -e "${YELLOW}⚠ Keeping current code${NC}"
            ;;
    esac
else
    echo -e "${YELLOW}⚠ Not a git repository, skipping code rollback${NC}"
fi

# 3. Restore dependencies
echo -e "${YELLOW}Step 3/5: Restoring Django 4.1 dependencies...${NC}"

# Create temporary requirements
cat > requirements_rollback.txt << EOF
Django==4.1.13
djangorestframework==3.12.2
celery==5.0.5
django-elasticsearch-dsl==8.0
django-filter==2.4.0
psycopg2==2.8.6
redis==3.5.3
EOF

pip install -r requirements_rollback.txt
rm requirements_rollback.txt
echo -e "${GREEN}✓ Dependencies restored${NC}"

# 4. Restore database
echo -e "${YELLOW}Step 4/5: Restoring database...${NC}"

if [ -z "$DATABASE_NAME" ]; then
    DATABASE_NAME="swp"
    echo "Using default database name: swp"
fi

echo "This will DROP and recreate the database!"
read -p "Continue? (y/N) " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    if command -v psql &> /dev/null; then
        # Drop and recreate database
        psql -c "DROP DATABASE IF EXISTS ${DATABASE_NAME};"
        psql -c "CREATE DATABASE ${DATABASE_NAME};"

        # Restore from backup
        psql "$DATABASE_NAME" < "$BACKUP_FILE"
        echo -e "${GREEN}✓ Database restored from $BACKUP_FILE${NC}"
    else
        echo -e "${RED}ERROR: psql not found${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}⚠ Skipping database restore${NC}"
fi

# 5. Restart services
echo -e "${YELLOW}Step 5/5: Restarting services...${NC}"

# Try to restart common services
for service in uwsgi celery nginx; do
    if systemctl list-units --full --all | grep -q "$service.service"; then
        if sudo systemctl restart "$service"; then
            echo -e "${GREEN}✓ Restarted $service${NC}"
        else
            echo -e "${YELLOW}⚠ Could not restart $service${NC}"
        fi
    fi
done

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Rollback completed${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
echo ""
echo "Next steps:"
echo "1. Verify application is running"
echo "2. Check logs for errors"
echo "3. Test critical functionality"
echo ""
echo "Restored from backup: $BACKUP_FILE"
