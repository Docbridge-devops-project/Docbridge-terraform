# DocBridge - Infrastructure Repository (Terraform)

This repository contains all the Infrastructure as Code (IaC) written in Terraform to build and configure the Azure cloud services for the DocBridge platform.

- Application Code: [DocBridge-application](../DocBridge-application)
- Kubernetes Config & Charts: [DocBridge-kubernetes](../DocBridge-kubernetes)

## Infrastructure Overview

DocBridge is deployed inside a hub-and-spoke Virtual Network architecture in Microsoft Azure, routing all external traffic securely via Azure Application Gateway (WAF) into an Azure Kubernetes Service (AKS) cluster.

```
       +---------------------------------------------+
       |                  VNet                       |
       |  +------------------+   +----------------+  |
       |  |  AppGateway Sub. |   |   AKS Subnet   |  |
Client -> |  AppGateway WAF  | ->|  AKS Cluster   |  |
       |  +------------------+   +-------+--------+  |
       |                                 |           |
       |  +------------------+           v           |
       |  |  Private Subnet  | -> Private Endpoints  |
       |  |  DB, Key Vault   |    to Managed Services|
       |  +------------------+                       |
       +---------------------------------------------+
```

### Azure Resources Created

1. **Virtual Network & Subnets**: Networking hub providing separation of public-facing endpoints (App Gateway) and private workloads (AKS nodes & pods).
2. **Azure Kubernetes Service (AKS)**: Node Pools with autoscaling enabled to host containerized microservices.
3. **Azure Container Registry (ACR)**: Private registry storing scanned Docker images.
4. **PostgreSQL Flexible Server**: Scalable managed database running inside a private subnet.
5. **Azure Service Bus**: Asynchronous message broker for event-driven microservice orchestration.
6. **Azure Key Vault**: Stores credentials and encryption keys, exposed to AKS pods via CSI Secret Provider.
7. **Application Insights & Log Analytics**: Unified logging, metrics compilation, and alerting dashboard.
8. **Azure Storage Account**: Hosts remote terraform state files with state locking via blob lease.

## Module Structure

The code is organized into modular directories:
- `modules/networking`: Virtual network, subnets, NSGs, and Private DNS zones.
- `modules/aks`: AKS Cluster v1.29, User Node Pool configuration, and Federated credentials.
- `modules/acr`: Azure Container Registry.
- `modules/keyvault`: Key Vault and Private Endpoints.
- `modules/database`: PostgreSQL Flexible Server and private DB configurations.
- `modules/servicebus`: Azure Service Bus namespace and queues.
- `modules/monitoring`: Log Analytics workspace and Application Insights.
- `modules/security`: Resource locks, audit logs, and IAM roles.

## Local Execution (Bootstrap steps)

To initialize and deploy infrastructure from your local machine:

1. Log in to Azure CLI:
   ```bash
   az login
   ```
2. Configure your local variables inside a `secrets.tfvars` file or supply them via environment variables.
3. Initialize the backend:
   ```bash
   terraform init -backend-config="resource_group_name=docbridge-rg" \
                  -backend-config="storage_account_name=<your_storage_account>" \
                  -backend-config="container_name=tfstate" \
                  -backend-config="key=dev.terraform.tfstate"
   ```
4. Generate and review execution plan:
   ```bash
   terraform plan -var-file="secrets.tfvars"
   ```
5. Apply resources:
   ```bash
   terraform apply -var-file="secrets.tfvars" -auto-approve
   ```

## Remote State Locking & Recovery

State locking is automatically handled by the Azure Storage backend. If an apply fails or the pipeline terminates abruptly, the state lock might remain active. To recover:
1. Identify the lease ID of the lock.
2. Run `terraform force-unlock <LOCK_ID>` or break the lease directly in the Azure Portal Storage Explorer.
3. Always verify state integrity using `terraform refresh` before running another plan.

## OIDC & Federated Credentials

All GitHub workflows in this repository authenticate to Azure using OpenID Connect (OIDC), removing the need for static Service Principal credentials.

> [!WARNING]
> If the repository moves or its path is modified, you MUST update the Federated Identity Credentials on the Azure Active Directory Service Principal, or the GitHub Action runners will fail to log in.

### Updating OIDC Subjects

Run the following commands using the Azure CLI to delete old credentials and create new ones for the reorganized repositories:

```bash
# Set SP Client ID and retrieve object ID
SP_CLIENT_ID="b584e603-090f-43f6-aa38-6da7b409a84a"
APP_OBJECT_ID=$(az ad app show --id $SP_CLIENT_ID --query id -o tsv)

# Delete old credentials from single-repository setup
az ad app federated-credential delete \
  --id $APP_OBJECT_ID \
  --federated-credential-id "docbridge-gha-main" 2>/dev/null || true

az ad app federated-credential delete \
  --id $APP_OBJECT_ID \
  --federated-credential-id "docbridge-gha-pr" 2>/dev/null || true

# Create credentials for DocBridge-application
az ad app federated-credential create \
  --id $APP_OBJECT_ID \
  --parameters '{
    "name": "docbridge-app-main",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:Docbridge-devops-project/DocBridge-application:ref:refs/heads/main",
    "audiences": ["api://AzureADTokenExchange"]
  }'

az ad app federated-credential create \
  --id $APP_OBJECT_ID \
  --parameters '{
    "name": "docbridge-app-pr",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:Docbridge-devops-project/DocBridge-application:pull_request",
    "audiences": ["api://AzureADTokenExchange"]
  }'

# Create credentials for DocBridge-terraform
az ad app federated-credential create \
  --id $APP_OBJECT_ID \
  --parameters '{
    "name": "docbridge-tf-main",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:Docbridge-devops-project/DocBridge-terraform:ref:refs/heads/main",
    "audiences": ["api://AzureADTokenExchange"]
  }'

az ad app federated-credential create \
  --id $APP_OBJECT_ID \
  --parameters '{
    "name": "docbridge-tf-pr",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:Docbridge-devops-project/DocBridge-terraform:pull_request",
    "audiences": ["api://AzureADTokenExchange"]
  }'

# Verify credentials list
az ad app federated-credential list --id $APP_OBJECT_ID \
  --query "[].{name:name,subject:subject}" --output table
```

## Required GitHub Secrets

Configure the following secrets in GitHub to run the Infrastructure pipeline:

| Secret Name | Description |
|---|---|
| `AZURE_CLIENT_ID` | Client ID of the Azure AD Service Principal |
| `AZURE_TENANT_ID` | Active Directory Tenant ID |
| `AZURE_SUBSCRIPTION_ID`| Subscription ID target |
| `TF_STORAGE_ACCOUNT_NAME`| Remote state storage account name |
| `TF_CONTAINER_NAME` | Storage container name |
| `DB_PASSWORD` | PostgreSQL Flexible Server root password |
| `JWT_ACCESS_SECRET` | Auth secret for access tokens |
| `JWT_REFRESH_SECRET` | Auth secret for refresh tokens |
| `AZURE_OPENAI_KEY` | API Key for Azure OpenAI cognitive resource |
| `ALERT_EMAIL` | DevOps email target for failure alerts |
| `SMTP_USERNAME` | SMTP sending address |
| `SMTP_PASSWORD` | App Password for Gmail SMTP account |

## Infrastructure Destruction Protection

To prevent accidental destruction of production infrastructure, the `terraform-destroy` job is guarded:
1. It is only accessible via manual `workflow_dispatch` with input `action = destroy`.
2. It triggers a `destroy-approval-gate` job that halts the run and requires a manual approval signature inside the GitHub UI.
3. It sends a strong warning email to the DevOps alert address listing all resources queued for deletion.

## Cost Estimation Breakdown

The monthly estimated cost for running the DocBridge infrastructure is detailed below:

```hcl
estimated_monthly_cost_note = {
  aks_system_nodes    = "~$70/month per Standard_D2s_v3 node"
  aks_app_nodes       = "~$70/month per Standard_D2s_v3 node"
  postgresql          = "~$13/month Burstable B2s"
  app_gateway_waf     = "~$40/month Standard_v2"
  acr_basic           = "~$5/month Basic SKU"
  key_vault           = "~$1/month Standard SKU"
  storage_accounts    = "~$3/month"
  service_bus         = "~$1/month Basic SKU"
  log_analytics       = "~$0-5/month first 5GB free"
  total_estimate      = "~$200-250/month"
}
```

## Branching Strategy & Protection Rules

### Strategy

- `main`: Production-ready, stable state. Direct push disabled. All changes must be made via PR.
- `develop`: Integration branch.
- Feature branches `feature/*` branch off `develop`.

### Branch Protection Rules for main

1. Require Pull Request before merging.
2. Require at least 1 approving review.
3. Dismiss stale reviews when new commits are pushed.
4. Require status checks to pass before merge (`terraform-check` which validates formatting and syntax).
5. Restrict force pushes and branch deletions.
