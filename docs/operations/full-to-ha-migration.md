# Harbor Full to HA Migration Guide

This guide provides detailed instructions for migrating a Harbor container registry from the "full" deployment (with in-cluster PostgreSQL and Redis) to the "HA" (High Availability) deployment using external managed services.

## Overview

### Architecture Comparison

**Full Harbor Stack:**

- PostgreSQL and Redis run as StatefulSets inside the Kubernetes cluster
- Container images stored on filesystem PersistentVolume
- Single replica for all components
- Suitable for development and testing environments

**Harbor HA Stack:**

- External PostgreSQL database (e.g., CloudNativePG, managed RDS)
- External Redis instance (with optional Sentinel support)
- S3-compatible object storage for container images
- Multiple replicas for all Harbor components
- Production-grade reliability and scalability

### Benefits of HA Architecture

- **Scalability**: External database and object storage can scale independently
- **Reliability**: Managed services provide automated backups and failover
- **Performance**: Object storage optimized for large artifacts, database optimized for metadata queries
- **Operational simplicity**: Offload database and cache management to specialized services
- **Disaster recovery**: Leverage managed service backup and restore capabilities

## Prerequisites

Before starting the migration, ensure the following are in place:

### 1. Existing Full Harbor Installation

- Harbor "full" stack deployed and running - take note of the namespace (default: `registry`)
- Full access to Harbor admin credentials and internal Postgres credentials

> [!WARNING]
>
> The existing "full" stack and the new "HA" stack **MUST** use the same Harbor minor version.

### 2. External Services Provisioned

**PostgreSQL Database:**

- CloudNativePG cluster or managed PostgreSQL instance
- PostgreSQL 12+ recommended
- Network connectivity from Kubernetes cluster
- Database credentials available

**Redis Instance:**

- Standalone Redis or Redis with Sentinel
- Network connectivity from Kubernetes cluster
- Redis credentials available (if authentication enabled)

> [!WARNING]
> Redis Sentinel with password authentication has known compatibility issues with Harbor. You can configure password authentication for Redis itself, not for Sentinel. Verify compatibility with your Harbor version. We also [opened an issue upstream about this](https://github.com/goharbor/harbor/issues/22538).

**S3-Compatible Object Storage:**

- AWS S3, MinIO, or compatible service
- Bucket created and accessible from cluster
- IAM credentials with read/write permissions

### 3. Kubernetes Requirements

- `kubectl` configured with cluster access
- Sufficient cluster resources for parallel Harbor instances

## Migration Approach: read-only maintenance mode

During the migration process, Harbor is set to **read-only mode** to ensure consistency. Users can pull images but cannot push during the migration window.

> [!NOTE]
>
> Notify your users of this maintenace window. Take your time.

**Characteristics:**

- Lower risk of data inconsistency
- Minimal service interruption (typically 15-30 minutes)
- Push operations blocked during migration

## Migration Steps

> [!WARNING]
>
> Read carefully the whole procedure **BEFORE** attempting the migration.

### Step 1: Prepare Migration Environment

#### 1.1 Set Harbor to Read-Only

> [!WARNING]
>
> This step blocks push operations. Communicate maintenance window to users before proceeding.

Set Harbor to read-only mode via Harbor admin UI: Configuration > System Settings > Click on the Read Only checkbox and save.

Alternatively, use the Harbor API:

```bash
# Get current config
curl -k -u "admin:<PASSWORD>" https://harbor.example.com/api/v2.0/configurations

# Set read-only mode
curl -k -u "admin:<PASSWORD>" -X PUT \
  https://harbor.example.com/api/v2.0/configurations \
  -H "Content-Type: application/json" \
  -d '{"read_only": true}'
```

#### 1.2 Create Folder Structure

We will work with a folder structure like the following:

```plaintext
.
└── add-on-registry
    ├── examples
    │   ├── full-to-ha-migration
    │   └── harbor-ha
    └── katalog
        └── harbor
            ├── core
            ├── distributions
            │   ├── common
            │   └── harbor-ha
            ├── exporter
            ├── jobservice
            ├── portal
            ├── registry
            └── trivy
```

To create it, run:

```bash
ADD_ON_VERSION=v3.4.0 # check latest add-on version
kustomize localize "https://github.com/sighupio/add-on-registry//examples/full-to-ha-migration?ref=${ADD_ON_VERSION}" add-on-registry
cd add-on-registry
# Download the migration manifests
FILES=(
  "00-env-secret.yaml"
  "01-pvc-backup.yaml"
  "02-job-dump.yaml"
  "03-job-restore.yaml"
  "04-skopeo-migration.yaml"
)
mkdir -p examples/full-to-ha-migration

for file in "${FILES[@]}"; do
  echo $file
  curl "https://raw.githubusercontent.com/sighupio/add-on-registry/${ADD_ON_VERSION}/examples/full-to-ha-migration/${file}" -o "examples/full-to-ha-migration/${file}"
done
```

#### 1.3 Customize Migration Secret

Edit the `examples/full-to-ha-migration/00-env-secret.yaml` file to match your environment:

```bash
# Edit the secret with actual values
# Replace ALL placeholders marked with %...%
vi examples/full-to-ha-migration/00-env-secret.yaml
```

**Required customizations:**

| Variable          | Description                         | Example                                      |
| ----------------- | ----------------------------------- | -------------------------------------------- |
| `SRC_DB_PASSWORD` | Password for full Harbor PostgreSQL | `changeit`                                   |
| `SRC_DB_USER`     | User for full Harbor PostgreSQL     | `postgres`                                   |
| `SRC_DB_HOST`     | Full Harbor database service        | `database.registry.svc.cluster.local`        |
| `SRC_DB_NAME`     | Full Harbor database name           | `registry`                                   |
| `SRC_URL`         | Full Harbor ingress hostname        | `harbor.example.com`                         |
| `SRC_CREDS`       | Full Harbor admin credentials       | `admin:Harbor12345`                          |
| `DST_DB_PASSWORD` | External PostgreSQL password        | `newchangeit`                                |
| `DST_DB_USER`     | External PostgreSQL user            | `harbor`                                     |
| `DST_DB_HOST`     | External PostgreSQL hostname        | `harbor-db-rw.cnpg-system.svc.cluster.local` |
| `DST_DB_NAME`     | External PostgreSQL database name   | `harbor`                                     |
| `DST_URL`         | Temporary HA Harbor hostname        | `harbor-new.example.com`                     |
| `DST_CREDS`       | HA Harbor admin credentials         | `admin:SecurePassword123`                    |

**Apply the secret:**

```bash
# This is optional but adviced
kubectl create namespace harbor-migration

kubectl apply -n harbor-migration -f examples/full-to-ha-migration/00-env-secret.yaml
```

### Step 3: Database Migration

#### 3.1 Create Backup Storage

```bash
# This provisions a 5Gi PVC to hold the DB dump - double check if it is sufficient
kubectl apply -n harbor-migration -f examples/full-to-ha-migration/01-pvc-backup.yaml

# Verify PVC is bound
kubectl get pvc -n harbor-migration harbor-db-backup-pvc
```

#### 3.2 Dump Full Harbor Database

```bash
# Start the database dump job
kubectl apply -n harbor-migration -f examples/full-to-ha-migration/02-job-dump.yaml

# Monitor dump progress
kubectl logs -n harbor-migration -f job/harbor-db-dump

# Expected output:
# Starting dump of external Harbor DB...
# [pg_dump verbose output]
# Dump complete, saved to /backup/harbor-final.dump
```

**Verify dump completion:**

```bash
# Check job status
kubectl get job -n harbor-migration harbor-db-dump

# Should show COMPLETIONS: 1/1
```

> [!WARNING]
> Do not proceed if dump job fails. Check logs for errors and verify database connectivity.

#### 3.3 Restore to External Database

> [!WARNING]
> The restore job uses `pg_restore --clean --if-exists`, which drops existing objects in the target database. Ensure the target database is empty or contains only test data.

```bash
# Start the restore job
kubectl apply -n harbor-migration -f examples/full-to-ha-migration/03-job-restore.yaml

# Monitor restore progress
kubectl logs -n harbor-migration -f job/harbor-db-restore

# Expected output:
# Starting restore to CloudNativePG...
# [pg_restore verbose output]
# Restore complete.
```

> [!INFO]
> If the owner of the Harbor database in the "full" stack was a different user than the one used in the "HA" stack, you might receive a line at the end of the restore logs with something like:
>
> ```plaintext
> pg_restore: warning: errors ignored on restore: 95
> ```
>
> This is not an issue, you can proceed with the rest of the steps.

**Verify restore:**

```bash
# Check job status
kubectl get job -n harbor-migration harbor-db-restore

# Connect to external database and verify tables
# If the terminal prints a line like "If you don't see a command prompt, try pressing enter", you can enter the User password and press enter 
kubectl run -it --rm psql-verify --image=postgres:17 --restart=Never -- \
  psql -h <NEW_DB_HOST> -U <NEW_DB_USER> -d <NEW_DB_NAME> -c "\dt"

# Should show Harbor tables: project, repository, artifact, etc.
```

### Step 4: Deploy Harbor HA in Temporary Namespace

Deploy Harbor HA in a new namespace for validation before final cutover.

#### 4.1 Customize HA Configuration

Follow [`harbor-ha`'s README](../../examples/harbor-ha/README.md) to know how to customize this add-on to fit your environment. You will need to edit files inside `examples/harbor-ha`.

> [!WARNING]
> the `CORE_SECURE_SECRET` and `CORE_SECURE_KEY` parameters **MUST** be exactly the same as the "full" Harbor stack.

Additionally, update `examples/harbor-ha/patch/ingress.yml`:

```yaml
- op: replace
  path: /spec/rules/0/host
  value: harbor-new.example.com  # Temporary hostname
```

and update the `EXT_ENDPOINT` variable in the `examples/harbor-ha/kustomization.yaml` file accordingly.

Also, set a temporary namespace as target:

```bash
pushd examples/harbor-ha/
kustomize edit set namespace registry-new
popd
```

#### 4.2 Deploy Harbor HA

```bash
# Apply the HA configuration
kustomize build examples/harbor-ha | kubectl apply -f - --server-side

# Monitor deployment
kubectl get pods -n registry-new -w

# Wait for all pods to be ready
kubectl wait --for=condition=ready pod -l app=harbor -n registry-new --timeout=600s
```

#### 4.3 Validate HA Deployment

```bash
# Check all components are running
kubectl get all -n registry-new

# Test Harbor web UI access
curl -k https://harbor-new.example.com/api/v2.0/systeminfo

# Log in to Harbor UI at https://harbor-new.example.com
# Verify projects and repositories are visible (metadata migrated)
```

> [!INFO]
> At this stage, you should see all projects and repositories in the Harbor UI, but image pulls will fail because the actual image layers have not been migrated to S3 yet.

#### 4.4 Disable Read-only in the new registry

To enable the copy of images from the "full" Harbor to the "HA" Harbor, you need to disable Read-only mode in the "HA" Harbor.

> [!WARNING]
> It is key to be careful in this simple passage, because mistakenly disabling read-only mode in the old Harbor could make all the effort made so far basically useless.

You can disable Read-only via Harbor admin UI: Configuration > System Settings > Un-check the Read Only checkbox and save.

Alernatively, via API:

```bash
# Disable read-only mode via API
curl -k -u "admin:<PASSWORD>" -X PUT \
  https://harbor-new.example.com/api/v2.0/configurations \
  -H "Content-Type: application/json" \
  -d '{"read_only": false}'
```

### Step 5: Migrate Container Images

Use Skopeo to copy all container images from the old registry to the new one.

#### 5.1 Start Image Migration

You can use [Harbor's Replication feature](https://goharbor.io/docs/2.14.0/administration/configuring-replication/create-replication-endpoints/) to migrate all images from the old registry to the HA one.

##### Alternative approach

If, for some reason, it fails to migrate images uysing Replications, you could also use the `04-skopeo-migration.yaml` manifest to trigger a more manual approach:

```bash
# Apply skopeo migration job
kubectl apply -f -n harbor-migration examples/full-to-ha-migration/04-skopeo-migration.yaml

# Monitor migration progress
kubectl logs -f job/skopeo-migration
```

**Expected output:**

```plaintext
Installing utilities...
=== Discovering projects from harbor.example.com ===
--- Project: library ---
[START] library/nginx
migrating library/nginx:latest
...
=== Migration completed ===
--- Successful repositories ---
[OK] library/nginx:latest
...
--- Failed repositories ---
cat: /report/fail.log: No such file or directory
```

> [!NOTE]
> Depending on the cardinality of the images to be migrated and their size, this operation can take a while.
>
> The default configuration of the Job has a parallelism of 4 concurrent copies. You can edit that by downloading the Job manifest and setting the `CONCURRENCY` env variable to something else before applying it.

The Job runs with 4 parallel workers by default. For large registries:

```bash
# Check current progress (success/fail counts)
kubectl exec job/skopeo-migration -- cat /report/success.log | wc -l
kubectl exec job/skopeo-migration -- cat /report/fail.log | wc -l

# View failed migrations (if any)
kubectl exec job/skopeo-migration -- cat /report/fail.log
```

**Troubleshooting failed images:**

If some images fail to migrate:

1. Check the failure logs for error messages
2. Verify network connectivity to both registries
3. Check credentials are correct
4. Verify that image layers are actually available in the old registry
5. Check old Harbor's components logs
6. Retry individual images manually:

```bash
skopeo copy --all \
  --src-creds "admin:OldPassword" \
  --dest-creds "admin:NewPassword" \
  docker://harbor.example.com/project/image:tag \
  docker://harbor-new.example.com/project/image:tag \
  --src-tls-verify=false \
  --dest-tls-verify=false
```

#### 5.3 Validate Image Migration

```bash
# List available tags for an image in both registries
skopeo list-tags docker://harbor.example.com/library/nginx --creds "admin:OldPassword" --tls-verify=false | jq -r '.Tags[]'
skopeo list-tags docker://harbor-new.example.com/library/nginx --creds "admin:NewPassword" --tls-verify=false | jq -r '.Tags[]'

# Compare image digest with old Harbor
skopeo inspect docker://harbor.example.com/library/nginx:latest | jq .Digest
skopeo inspect docker://harbor-new.example.com/library/nginx:latest | jq .Digest

# Test pulling from new registry
mkdir test-nginx-pull
skopeo copy docker://harbor-new.example.com/library/nginx:latest dir:test-nginx-pull --creds "admin:NewPassword" --tls-verify=false
ls -lah test-nginx-pull
rm -rf test-nginx-pull
```

### Step 6: Final Cutover to Production

After validating the temporary HA Harbor, perform the final cutover.

#### 6.1 Deploy HA Harbor in Production Namespace

> [!WARNING]
> This step will replace the existing "full" Harbor deployment. Ensure all validations in Step 4 and 5 are successful before proceeding.

```bash
# Update HA configuration for production ingress
vi examples/harbor-ha/patch/ingress.yml
# Change hostname to: harbor.example.com (original hostname)
vi examples/harbor-ha/kustomization.yaml
# update the EXT_ENDPOINT variable to: harbor.example.com (original hostname)

# Update kustomization namespace
pushd examples/harbor-ha
kustomize edit set namespace registry # or your production namespace
popd

# Apply HA Harbor in production namespace
# This will replace Deployments, Services, Ingress from full Harbor
kustomize build examples/harbor-ha | kubectl apply -f - --server-side

# Monitor rollout
kubectl rollout status deployment/core -n registry
kubectl rollout status deployment/registry -n registry
kubectl rollout status deployment/jobservice -n registry
```

**What happens:**

- HA Harbor Deployments/Services/Ingress replace full Harbor resources (due to name overlap)
- The old PostgreSQL and Redis StatefulSets remain running but unused
- Harbor is now accessible at the original hostname with HA backend

#### 6.2 Verify Production Cutover

```bash
# Test Harbor at original hostname
curl -k https://harbor.example.com/api/v2.0/systeminfo

# List available tags for an image
skopeo list-tags docker://harbor.example.com/library/nginx --creds "admin:NewPassword" --tls-verify=false | jq -r '.Tags[]'

# Test pulling an image
mkdir test-nginx-pull
skopeo copy docker://harbor.example.com/library/nginx:latest dir:test-nginx-pull --creds "admin:NewPassword" --tls-verify=false
ls -lah test-nginx-pull
rm -rf test-nginx-pull

# Log in to Harbor UI
# Verify all functionality: browse projects, push/pull images, vulnerability scanning
```

## Rollback Procedure

If critical issues are encountered during or after cutover:

### Immediate Rollback

If issues occur immediately after cutover:

```bash
# Restore full Harbor from your old Kustomize project
kustomize build /path/to/full/harbor | kubectl apply -f - --server-side

# Wait for pods to be ready
kubectl get pods -n registry -w

# Verify Harbor is accessible
curl -k https://harbor.example.com/api/v2.0/systeminfo
```

This works because you still have the old database's StatefulSet and PVC available in the cluster.

### Delayed Rollback (After cleanup)

If the old StatefulSets have been deleted:

```bash
# Recreate full Harbor
kustomize build /path/to/full/harbor | kubectl apply -f - --server-side
kubectl scale deployment -n registry core exporter jobservice portal registry --replicas 0 # scale down Harbor services
vi examples/full-to-ha-migration/00-env-secret.yaml # edit the credentials and endpoints of "DST" variables to point to the old database
kubectl apply -f examples/full-to-ha-migration/00-env-secret.yaml --server-side
# Restore database from migration backup
kubectl apply -f examples/full-to-ha-migration/02-job-restore.yaml
kubectl scale deployment -n registry core exporter jobservice portal registry --replicas 1 # scale back up Harbor services
```

### Data Recovery

If data loss is detected after migration:

1. Check migration backup PVC for database dump
2. Restore from external PostgreSQL backups (if available)
3. If you still have the old Harbor PVC and database dump, you can re-deploy the old Harbor, restore the DB and re-run this entire procedure.

## Post-Migration Cleanup

Verify that:

- Users, Projects, Repositories and other metadata are the same as before the migration
- Test the permissions of some users
- Test pushing and pulling images from CI systems

When you are confident that the environment is stable enough, you can delete the old resources and migration backup:

```bash
# Delete Database and Redis StatefulSets from old "full" Harbor
kubectl delete statefulset -n registry database redis

# Delete old PVCs (after backing up if needed)
kubectl get pvc -n registry
kubectl delete pvc -n registry data-database-0  # PostgreSQL data
kubectl delete pvc -n registry data-redis-0     # Redis data
kubectl delete pvc -n registry registry         # Old registry PVC

# Delete migration resources
kubectl delete job -n harbor-migration harbor-db-dump harbor-db-restore skopeo-migration
kubectl delete secret -n harbor-migration db-migration-env
kubectl delete pvc -n harbor-migration harbor-db-backup-pvc
```

> [!WARNING]
> Retain the migration PVC (`harbor-db-backup-pvc`) and the old registry PVC (`registry`) for at least 7 days after migration for disaster recovery purposes. You can use those to fully recover to the same state as before the migration.

If all went well, you can also delete the `examples/full-to-ha-migration` folder:

```bash
rm -rf examples/full-to-ha-migration
```

## Additional Resources

- [Harbor Official Documentation](https://goharbor.io/docs/)
- [Skopeo Documentation](https://github.com/containers/skopeo)
- [Harbor API Reference](https://goharbor.io/docs/latest/build-customize-contribute/configure-swagger/)
