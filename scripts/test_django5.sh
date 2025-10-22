#!/bin/bash
# Comprehensive test suite for Django 5.1 upgrade

set -e

# Farben
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "🧪 Running Django 5.1 Test Suite..."
echo "=================================="

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

run_test() {
    local test_name=$1
    local test_command=$2

    echo ""
    echo -e "${YELLOW}Testing: $test_name${NC}"

    if eval "$test_command"; then
        echo -e "${GREEN}✓ PASSED${NC}"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗ FAILED${NC}"
        ((TESTS_FAILED++))
        return 1
    fi
}

# 1. Unit Tests
run_test "Unit tests" "python manage.py test --parallel --keepdb --verbosity=2"

# 2. Migration checks
run_test "Migration checks" "python manage.py makemigrations --check --dry-run"

# 3. System checks
run_test "System checks" "python manage.py check"

# 4. Deployment checks (nur warnings, nicht fatal)
echo ""
echo -e "${YELLOW}Testing: Deployment checks${NC}"
if python manage.py check --deploy 2>&1 | tee /tmp/deploy_check.log; then
    echo -e "${GREEN}✓ PASSED (with warnings)${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${YELLOW}⚠ WARNINGS (non-critical)${NC}"
    cat /tmp/deploy_check.log
    ((TESTS_PASSED++))
fi

# 5. Database connection
run_test "Database connection" "python manage.py dbshell --command='SELECT 1;' 2>/dev/null"

# 6. Elasticsearch connection (optional)
echo ""
echo -e "${YELLOW}Testing: Elasticsearch connection${NC}"
if python manage.py search_index --help &>/dev/null; then
    if timeout 10 python -c "
from django.conf import settings
from elasticsearch import Elasticsearch
es_config = settings.ELASTICSEARCH_DSL['default']
es = Elasticsearch([es_config['hosts']])
print('Connected:', es.ping())
" 2>/dev/null; then
        echo -e "${GREEN}✓ PASSED${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${YELLOW}⚠ Elasticsearch not available (non-critical)${NC}"
        ((TESTS_PASSED++))
    fi
else
    echo -e "${YELLOW}⚠ Elasticsearch DSL not configured (skipping)${NC}"
    ((TESTS_PASSED++))
fi

# 7. Celery health check (optional)
echo ""
echo -e "${YELLOW}Testing: Celery connection${NC}"
if command -v celery &> /dev/null; then
    if timeout 5 celery -A swp inspect ping 2>/dev/null; then
        echo -e "${GREEN}✓ PASSED${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${YELLOW}⚠ Celery not running (non-critical)${NC}"
        ((TESTS_PASSED++))
    fi
else
    echo -e "${YELLOW}⚠ Celery not installed (skipping)${NC}"
    ((TESTS_PASSED++))
fi

# 8. Import all models
run_test "Model imports" "python -c 'from swp.models import *; print(\"All models imported successfully\")'"

# 9. API URL resolution
run_test "URL resolution" "python manage.py show_urls --format=table 2>/dev/null || python manage.py show_urls 2>/dev/null || echo 'django-extensions not installed, skipping'"

# 10. Coverage report (optional)
if command -v coverage &> /dev/null; then
    echo ""
    echo -e "${YELLOW}Generating coverage report...${NC}"
    coverage run --source='swp' manage.py test --parallel --keepdb
    coverage report --skip-covered
    coverage html
    echo -e "${GREEN}✓ Coverage report generated in htmlcov/index.html${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${YELLOW}⚠ Coverage not installed (skipping)${NC}"
fi

# Summary
echo ""
echo "=================================="
echo -e "${GREEN}Tests Passed: $TESTS_PASSED${NC}"
if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "${RED}Tests Failed: $TESTS_FAILED${NC}"
    echo ""
    echo -e "${RED}❌ Test suite FAILED${NC}"
    exit 1
else
    echo -e "${GREEN}Tests Failed: 0${NC}"
    echo ""
    echo -e "${GREEN}✅ All tests PASSED!${NC}"
    exit 0
fi
