# Deploy preview environment using preevy

## About Preevy

Preevy is a powerful CLI tool designed to simplify the process of creating ephemeral preview environments.
Using Preevy, you can easily provision any [Docker Compose](https://docs.docker.com/compose/) application using any Kubernetes server or affordable VMs on [AWS Lightsail](https://aws.amazon.com/free/compute/lightsail), [Google Cloud](https://cloud.google.com/compute/) or [Azure VM](https://azure.microsoft.com/en-us/products/virtual-machines/).

Visit The full documentation here: https://preevy.dev/

## About the preevy-up action

Use this action to build and deploy a preview environment using the Preevy CLI whenever a GitHub PR is created or updated.

Preevy's [GitHub plugin](https://preevy.dev/integrations/github-plugin) will automatically add a comment to your PR with links to the deployed services.

More information about running Preevy from CI [over here](https://preevy.dev/ci/overview#how-to-run-preevy-from-the-ci).

Use [preevy-down action](https://github.com/marketplace/actions/preevy-down) to remove the preview environment when the PR is merged or closed.

## Permissions

Preevy requires the following [GitHub Actions permissions](https://docs.github.com/en/actions/using-jobs/assigning-permissions-to-jobs):

* `contents: read`: used by Preevy to read the Docker Compose file(s)
* `pull-requests: write`: used by the Preevy GitHub plugin to write a comment with the deployed URLs on the PR

In addition, if you're using GitHub's OIDC Token endpoint to authenticate to your cloud provider (as in the below examples), `id-token: write`: is also needed.

## Inputs

### `profile-url`

*required*: `true`

The profile url created by the CLI, [as detailed in the docs](https://preevy.dev/ci/overview#how-to-run-preevy-from-the-ci).

### `version`

*required*: `false`

The preevy [CLI version](https://www.npmjs.com/package/preevy?activeTab=versions) to use. Defaults to `latest`.

### `args`

*required*: `false`

Optional additional args to the `preevy up` command, see the full reference [here](https://preevy.dev/cli-reference/#preevy-up-service).

### `docker-compose-yaml-paths`

*required*: `false`

Optional path to the `docker-compose.yaml` file. If not provided, uses the working directory. If you have multiple docker compose files, you can add them as a comma seperated string like so `'docker-compose.yml,docker-compose.dev.yml'`

## Outputs

### `urls-json`

The generated preview environment urls, formatted in JSON.

## Examples

### Build and deploy on AWS Lightsail

The following features are shown:

* [Configuring AWS credentials](https://github.com/aws-actions/configure-aws-credentials) using GitHub's OIDC provider
* Creating a [GitHub environment URL](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment) with a specific service.

```yaml
name: Deploy Preevy environment
on:
  pull_request:
    types:
      - opened
      - reopened
      - synchronize
permissions:
  id-token: write
  contents: read

  # Needed to write a PR comment with the environment URLs
  pull-requests: write
jobs:
  deploy:
    timeout-minutes: 15

    # allow a single job to run per PR
    concurrency: preevy-${{ github.event.number }}

    environment:
      # An environment needs to be created at
      # https://github.com/YOUR-ORG/YOUR-REPO/settings/environments
      name: preview
      url: ${{ steps.store_url.outputs.url }}

    runs-on: ubuntu-latest
    steps:
      - uses: aws-actions/configure-aws-credentials@v2
        with:
          role-to-assume: arn:aws:iam::12345678:role/my-role
          aws-region: eu-west-1

      - uses: actions/checkout@v3

      - uses: livecycle/preevy-up-action@v2.0.0
        id: preevy
        with:
          # Create the profile using the `preevy init` command, see
          # https://preevy.dev/ci/overview
          profile-url: "s3://preevy-12345678-my-profile?region=eu-west-1"
          docker-compose-yaml-paths: "./docker/docker-compose.yaml"

      # Change `frontend` and `3000` in this step to your main service and port
      # This will appear as the GH environment URL
      - id: store_url
        name: Store URL of frontend
        run: |
          echo url=$(jq -r '.[] | select(.service=="frontend" and .port==3000).url' "${{ steps.preevy_up.outputs.urls-file }}") >> "$GITHUB_OUTPUT"
```

### Build on the CI machine with cache, deploy on a Google Cloud VM

The following features are shown:

* [Configuring Google Cloud credentials](https://github.com/google-github-actions/auth) using a Service Account JSON file
* [Offloading the build the CI machine](https://preevy.dev/recipes/faster-build#part-1-offload-the-build) by creating a BuildKit builder and specifying its name to the Preevy up action
* Using GitHub Packages (GitHub Container Registry, GHCR) as a [cache](https://preevy.dev/recipes/faster-build#part-2-automatically-configure-cache) to make the build faster across different PRs.

```yaml
name: Deploy Preevy environment
on:
  pull_request:
    types:
      - opened
      - reopened
      - synchronize
permissions:
  id-token: write
  contents: read

  # Needed to use GHCR
  packages: write

  # Needed to write a PR comment with the environment URLs
  pull-requests: write
jobs:
  deploy:
    timeout-minutes: 15
    concurrency: preevy-${{ github.event.number }}

    environment:
      name: preview
      url: ${{ steps.store_url.outputs.url }}

    env:
      GITHUB_TOKEN: ${{ github.token }}

    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: 'Authenticate to Google Cloud'
        id: auth
        uses: 'google-github-actions/auth@v1'
        with:
          token_format: access_token

          # Create a key according to https://github.com/google-github-actions/auth#service-account-key-json
          credentials_json: '${{ secrets.PREEVY_SA_KEY }}'

      - name: Set up Docker Buildx
        id: buildx_setup
        uses: docker/setup-buildx-action@v3

      -
        name: Login to GitHub Container Registry
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - uses: livecycle/preevy-up-action@v2.0.0
        id: preevy_up
        with:
          # Create the profile using the `preevy init` command, see
          # https://preevy.dev/ci/overview
          profile-url: "s3://preevy-12345678-my-profile?region=eu-west-1"
          # Specify the GHCR registry and the builder created above
          args: --registry ghcr.io/livecycle --builder ${{ steps.buildx_setup.outputs.name }}

      # Change `frontend` and `3000` in this step to your main service and port
      # This will appear as the GH environment URL
      - id: store_url
        name: Store URL of frontend
        run: |
          echo url=$(jq -r '.[] | select(.service=="frontend" and .port==3000).url' "${{ steps.preevy_up.outputs.urls-file }}") >> "$GITHUB_OUTPUT"

```