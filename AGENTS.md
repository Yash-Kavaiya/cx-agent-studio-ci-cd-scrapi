# Project: cx-agent-studio-ci-cd-scrapi

CI/CD configuration repository for deploying `cxas-scrapi` (Google CX Agent Studio) to GCP across dev, qa, and prod environments.

## Structure

```
.github/workflows/
  ci.yml           # Core CI: lint → test:tools + test:callbacks → test:all
  deploy-dev.yml   # Deploy to dev on develop branch pushes
  deploy-qa.yml    # Deploy to QA on release/** branch pushes
  deploy-prod.yml  # Deploy to prod on main pushes (requires approval gate)
  bootstrap-gcp.yml# One-time GCP infra setup (SA, WIF, IAM)
scripts/
  deploy.py        # Python deploy script using cxas_scrapi SDK
  setup-github-env.sh
docs/
  cicd-setup.md    # Setup guide
cloudbuild.yaml    # Google Cloud Build alternative pipeline
```

## Skills

- `.agents/skills/cxas-scrapi/SKILL.md` — CXAS SCRAPI CLI reference (all `cxas` commands)

## Common Operations

### Add pip caching to CI

```yaml
- name: Cache pip
  uses: actions/cache@v4
  with:
    path: ~/.cache/pip
    key: pip-${{ env.PYTHON_VERSION }}-${{ hashFiles('src/requirements.txt') }}
```

### Add CXAS agent linting to CI

```yaml
- name: Lint agent config
  run: |
    pip install cxas-scrapi
    cxas lint --app-dir ./my-agent --json > lint-results.json
```

### Generate GitHub Actions workflow for agent

```bash
cxas init-github-action \
  --app-dir ./my-agent \
  --workload-identity-provider "$WIF_PROVIDER" \
  --service-account "$SA_EMAIL" \
  --project-id my-project \
  --location us-central1
```

### Deploy to specific environment

```bash
GCP_PROJECT_ID=my-project \
GCP_LOCATION=us \
CXAS_APP_ID=<uuid> \
ENVIRONMENT=dev \
python scripts/deploy.py
```

## Key Config

| Env | Branch | Project Var | App ID Var | Approval |
|-----|--------|-------------|------------|----------|
| dev | develop | GCP_PROJECT_ID_DEV | CXAS_APP_ID_DEV | No |
| qa | release/** | GCP_PROJECT_ID_QA | CXAS_APP_ID_QA | No |
| prod | main | GCP_PROJECT_ID_PROD | CXAS_APP_ID_PROD | Yes (prod-approval env) |

Secrets: `GCP_WIF_PROVIDER`, `GCP_SA_EMAIL` (repo-level).
