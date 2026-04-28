#!/usr/bin/env bash
# Setup GitHub repository environments, secrets, and variables
# for the cx-agent-studio CI/CD pipeline using the gh CLI.
#
# Usage:
#   chmod +x scripts/setup-github-env.sh
#   ./scripts/setup-github-env.sh
#
# Prerequisites:
#   gh auth login   (must be authenticated as repo admin)

set -euo pipefail

# ─── Edit these values before running ────────────────────────────────────────
REPO="Yash-Kavaiya/cx-agent-studio-ci-cd-scrapi"   # owner/repo

GCP_PROJECT_NUMBER="123456789012"                   # gcloud projects describe genaiguruyoutube --format="value(projectNumber)"
GCP_SA_EMAIL="cxas-cicd@genaiguruyoutube.iam.gserviceaccount.com"

CXAS_APP_ID_DEV="a1b2c3d4-0000-0000-0000-dev000000000"
CXAS_APP_ID_QA="a1b2c3d4-0000-0000-0000-qa0000000000"
CXAS_APP_ID_PROD="8f308ef3-ded1-469a-bb06-8b0af3e8816c"

GCP_LOCATION="us"
GCP_PROJECT_ID="genaiguruyoutube"

WIF_PROVIDER="projects/${GCP_PROJECT_NUMBER}/locations/global/workloadIdentityPools/github-pool/providers/github-provider"
# ─────────────────────────────────────────────────────────────────────────────

echo "==> Repository: $REPO"
echo ""

# ── 1. Create GitHub Environments ────────────────────────────────────────────
echo "==> Creating environments..."

for ENV in dev qa prod-approval prod; do
  gh api \
    --method PUT \
    -H "Accept: application/vnd.github+json" \
    "/repos/${REPO}/environments/${ENV}" \
    --input /dev/null \
    --silent && echo "  ✓ Environment '${ENV}' created/updated"
done

# Set required reviewers on prod-approval (replace USER_ID with actual GitHub user ID)
# gh api --method PUT "/repos/${REPO}/environments/prod-approval" \
#   --field reviewers='[{"type":"User","id":YOUR_GITHUB_USER_ID}]'

echo ""

# ── 2. Repo-level Secrets ─────────────────────────────────────────────────────
echo "==> Setting repo-level secrets..."

gh secret set GCP_WIF_PROVIDER \
  --repo "$REPO" \
  --body "$WIF_PROVIDER"
echo "  ✓ GCP_WIF_PROVIDER"

gh secret set GCP_SA_EMAIL \
  --repo "$REPO" \
  --body "$GCP_SA_EMAIL"
echo "  ✓ GCP_SA_EMAIL"

echo ""

# ── 3. Environment Variables: dev ────────────────────────────────────────────
echo "==> Setting variables for 'dev' environment..."

gh variable set GCP_PROJECT_ID_DEV \
  --repo "$REPO" \
  --env dev \
  --body "$GCP_PROJECT_ID"
echo "  ✓ GCP_PROJECT_ID_DEV=$GCP_PROJECT_ID"

gh variable set GCP_LOCATION \
  --repo "$REPO" \
  --env dev \
  --body "$GCP_LOCATION"
echo "  ✓ GCP_LOCATION=$GCP_LOCATION"

gh variable set CXAS_APP_ID_DEV \
  --repo "$REPO" \
  --env dev \
  --body "$CXAS_APP_ID_DEV"
echo "  ✓ CXAS_APP_ID_DEV=$CXAS_APP_ID_DEV"

echo ""

# ── 4. Environment Variables: qa ─────────────────────────────────────────────
echo "==> Setting variables for 'qa' environment..."

gh variable set GCP_PROJECT_ID_QA \
  --repo "$REPO" \
  --env qa \
  --body "$GCP_PROJECT_ID"
echo "  ✓ GCP_PROJECT_ID_QA=$GCP_PROJECT_ID"

gh variable set GCP_LOCATION \
  --repo "$REPO" \
  --env qa \
  --body "$GCP_LOCATION"
echo "  ✓ GCP_LOCATION=$GCP_LOCATION"

gh variable set CXAS_APP_ID_QA \
  --repo "$REPO" \
  --env qa \
  --body "$CXAS_APP_ID_QA"
echo "  ✓ CXAS_APP_ID_QA=$CXAS_APP_ID_QA"

echo ""

# ── 5. Environment Variables: prod ───────────────────────────────────────────
echo "==> Setting variables for 'prod' environment..."

gh variable set GCP_PROJECT_ID_PROD \
  --repo "$REPO" \
  --env prod \
  --body "$GCP_PROJECT_ID"
echo "  ✓ GCP_PROJECT_ID_PROD=$GCP_PROJECT_ID"

gh variable set GCP_LOCATION \
  --repo "$REPO" \
  --env prod \
  --body "$GCP_LOCATION"
echo "  ✓ GCP_LOCATION=$GCP_LOCATION"

gh variable set CXAS_APP_ID_PROD \
  --repo "$REPO" \
  --env prod \
  --body "$CXAS_APP_ID_PROD"
echo "  ✓ CXAS_APP_ID_PROD=$CXAS_APP_ID_PROD"

echo ""
echo "==> Done! Verify at: https://github.com/${REPO}/settings/environments"
