# CXAS SCRAPI Skill

CXAS SCRAPI is the scripting API and CLI for **Google CX Agent Studio** — build, test, deploy, and maintain conversational agents with confidence.

## Installation

```bash
pip install cxas-scrapi
```

Requires Python 3.10+. See the [official docs](https://googlecloudplatform.github.io/cxas-scrapi/stable/) for details.

## Authentication

- **Workload Identity Federation (recommended for CI/CD):** `google-github-actions/auth@v2` action with WIF provider + service account
- **Local / ADC:** `gcloud auth application-default login` or `GOOGLE_APPLICATION_CREDENTIALS`
- **Direct token:** Set `CXAS_OAUTH_TOKEN` env var

## CLI Reference

### Core Agent Lifecycle

| Command | Description |
|---------|------------|
| `cxas init` | Bootstrap a project with skills, config files, and directory structure |
| `cxas pull <app-name>` | Pull agent config from CX Agent Studio to local disk |
| `cxas push <app-name>` | Push local agent config to CX Agent Studio |
| `cxas create` | Create new CXAS resources (apps, agents, tools, etc.) |
| `cxas delete <resource>` | Delete a CXAS resource (app, agent, etc.) |
| `cxas migrate <new-version>` | Migrate an app to a new version |
| `cxas branch <new-branch>` | Branch an app for parallel development |
| `cxas apps list\|describe` | List or describe apps in a project |

### Evaluation & Testing

| Command | Description |
|---------|------------|
| `cxas ci-test` | Full CI lifecycle: push to temp app, run tool tests + evals, exit pass/fail |
| `cxas local-test` | Run `ci-test` lifecycle inside a Docker container locally |
| `cxas test-tools` | Run tool tests in isolation against a deployed app |
| `cxas test-callbacks` | Run callback tests in isolation |
| `cxas test-single-callback` | Run a single callback test |
| `cxas run` | Run evaluations against a deployed app |
| `cxas push-eval` | Push evaluation definitions to the platform |

### Linting & Quality

| Command | Description |
|---------|------------|
| `cxas lint` | Lint agent directory against 60+ best-practice rules |
| `cxas lint --json` | Output lint results as JSON for CI dashboards |
| `cxas lint --fix` | Show fix suggestions alongside issues |
| `cxas lint --only <category>` | Limit to specific category (instructions, tools, config, etc.) |
| `cxas lint --rule I003,C005` | Run only specific rules |
| `cxas lint --validate-only` | Schema + structure checks only (no instruction/eval checks) |

### GitHub Actions

| Command | Description |
|---------|------------|
| `cxas init-github-action` | Generate a GitHub Actions workflow that runs `cxas ci-test` on PRs |
| `cxas init-github-action --auto-create-wif` | Also create WIF resources on GCP automatically |
| `cxas init-github-action --install-hook` | Install a `pre-push` git hook that runs `cxas local-test` |

### Insights & Scorecards (QA)

| Command | Description |
|---------|------------|
| `cxas insights list-scorecards --parent <parent>` | List all QA scorecards |
| `cxas insights export-scorecard-from-insights` | Export a scorecard to JSON/YAML |
| `cxas insights import-scorecard-to-insights` | Import a scorecard from JSON/YAML |
| `cxas insights copy-scorecard` | Copy scorecard questions between projects |

### Utility

| Command | Description |
|---------|------------|
| `cxas export` | Export agent evaluation definitions to local files |
| `cxas list-rules` | List all available lint rules |

## Lint Rule Categories

| Prefix | Category | What it checks |
|--------|----------|---------------|
| `I` | Instructions | Agent instruction quality, clarity, length, formatting |
| `CB` | Callbacks | Callback file structure, naming, implementation patterns |
| `T` | Tools | Tool definition quality, parameter descriptions, schema |
| `E` | Evals | Evaluation structure, turn count, expectation quality |
| `C` | Config | `app.yaml`/`app.json` correctness |
| `S` | Structure | Directory layout, required files, naming conventions |
| `SC` | Schema | JSON/YAML schema validation against CES schemas |

## CI/CD Integration

### cxas lint in CI

```yaml
- name: Run CXAS linter
  run: cxas lint
  # Exit code 0 = no errors; 1 = errors found
```

With JSON output and error reporting:

```yaml
- name: Run linter with JSON output
  run: |
    cxas lint --json > lint-results.json || true
    ERRORS=$(python -c "import json; data=json.load(open('lint-results.json')); print(len([r for r in data if r['severity']=='error']))")
    if [ "$ERRORS" -gt 0 ]; then exit 1; fi
```

### cxas ci-test in CI

```yaml
- name: Run CI Tests
  run: |
    cxas ci-test \
      --app-dir ./my-agent \
      --project-id ${{ vars.GCP_PROJECT_ID }} \
      --location ${{ vars.GCP_LOCATION }} \
      --display-name "[CI] ${{ github.ref_name }}"
```

### cxas init-github-action

Generates workflows automatically:

```bash
cxas init-github-action \
  --app-dir ./my-agent \
  --workload-identity-provider "projects/.../providers/github" \
  --service-account "sa@project.iam.gserviceaccount.com" \
  --project-id my-gcp-project \
  --location us-central1
```

## Python API

Available modules (see [API Reference](https://googlecloudplatform.github.io/cxas-scrapi/stable/api/) for full docs):

| Module | Description |
|--------|-------------|
| `cxas_scrapi.core.apps` | App management |
| `cxas_scrapi.core.agents` | Agent management |
| `cxas_scrapi.core.sessions` | Session management |
| `cxas_scrapi.core.tools` | Tool management |
| `cxas_scrapi.core.guardrails` | Guardrail management |
| `cxas_scrapi.core.deployments` | Deployment management |
| `cxas_scrapi.core.evaluations` | Evaluation management |
| `cxas_scrapi.core.variables` | Variable management |
| `cxas_scrapi.core.versions` | Version management |
| `cxas_scrapi.core.changelogs` | Changelog management |
| `cxas_scrapi.core.callbacks` | Callback management |
| `cxas_scrapi.core.conversation-history` | Conversation history |
| `cxas_scrapi.core.insights` | Insights (scorecards) |
| `cxas_scrapi.evals.tool-evals` | Tool evaluations |
| `cxas_scrapi.evals.simulation-evals` | Simulation evaluations |
| `cxas_scrapi.evals.callback-evals` | Callback evaluations |
| `cxas_scrapi.evals.guardrail-evals` | Guardrail evaluations |
| `cxas_scrapi.utils.linter` | Linter utility |
| `cxas_scrapi.utils.secret-manager` | Secret Manager utility |
| `cxas_scrapi.utils.changelog-utils` | Changelog utility |
| `cxas_scrapi.utils.google-sheets` | Google Sheets utility |

## Deploy Script Pattern

```python
from cxas_scrapi.core.deployments import Deployments
from cxas_scrapi.core.versions import Versions

deployments = Deployments(project_id=project, location=location)
versions = Versions(project_id=project, location=location)

# Create or update deployment
deployments.create_or_update_deployment(
    app_id=app_id,
    display_name=display_name,
    channel_profile=channel_profile,
)
```

## Resources

- **Docs:** https://googlecloudplatform.github.io/cxas-scrapi/stable/
- **GitHub:** https://github.com/GoogleCloudPlatform/cxas-scrapi
- **PyPI:** `pip install cxas-scrapi`
