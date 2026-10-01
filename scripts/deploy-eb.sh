#!/usr/bin/env bash
# Deploy the Spring Boot backend to AWS Elastic Beanstalk (single-instance, ap-south-1).
# Run from repo root:  bash scripts/deploy-eb.sh
set -euo pipefail

REPO="/Users/madhushreegm/Desktop/copart_search"
cd "$REPO/backend"

# Isolated EB CLI venv + writable temp (host $KIROCREW_SCRATCH is not creatable)
export PATH="$REPO/.deploy-tmp/ebvenv/bin:$PATH"
export TMPDIR="$REPO/.deploy-tmp/tmp"
mkdir -p "$TMPDIR"

# Load local .env so secrets flow into eb setenv WITHOUT being committed.
set -a; . "$REPO/.env"; set +a

APP="copart-vehicle-search"
ENVNAME="vehicle-search-env"
REGION="us-east-1"

echo "==> 1/4 Building the fat JAR (tests skipped)"
mvn -q -DskipTests -Dmaven.repo.local=/private/tmp/copart-m2 clean package

echo "==> 2/4 Ensuring EB application exists"
aws elasticbeanstalk describe-applications --application-names "$APP" --region "$REGION" \
  --query 'Applications[0].ApplicationName' --output text 2>/dev/null | grep -q "$APP" \
  || aws elasticbeanstalk create-application --application-name "$APP" --region "$REGION"

# Derive JDBC datasource from the libpq DATABASE_URL in .env (Supabase gives postgres://...).
# Spring needs jdbc:postgresql://host:port/db + separate user/password.
JDBC_URL="jdbc:postgresql://aws-0-us-east-1.pooler.supabase.com:5432/postgres"
DB_USER="postgres.vpmaxubiboaflgtvmimc"
# password = between 'postgres:' and '@'
DB_PASS="${DATABASE_URL#*://postgres:}"; DB_PASS="${DB_PASS%%@*}"

# Secrets + runtime config as EB ENVIRONMENT PROPERTIES (injected as env vars; never in git).
OPTS=(
  "SERVER_PORT=5000"
  "DATABASE_URL=$JDBC_URL"
  "DATABASE_USER=$DB_USER"
  "DATABASE_PASSWORD=$DB_PASS"
  "SUPABASE_URL=$SUPABASE_URL"
  "SUPABASE_PUBLISHABLE_KEY=$SUPABASE_PUBLISHABLE_KEY"
)

if aws elasticbeanstalk describe-environments --application-name "$APP" \
     --environment-names "$ENVNAME" --region "$REGION" \
     --query 'Environments[?Status!=`Terminated`].EnvironmentName' --output text 2>/dev/null \
     | grep -q "$ENVNAME"; then
  echo "==> 3/4 Env exists — deploying new version + updating secrets"
  eb setenv "${OPTS[@]}" -e "$ENVNAME"
  eb deploy "$ENVNAME"
else
  echo "==> 3/4 Creating single-instance env with secrets"
  eb create "$ENVNAME" \
    --single \
    --instance-types t3.small \
    --envvars "$(IFS=,; echo "${OPTS[*]}")"
fi

echo "==> 4/4 Status"
eb status "$ENVNAME"
echo "Open with: eb open $ENVNAME"
