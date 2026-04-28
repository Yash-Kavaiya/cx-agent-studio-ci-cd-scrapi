# CI/CD Setup Guide

## Pipeline Overview

```
PR / push
    │
    ▼
Stage 1 · Lint (ruff check + ruff format --check)
    │
    ├─▶ Stage 2a · Test: Tools     ─┐
    │                               ├─▶ Stage 3 · CI: Full Test Suite
    └─▶ Stage 2b · Test: Callbacks ─┘
                                         │
                         ┌───────────────┼───────────────┐
                         ▼               ▼               ▼
                    Deploy Dev      Deploy QA       Deploy Prod
                  (develop branch) (release/*) (main + approval)
```

## Branch Strategy

| Branch | CI | Deploy |
|--------|-----|--------|
| `feature/*` | ✅ Full CI | ❌ |
| `develop` | ✅ Full CI | ✅ Dev |
| `release/**` | ✅ Full CI | ✅ QA |
| `main` | ✅ Full CI | ✅ Prod (requires approval) |

## GitHub Repository Setup

### 1. Create GitHub Environments

Go to **Settings → Environments** and create:

- `dev` — no protection rules needed
- `qa` — optional: require specific reviewers
- `prod-approval` — **required reviewers** (the approval gate)
- `prod` — no additional protection (approval already enforced above)

### 2. Configure Workload Identity Federation (recommended)

```bash
# Create a Workload Identity Pool
gcloud iam workload-identity-pools create "github-pool" \
  --project="genaiguruyoutube" \
  --location="global" \
  --display-name="GitHub Actions Pool"

# Create a provider
gcloud iam workload-identity-pools providers create-oidc "github-provider" \
  --project="genaiguruyoutube" \
  --location="global" \
  --workload-identity-pool="github-pool" \
  --display-name="GitHub provider" \
  --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository" \
  --issuer-uri="https://token.actions.githubusercontent.com"

# Bind the service account
gcloud iam service-accounts add-iam-policy-binding "cxas-cicd@genaiguruyoutube.iam.gserviceaccount.com" \
  --project="genaiguruyoutube" \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github-pool/attribute.repository/YOUR_ORG/YOUR_REPO"
```

### 3. Required Secrets (per-environment or repo-level)

| Secret | Value |
|--------|-------|
| `GCP_WIF_PROVIDER` | `projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github-pool/providers/github-provider` |
| `GCP_SA_EMAIL` | `cxas-cicd@genaiguruyoutube.iam.gserviceaccount.com` |

### 4. Required Variables (per-environment)

Set in **Settings → Environments → [env] → Variables**:

| Variable | Dev | QA | Prod |
|----------|-----|----|------|
| `GCP_PROJECT_ID_DEV` | `genaiguruyoutube` | — | — |
| `GCP_PROJECT_ID_QA` | — | `genaiguruyoutube` | — |
| `GCP_PROJECT_ID_PROD` | — | — | `genaiguruyoutube` |
| `GCP_LOCATION` | `us` | `us` | `us` |
| `CXAS_APP_ID_DEV` | `<dev-app-uuid>` | — | — |
| `CXAS_APP_ID_QA` | — | `<qa-app-uuid>` | — |
| `CXAS_APP_ID_PROD` | — | — | `180a991e-4aa8-49ac-b363-4ef946fb8293` |

> The prod App ID is already known: `180a991e-4aa8-49ac-b363-4ef946fb8293`

### 5. Service Account IAM Roles

Grant the CI/CD service account the following roles on each GCP project:

```bash
gcloud projects add-iam-policy-binding genaiguruyoutube \
  --member="serviceAccount:cxas-cicd@genaiguruyoutube.iam.gserviceaccount.com" \
  --role="roles/ces.developer"

gcloud projects add-iam-policy-binding genaiguruyoutube \
  --member="serviceAccount:cxas-cicd@genaiguruyoutube.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountTokenCreator"
```

## Cloud Build (Alternative)

To trigger from Cloud Build instead of GitHub Actions:

```bash
# Create a trigger for dev
gcloud builds triggers create github \
  --project=genaiguruyoutube \
  --repo-name=cx-agent-studio-ci-cd-scrapi \
  --repo-owner=YOUR_ORG \
  --branch-pattern="^develop$" \
  --build-config=cloudbuild.yaml \
  --substitutions="_ENVIRONMENT=dev,_APP_ID=<dev-app-id>,_LOCATION=us"

# Create a trigger for QA
gcloud builds triggers create github \
  --project=genaiguruyoutube \
  --repo-name=cx-agent-studio-ci-cd-scrapi \
  --repo-owner=YOUR_ORG \
  --branch-pattern="^release/.*" \
  --build-config=cloudbuild.yaml \
  --substitutions="_ENVIRONMENT=qa,_APP_ID=<qa-app-id>,_LOCATION=us"

# Create a trigger for prod
gcloud builds triggers create github \
  --project=genaiguruyoutube \
  --repo-name=cx-agent-studio-ci-cd-scrapi \
  --repo-owner=YOUR_ORG \
  --branch-pattern="^main$" \
  --build-config=cloudbuild.yaml \
  --substitutions="_ENVIRONMENT=prod,_APP_ID=180a991e-4aa8-49ac-b363-4ef946fb8293,_LOCATION=us"
```
