#!/usr/bin/env python3
"""Deploy script for cx-agent-studio (cxas-scrapi).

Reads environment variables set by the GitHub Actions workflow and:
  1. Connects to the CES Agent Studio app.
  2. Fetches the latest app version.
  3. Creates or updates the named deployment for the target environment.

Required env vars:
  GCP_PROJECT_ID  – GCP project ID
  GCP_LOCATION    – GCP region (e.g. "us")
  CXAS_APP_ID     – Agent Studio app UUID
  ENVIRONMENT     – "dev" | "qa" | "prod"

Optional env vars:
  CXAS_OAUTH_TOKEN – short-lived OAuth token (injected by WIF auth step)
  GOOGLE_APPLICATION_CREDENTIALS – path to service-account JSON
"""

import os
import sys
import logging

from cxas_scrapi.core.deployments import Deployments
from cxas_scrapi.core.versions import Versions

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%dT%H:%M:%SZ",
)
log = logging.getLogger(__name__)

CHANNEL_PROFILE_MAP = {
    "dev": "WEB_AND_MOBILE",
    "qa": "WEB_AND_MOBILE",
    "prod": "WEB_AND_MOBILE",
}


def _require_env(key: str) -> str:
    value = os.environ.get(key)
    if not value:
        log.error("Missing required environment variable: %s", key)
        sys.exit(1)
    return value


def build_app_name(project_id: str, location: str, app_id: str) -> str:
    return f"projects/{project_id}/locations/{location}/apps/{app_id}"


def get_latest_version(versions_client: Versions) -> str:
    """Return the resource name of the most recently created version."""
    all_versions = versions_client.list_versions()
    if not all_versions:
        log.error("No versions found for app %s", versions_client.app_name)
        sys.exit(1)

    # CES returns versions in reverse-chronological order; take the first.
    latest = all_versions[0]
    log.info("Latest version: %s (%s)", latest.name, latest.display_name)
    return latest.name


def upsert_deployment(
    deployments_client: Deployments,
    environment: str,
    version_name: str,
    channel_profile: str,
) -> None:
    """Create the deployment if absent; otherwise update its version."""
    deployment_id = f"{environment}-deployment"
    display_name = f"{environment.upper()} Deployment"

    existing = deployments_client.get_deployments_map(reverse=True)
    log.info("Existing deployments: %s", list(existing.keys()))

    if display_name in existing:
        log.info("Updating existing deployment: %s → version %s", deployment_id, version_name)
        deployments_client.update_deployment(
            deployment_id=deployment_id,
            app_version=version_name,
        )
        log.info("Deployment updated successfully.")
    else:
        log.info("Creating new deployment: %s → version %s", deployment_id, version_name)
        deployments_client.create_deployment(
            deployment_id=deployment_id,
            display_name=display_name,
            app_version=version_name,
            channel_profile=channel_profile,
        )
        log.info("Deployment created successfully.")


def main() -> None:
    project_id = _require_env("GCP_PROJECT_ID")
    location = _require_env("GCP_LOCATION")
    app_id = _require_env("CXAS_APP_ID")
    environment = _require_env("ENVIRONMENT").lower()

    if environment not in ("dev", "qa", "prod"):
        log.error("ENVIRONMENT must be one of: dev, qa, prod (got %r)", environment)
        sys.exit(1)

    app_name = build_app_name(project_id, location, app_id)
    log.info("Target app: %s (environment=%s)", app_name, environment)

    versions_client = Versions(app_name=app_name)
    deployments_client = Deployments(app_name=app_name)

    version_name = get_latest_version(versions_client)
    channel_profile = CHANNEL_PROFILE_MAP[environment]

    upsert_deployment(
        deployments_client=deployments_client,
        environment=environment,
        version_name=version_name,
        channel_profile=channel_profile,
    )

    log.info(
        "Deploy complete. App=%s Environment=%s Version=%s",
        app_name,
        environment,
        version_name,
    )


if __name__ == "__main__":
    main()
