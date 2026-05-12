# CI/CD Production & Scale Recommendations

## Current Pipeline (ci.yml) Optimizations

### 1. Cache pip Dependencies & Source
Every CI job re-checks out the full source and re-installs all deps. Add caching:

```yaml
- name: Cache pip
  uses: actions/cache@v4
  with:
    path: ~/.cache/pip
    key: pip-${{ env.PYTHON_VERSION }}-${{ hashFiles('src/requirements.txt') }}
    restore-keys: pip-${{ env.PYTHON_VERSION }}-
```

### 2. Consolidate Checkout Steps (reusable action)
The 3x checkout per CI run pattern (checkout CI repo, checkout source, setup Python) is repeated across 4 jobs. Create a composite action or move to a single job with artifacts:

```yaml
- name: Cache source checkout
  uses: actions/cache@v4
  with:
    path: src
    key: src-${{ github.sha }}
```

### 3. Add Python Version Matrix Testing
Test against Python 3.10, 3.11, 3.12, 3.13 to catch compatibility issues:

```yaml
strategy:
  matrix:
    python-version: ["3.10", "3.11", "3.12", "3.13"]
```

---

## Security

### 4. Add `.gitignore`
Currently missing. Needed to prevent accidental commits of credentials, caches, or build artifacts:

```gitignore
__pycache__/
*.py[cod]
*.egg-info/
dist/
build/
.venv/
*.xml
reports/
.env
*.json
!secrets/  # if needed
```

### 5. Enable GitHub Secret Scanning & CodeQL
Add `codeql.yml` and enable push protection for secret scanning in repo settings.

### 6. Dependabot Configuration
Create `.github/dependabot.yml` for automated dependency updates on `src/`:

```yaml
version: 2
updates:
  - package-ecosystem: "pip"
    directory: "/src"
    schedule:
      interval: "weekly"
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
```

### 7. Add Software Composition Analysis (SCA)
Scan third-party dependencies for known vulnerabilities. Use `pip-audit` or `trivy` in CI:

```yaml
- name: Audit dependencies
  run: |
    pip install pip-audit
    pip-audit --requirement src/requirements.txt
```

---

## Quality Gates

### 8. Add CXAS Agent Linting (`cxas lint`)
Currently the pipeline lints Python source (ruff) but does not lint the **CX Agent Studio agent configuration** itself. Add:

```yaml
- name: Install cxas-scrapi
  run: pip install cxas-scrapi

- name: Pull agent config
  run: cxas pull "$APP_NAME" --project_id "$PROJECT" --location "$LOCATION"

- name: Lint agent config (60+ rules)
  run: cxas lint --json > lint-results.json
```

### 9. Add Agent CI Testing (`cxas ci-test`)
Push agent to a temp app and run tool tests + evaluations on every PR:

```yaml
- name: Run CXAS CI lifecycle
  run: |
    cxas ci-test \
      --app-dir ./my-agent \
      --project-id ${{ vars.GCP_PROJECT_ID_DEV }} \
      --location ${{ vars.GCP_LOCATION }} \
      --display-name "[CI] PR-${{ github.event.pull_request.number }}"
```

### 10. Enforce Lint Error Exit Code
The current CI uses `ruff check .` which already exits non-zero on errors. Good. But extend zero-errors policy to `cxas lint` too.

### 11. Add CODEOWNERS
Required reviews for critical paths:

```yaml
# .github/CODEOWNERS
.github/workflows/deploy-prod.yml   @team-leads
scripts/deploy.py                    @team-leads
```

---

## Deployment Improvements

### 12. Add Semantic Release / Versioning
The prod deploy creates a `deploy-prod-<timestamp>` tag but doesn't provide semantic versioning. Add a release workflow that:
- Reads version from `src/cxas_scrapi/__init__.py` or `src/pyproject.toml`
- Creates GitHub Release with auto-generated changelog
- Tags with `v{major}.{minor}.{patch}`

### 13. Add Rollback Capability to Deploy Script
The deploy script (`deploy.py`) deploys the latest version always. Enhance to support pinning to a specific version for rollbacks:

```python
# scripts/deploy.py
parser.add_argument("--version-name", help="Pin to a specific version for rollback")
```

### 14. Add Blue/Green Deploy Step to Prod
Create a new deployment alongside the current one, run smoke tests against it, then switch traffic:

```yaml
- name: Deploy candidate version
  run: python scripts/deploy.py --suffix "-candidate"

- name: Smoke test candidate
  run: ...

- name: Promote to production
  run: python scripts/deploy.py --promote
```

### 15. Replace Echo Notifications with Slack/Email
Replace raw `echo "::notice..."` steps with proper Slack notifications:

```yaml
- name: Notify Slack
  uses: slackapi/slack-github-action@v2
  with:
    webhook: ${{ secrets.SLACK_WEBHOOK }}
    webhook-type: incoming-webhook
    payload: |
      {"text": "Deploy to ${{ vars.ENVIRONMENT }}: ${{ job.status }}"}
```

---

## Infrastructure & Governance

### 16. Infrastructure as Code
Drive the GCP bootstrap (SA, WIF pool, WIF provider, IAM bindings) through Terraform or Pulumi instead of a shell-based workflow for auditability and drift detection.

### 17. Budget Alerts & Cost Tracking
Set up GCP budget alerts per environment. Add a `deploy-cost-estimate` manual step that estimates agent deployment costs before production promotion.

### 18. Branch Protection Rules (document in `docs/`)
Enforce in GitHub Settings → Branches:
- `main`: Require PR + 1 approval + status checks (CI, lint, cxas-ci-test)
- `develop`: Require status checks
- `release/*`: Require status checks

### 19. SLO Monitoring for Production Deployments
Define and track SLOs:
- Deployment success rate > 99.5%
- Deployment duration < 10 minutes
- Agent response time regression < 5%

### 20. Disaster Recovery / Backup
- Schedule `cxas pull` weekly to backup agent configs to a GCS bucket
- Version-controlled agent directory in `main` branch serves as the source of truth

---

## CXAS SCRAPI-Specific Scale Patterns

### 21. Pre-Push Hooks
Install a git pre-push hook via `cxas init-github-action --install-hook` that runs `cxas local-test` before every push — catches agent issues before CI even runs.

### 22. QA Scorecards with `cxas insights`
Export scorecards to version control so they evolve with the agent:

```bash
cxas insights export-scorecard-from-insights \
  --scorecard-name "projects/.../qaScorecards/sc-001" \
  --template ./scorecards/customer-satisfaction.json
```

Check scorecard diffs in PR review and import new revisions as part of QA deployment.

### 23. Agent Branching for Parallel Development
Use `cxas branch` to create per-feature agent branches in the platform that mirror git branches:

```bash
cxas branch "projects/.../apps/my-app" \
  --display-name "feature-add-payment" \
  --source-version "projects/.../versions/v1"
```

### 24. Tidy Up CI Temporary Apps
The `cxas init-github-action` generates a cleanup workflow for stale CI temp apps. Make sure it's enabled (not `--no-cleanup`).

---

## Prioritized Implementation Order

| Priority | Item | Effort | Impact |
|----------|------|--------|--------|
| P0 | Add `.gitignore` | 5 min | Prevents credential leaks |
| P0 | Dependabot configuration | 10 min | Automated vulnerability patching |
| P0 | Enable GitHub secret scanning | 2 min | Blocks leaked secrets |
| P1 | Add pip caching to CI jobs | 15 min | 40-60% faster CI |
| P1 | Add `cxas lint` to CI pipeline | 30 min | Catches agent config issues |
| P1 | Add `cxas ci-test` for PRs | 1 hr | End-to-end agent validation |
| P1 | Create CODEOWNERS | 5 min | Enforce review on critical paths |
| P2 | Add CodeQL + security scanning | 20 min | SAST coverage |
| P2 | Slack notification integration | 30 min | Real-time deploy visibility |
| P2 | Blue/green deploy for prod | 2 hr | Zero-downtime deployments |
| P3 | Terraform for GCP infra | 4 hr | Auditability, reproducibility |
| P3 | Semantic release automation | 2 hr | Changelog + version tracking |
| P3 | Python version matrix testing | 30 min | Broader compatibility |
