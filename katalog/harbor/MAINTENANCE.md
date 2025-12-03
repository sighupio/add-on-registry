# Development notes

## How to update

Harbor distributes itself as a Helm chart.

### Look for the target version

Search the Chart version that you'll need with

```bash
helm repo add harbor https://helm.goharbor.io
helm repo update
helm search repo harbor/harbor --versions
```

### Verify the upstream values.yaml

Check that the `values.yaml` file differs from the `MAINTENANCE.values.yaml` only for expected changes. If the upstream `values.yaml` contains new parameters, copy them into the `MAINTENANCE.values.yaml`.

```bash
VERSION=v1.18.0 # v2.14.0

curl "https://raw.githubusercontent.com/goharbor/harbor-helm/refs/tags/${VERSION}/values.yaml" -o upstream.values.yaml
```

Known customizations are:

- `caSecretName: "core-root-ca"`
- `core.secretName: "core-root-ca"`
- `expose.tls.certSource: secret`
- `expose.tls.secret.secretName: "harbor-ingress-cert"`
- `expose.ingress.annotations.cert-manager.io/cluster-issuer: "letsencrypt-staging"`
- `imagePullPolicy: Always`
- `metrics.enabled: true`
- `metrics.serviceMonitor.enabled: true`
- `trivy.skipUpdate: true`
- `trivy.skipJavaDBUpdate: true`
- `trivy.offlineScan: true`
- all `resources` for various components

### Download and template the Helm Chart

```bash
VERSION=v1.18.0 #v2.14.0
HARBOR_VERSION=v2.14.0
rm -rf vendor
helm template harbor harbor/harbor --version $VERSION -f MAINTENANCE.values.yaml --output-dir vendor
for file in $(find ./vendor -type f \( -name "*.yaml" -o -name "*.yml" \)); do
  yq -i 'del(.metadata.labels, .spec.selector, .spec.template.metadata, .metadata.namespace)' $file
done
curl "https://raw.githubusercontent.com/goharbor/harbor/refs/tags/${HARBOR_VERSION}/contrib/grafana-dashboard/metrics-example.json" \
  | yq '
    (.panels | .. | select(has "targets") | .. | select(has("expr")).expr) |=
      sub("service=~\"harbor-\\.\\*\"", "job=\"harbor\""
    )' -ojson > exporter/dashboards/harbor-general.json
```

### Check the diff and update the images

At this point you should check the differences and adapt them. Keep in mind that you will probably need to update images in the SIGHUP registry.

The Helm chart generates the same foldering that we maintain, so you will need to compare manifests inside each folder.

#### General notes

- we prefer to generate secrets and configmaps using Kustomize generators
- we delete all labels from the upstream-generated manifests and set them with Kustomize, with the exception of some CustomResource ( es. ServiceMonitor ) or fields ( volumeClaimTemplates ) 
- we rewrite all images and tags using Kustomize, pointing to our registry - remember to pull new images!
- we stripped all of the resources from the Helm Chart's release Name prefix, which is "harbor-" by default ( es. "harbor-core" and "harbor-registry" Deployment and ConfigMap become "core" and "registry" in our manifests ). Remember to change accordingly both the resources' names, and the configurations that reference them!

#### Config maps

We generate CMs using Kustomize's `configMapGenerator`, so you will need to port all Helm configmaps into each `kustomization.yaml`.

We also prefer to use the `files` options when possible (e.g.: in `portal` the `nginx.conf` is placed inside `config/nginx.conf` and imported in the CM with Kustomize)

### Secrets

- the `JOBSERVICE_SECRET` key has been renamed to `secret` inside the `jobservice` secret

### Service monitor manifests

The service monitor manifests `katalog/harbor/exporter/sm.yml` file will be found at `vendor/metrics/metrics-svcmon.yaml`, as usual check for differences.

Once deployed, you will be able to find a `serviceMonitor` Prometheus Operator resources. It is required to allow prometheus to fetch the metrics exposed by Harbor

### Ingress manifest

The Ingress manifest `katalog/harbor/distributions/common/ingress.yml` will be found at `vendor/ingress/ingress.yaml`, as usual check for differences.

### Demos / Testing

All the following examples are tested in the pipeline

### e2e tests

- [setup](../../katalog/tests/harbor/setup.sh)
- [vulns](../../katalog/tests/harbor/vulns.sh)
- [replication](../../katalog/tests/harbor/replication.sh)
- [registry](../../katalog/tests/harbor/registry.sh)

### Dashboard and Rules

#### Grafana Dashboards

The Grafana dashboard found in `katalog/harbor/exporter/dashboards` was taken from:

- [Harbor Metrics](https://github.com/goharbor/harbor/blob/main/contrib/grafana-dashboard/metrics-example.json)

Compared to the official dashboards, the following changes have been made:

- renamed the variable from `DS_PROMETHEUS` to `datasource`
- added the `harbor` tag to the dashboards
- added "Legend" on all gadgets

#### Prometheus Rules

Harbor upstream does not provide a set of Prometheus Rules that we could include.
The Prometheus Rules defined in `katalog/harbor/exporter/rules.yml` are copied from:
<https://github.com/sysdiglabs/promcat-resources/blob/master/resources/harbor/alerts-v2.2.yaml>

> [!WARNING]
>
> The promcat-resources repo has been unmantained for 2+ years.
> Even though the Rules are working correctly, we might want to open a PR to the upstream project that we use for other systems' rules,  
> <https://github.com/samber/awesome-prometheus-alerts>, which is more actively maintained.

Once deployed, you will be able to find some `Alert`s defined on the Prometheus dashboard.

To export the list of alerts from the YAML file to include them in the readme you can use the following command:

```bash
yq e '.spec.groups[] | .rules[] |  "| " + .alert + " | " + (.annotations.summary // "-" | sub("\n",". "))+ " | " + (.annotations.description // "-" | sub("\n",". ")) + " |"' katalog/harbor/exporter/rules.yml
```

### Trivy Database Update Offline

The trivy configuration has been updated to download the new image with the updated vulnerability database every night. To do this we have added: [an image that is built every night](https://github.com/sighupio/container-image-sync/blob/main/modules/registry/custom/trivy-adapter-photon-offline/Dockerfile), an ad-hoc rbac and a cronjob to restart the pod. The new image is downloaded from the following [repository](https://registry.sighup.io/harbor/projects/37/repositories/goharbor%2Ftrivy-adapter-photon-offline/artifacts-tab?publicAndNotLogged=yes).
