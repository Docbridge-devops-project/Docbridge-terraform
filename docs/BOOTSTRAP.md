# DocBridge Bootstrap Setup Guide

This guide details the one-time manual steps required to prepare your Azure subscription, create your deployment Service Principal, configure OIDC, initialize the local Terraform lock file, and register GitHub repository secrets.

---

## 1. Tool Installation Checklist
Ensure the following tools are installed locally:
- **Azure CLI** (v2.50+)
- **Terraform** (v1.5.0+)
- **kubectl** (configured for AKS)
- **Docker Desktop**
- **Git**

---

## 2. Authenticating and Setting Subscription
Login to your Azure account and list your subscription details:
```bash
# Log in to Azure
az login

# List subscriptions to find your ID
az account list --output table

# Set the active subscription
az account set --subscription "YOUR_SUBSCRIPTION_ID"

# Verify current subscription active context
az account show --output json
```

---

## 3. Creating Resource Group
Create the resource group where all project infrastructure will reside:
```bash
az group create \
  --name "docbridge-rg" \
  --location "eastus2" \
  --tags "Project=docbridge" "Environment=dev" "ManagedBy=Bootstrap"
```

---

## 4. Creating Storage Account for Terraform State
Create the storage account to store the remote Terraform state file securely (LRS, HTTPS only, disabled public blob):
```bash
# Generate a random 6-character suffix to ensure uniqueness
# Note: Storage names must be 3-24 characters, lowercase alphanumeric only
STATE_SA_NAME="docbridgetfstate$(openssl rand -hex 3)"
echo "Storage Account Name: $STATE_SA_NAME"

# Create the Storage Account
az storage account create \
  --name "$STATE_SA_NAME" \
  --resource-group "docbridge-rg" \
  --location "eastus2" \
  --sku "Standard_LRS" \
  --encryption-services blob \
  --allow-blob-public-access false \
  --min-tls-version "TLS1_2"

# Create the blob container
az storage container create \
  --name "tfstate" \
  --account-name "$STATE_SA_NAME"
```

---

## 5. Creating Service Principal for GitHub Actions
Create an Azure Active Directory Service Principal for deployment authentication:
```bash
# Create Service Principal and get Client ID
SP_NAME="docbridge-github-sp"
az ad sp create-for-rbac --name "$SP_NAME" --skip-assignment true
```
Make a note of the `appId` (Client ID), `displayName`, and `tenant` fields from the output.

---

## 6. Assigning RBAC Contributor Permission
Grant the Service Principal Contributor access to the resource group:
```bash
# Fetch SP Client App ID
SP_CLIENT_ID=$(az ad sp list --display-name "$SP_NAME" --query "[0].appId" -o tsv)

# Assign Contributor role
az role assignment create \
  --assignee "$SP_CLIENT_ID" \
  --role "Contributor" \
  --scope "/subscriptions/YOUR_SUBSCRIPTION_ID/resourceGroups/docbridge-rg"
```

---

## 7. Configuring OIDC Federated Credentials
Establish Trust between GitHub and Azure AD without using long-lived Client Secrets.
Replace `YOUR_GITHUB_ORG/YOUR_REPO` with your repository path (e.g., `arjunmehta/docbridge`).

### Credential for Main Branch Push:
```bash
az ad app federated-credential create \
  --id "$SP_CLIENT_ID" \
  --parameters '{
    "name": "docbridge-gha-main",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:YOUR_GITHUB_ORG/YOUR_REPO:ref:refs/heads/main",
    "description": "Deployments on main branch push",
    "audiences": ["api://AzureADTokenExchange"]
  }'
```

### Credential for Pull Requests:
```bash
az ad app federated-credential create \
  --id "$SP_CLIENT_ID" \
  --parameters '{
    "name": "docbridge-gha-pr",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:YOUR_GITHUB_ORG/YOUR_REPO:pull_request",
    "description": "Infrastructure validation plans on Pull Requests",
    "audiences": ["api://AzureADTokenExchange"]
  }'
```

---

## 8. Initializing Local Terraform Lock File
Before pushing Terraform configurations to GitHub, initialize Terraform locally to download providers and create `.terraform.lock.hcl`. This lock file **must** be committed to Git to pin exact provider versions:
```bash
cd terraform

# Run init with partial backend configurations
terraform init \
  -backend-config="resource_group_name=docbridge-rg" \
  -backend-config="storage_account_name=YOUR_STATE_SA_NAME" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=dev.terraform.tfstate"

# Add and commit the lock file
git add .terraform.lock.hcl
git commit -m "chore: add terraform provider lock file"
git push origin main
cd ..
```

---

## 9. Setting Up GitHub Repository Secrets
Add the following secrets under **Settings > Secrets and variables > Actions > Repository secrets** on GitHub:

| Secret Name | Description | Example / Source |
| :--- | :--- | :--- |
| `AZURE_CLIENT_ID` | Application (Client) ID of the Service Principal | From Step 5 (`appId`) |
| `AZURE_TENANT_ID` | Tenant (Directory) ID of your Azure Active Directory | From Step 5 (`tenant`) |
| `AZURE_SUBSCRIPTION_ID` | Your active Azure Subscription ID | `YOUR_SUBSCRIPTION_ID` |
| `TF_STORAGE_ACCOUNT_NAME` | Name of the state Storage Account | From Step 4 (`$STATE_SA_NAME`) |
| `TF_CONTAINER_NAME` | Name of the state Blob Container | `tfstate` |
| `DB_PASSWORD` | Secure administrator password for PostgreSQL | e.g. `Str0ngP@ssw0rd!` |
| `JWT_ACCESS_SECRET` | Secret key for generating JWT access tokens | A secure random string |
| `JWT_REFRESH_SECRET` | Secret key for generating JWT refresh tokens | A secure random string |
| `AZURE_OPENAI_KEY` | Azure OpenAI Service Key | From Azure AI / OpenAI Playground |
| `ALERT_EMAIL` | Target email for infrastructure alerts | `arjun.mehta@gmail.com` |

---

## 10. CRITICAL: Installing API Gateway Redis Packages
The API Gateway requires Redis integration modules. Run the following commands locally and commit the updated configuration **before** building the container images:
```bash
cd gateway
npm install rate-limit-redis ioredis
cd ..
git add gateway/package.json gateway/package-lock.json
git commit -m "chore: add Redis distributed rate limiting packages"
git push origin main
```
> [!WARNING]
> Skipping this prerequisite will cause the `api-gateway` pod to crash instantly on startup due to missing NPM packages.

---

## 11. Creating Budget Alert
Keep track of costs and avoid unexpected charges during the trial:
```bash
az consumption budget create \
  --budget-name "DocBridgeBudget" \
  --amount 160 \
  --time-grain "Monthly" \
  --start-date "2026-06-01" \
  --end-date "2028-12-31" \
  --contact-emails "arjun.mehta@gmail.com" \
  --notification-key-actual "80"
```

---

## 12. Triggering Deployments and Verifying
1. Trigger the infrastructure pipeline by committing files inside `terraform/` or merging a pull request to `main`.
2. Verify all resources are successfully built.
3. Commit and push your microservices and manifests in `kubernetes/` to trigger the application build, migration, and deployment.
4. Verify deployment pods:
```bash
# Get credentials for local kubectl
az aks get-credentials --resource-group docbridge-rg --name docbridge-dev-aks

# Check all pods
kubectl get pods -n docbridge

# Check ingress rules and public IP routing
kubectl get ingress -n docbridge
```

---

## 13. Destroying Resources
To tear down the entire cloud environment when testing is finished, run locally:
```bash
cd terraform
terraform destroy \
  -var="subscription_id=YOUR_SUBSCRIPTION_ID" \
  -var="owner=ArjunMehta" \
  -var="alert_email=arjun.mehta@gmail.com" \
  -var="db_password=YOUR_DB_PASSWORD" \
  -var="jwt_access_secret=YOUR_JWT_SECRET" \
  -var="jwt_refresh_secret=YOUR_JWT_SECRET" \
  -var="azure_openai_key=YOUR_OPENAI_KEY"
```
Or manually delete the resource group via the Azure Portal.

---

## 14. Helm Chart Deployment and Upgrades

After migrating from raw manifests to a unified Helm chart, the application resources are managed through Helm.

### First-Time Installation or Upgrades

To install or upgrade the DocBridge application using Helm:

1. Retrieve the Terraform outputs:
   ```bash
   cd terraform
   KV_NAME=$(terraform output -raw key_vault_name)
   IDENTITY_ID=$(terraform output -raw workload_identity_client_id)
   POSTGRES_FQDN=$(terraform output -raw postgres_fqdn)
   AGW_IP=$(terraform output -raw app_gateway_public_ip)
   TENANT_ID="YOUR_AZURE_TENANT_ID"
   ```

2. Run the Helm upgrade command:
   ```bash
   helm upgrade --install docbridge ./helm/docbridge \
     --namespace docbridge \
     --create-namespace \
     --values helm/docbridge/values.yaml \
     --values helm/docbridge/values.dev.yaml \
     --set azure.keyVaultName=$KV_NAME \
     --set azure.workloadIdentityClientId=$IDENTITY_ID \
     --set azure.tenantId=$TENANT_ID \
     --set database.host=$POSTGRES_FQDN \
     --set gateway.corsOrigin=http://$AGW_IP \
     --wait \
     --timeout 10m
   ```

### Important: Never Use kubectl apply After Helm

> [!WARNING]
> After Helm takes ownership of the application resources, **kubectl apply -f kubernetes/ must never be used again** to deploy or manage application configurations. 
> 
> Doing so causes configuration drift where Helm's stored release state does not match what is actually deployed on the cluster, resulting in unpredictable behavior or failed rollouts on subsequent Helm upgrades.
> 
> - **kubectl** must only be used for read operations (e.g., checking logs, describing pods, or viewing statuses):
>   ```bash
>   kubectl get pods -n docbridge
>   kubectl describe pod -n docbridge
>   kubectl logs -n docbridge deployment/api-gateway
>   kubectl get ingress -n docbridge
>   ```
> - **All updates** to replicas, environment variables, secret mappings, image versions, or ingress configuration must be done by modifying the Helm values and running `helm upgrade --install`.

---

## 15. Pipeline System Setup (GitHub Actions & Infrastructure Automation)

This section details the configuration steps required to fully activate the Terraform infrastructure pipeline and the microservice CI/CD pipelines.

### 15.1. GitHub Secrets Setup
Add the following 5 new secrets to your GitHub repository under **Settings > Secrets and variables > Actions > Repository secrets**:

| Secret Name | Purpose / Description | How to Get |
| :--- | :--- | :--- |
| `SONAR_TOKEN` | Authentication token for SonarCloud code quality scans. | sonarcloud.io > My Account > Security > Tokens > Generate a User Token |
| `SONAR_ORGANIZATION` | SonarCloud organization key | sonarcloud.io > Your organization page (found in URL/Settings) |
| `SNYK_TOKEN` | Snyk token to run SCA dependency checks. | app.snyk.io > Account Settings > General > Auth Token |
| `SMTP_USERNAME` | Gmail address used to send DevOps notification emails. | e.g. `yourdevops@gmail.com` |
| `SMTP_PASSWORD` | Gmail App Password (16 characters, NOT regular password). | Google Account > Security > App Passwords (needs 2FA enabled) |

### 15.2. GitHub Environments Setup
Configure the following two environments in your GitHub repository under **Settings > Environments**:

1. **development**:
   - Protection rules: None (auto-approves deployments on push to `main`).
2. **production**:
   - Protection rules: Enable **Required reviewers** and add your own GitHub username. This creates the deployment approval gate UI.

### 15.3. SonarCloud Integration
1. Log in to [sonarcloud.io](https://sonarcloud.io/) using your GitHub account.
2. Import your GitHub repository into SonarCloud.
3. For each of the 11 projects (Frontend, API Gateway, and 9 microservices), **disable Automatic Analysis** in the SonarCloud project settings (analysis is executed inside the GitHub Action runner).
4. Each service directory contains a `sonar-project.properties` file defining its project key (`docbridge_service-name`) and source patterns.

### 15.4. Snyk Integration
1. Register a free account at [app.snyk.io](https://app.snyk.io/).
2. Copy your API token to the `SNYK_TOKEN` repository secret.
3. Snyk vulnerability checks run during the `build` pipeline stage and export an HTML results report as a GitHub Actions run artifact (available for 30 days). Findings do not block the pipeline.

### 15.5. Pipeline Flow & Triggers

- **Terraform Infrastructure Pipeline** (`infra-terraform.yml`):
  - Triggers automatically on push/PR modifying files under `terraform/`.
  - Manual trigger via `workflow_dispatch` allows running a `plan`, `apply`, or `destroy` action.
  - Applying or destroying infrastructure triggers the `production` environment review gate, requiring manual approval in the GitHub UI before proceeding.
- **Application CI/CD Pipeline** (`cicd-application.yml`):
  - Triggers automatically on push/PR modifying files under `services/`, `gateway/`, `frontend/`, `database/`, or `helm/`.
  - Performs path filtering to run stages (SonarCloud quality gates, Snyk SCA, Docker pushes, Approval gates, and Helm deploys) for changed services only.
  - Manual trigger via `workflow_dispatch` allows forcing deployment of a specific service or all services.

### 15.6. Database Migrations Pipeline Hook
When database schemas (`database/migrations/` or `database/seeders/`) are changed:
1. The pipeline automatically builds and pushes a new `db-migrations:latest` image to ACR.
2. This image is automatically pulled and run by the pre-upgrade Helm hook during any subsequent microservice deployment.
3. No manual migration commands are required.

