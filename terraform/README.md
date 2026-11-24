### Terraform — Validation and Planning

**Prerequisites:**
- Terraform CLI installed.
- Google Cloud CLI (`gcloud`) installed.
- Access to a valid GCP project with appropriate IAM permissions.
- Application Default Credentials (ADC) configured.

**Authenticate with Google Cloud:**

```bash
gcloud auth application-default login
```

For environments without a directly accessible browser:

```bash
gcloud auth application-default login --no-launch-browser
```

**Initialize and validate the Terraform configuration:**

```bash
terraform init
terraform fmt -check
terraform validate
terraform plan
```

The configuration uses placeholder project identifiers. Replace these with valid GCP project values before running a live plan.

**Note:** `terraform plan` previews proposed infrastructure changes without deploying resources. A successful plan does not guarantee that deployment will succeed.

Running `terraform apply` is not required for this assignment.