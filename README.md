# AWS Infra Setup

Terraform repo for my personal projects.

Directory Structure:

- `envs/<deploy_env>`: Terraform configuration for *deploy_env*. Backend is configured to use s3; see `<env>-config.tfvars` file.

- `modules`:
   - `apps/<app>`: Contains resources for each project *app*.
   - Other sub-dirs contain resources independent of projects.

## How to run

Example to deploy resources in *dev* env:

```
$ cd envs/dev

$ terraform init -backend-config=dev-config.conf

$ terraform plan -var-file=dev.tfvars -out=output/plan.out   # see dev-template.tfvars

$ terraform apply output/plan.out
```
  