# Development notes

## How to update

Harbor distributes itself as a Helm chart.

### Look for the target version

Search the Chart version that you'll need with

```bash
helm repo add harbor https://helm.goharbor.io
helm search repo harbor/harbor --versions
```

### Download and template the Helm Chart

```bash
VERSION=v1.15.2 #v2.11.2
rm -rf vendor
helm template harbor harbor/harbor --version $VERSION --set "metrics.enabled=true" --set "metrics.serviceMonitor.enabled=true" --output-dir vendor
```

### Check the diff and update the images

At this point you should check the differences and adapt them. Keep in mind that you will probably need to update images in the SIGHUP registry.

The Helm chart generates the same foldering that we maintain, so you will need to compare manifests inside each folder.

#### Config maps

We generate CMs sing Kustomize's `configMapGenerator`, so you will need to port all Helm configmaps into each `kustomization.yaml`.

## Service monitor manifests

The service monitor manifests `katalog/harbor/exporter/sm.yml` file will be found at `vendor/metrics/metrics-svcmon.yaml`, as usual check for differences.

Once deployed, you will be able to find a `serviceMonitor` Prometheus Operator resources. It is required to allow prometheus to fetch the metrics exposed by Harbor

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

- [Harbor Metrics](https://github.com/goharbor/harbor/blob/main/contrib/grafana-dashborad/metrics-example.json)

Compared to the official dashboards, the following changes have been made:

- renamed the variable from `DS_PROMETHEUS` to `datasource`
- added the `harbor` tag to the dashboards
- added "Legend" on all gadgets

#### Prometheus Rules

Harbor upstream does not provide a set of Prometheus Rules that we could include.
The Prometheus Rules defined in `katalog/harbor/exporter/rules.yml` are inspired by those provided by:
<https://promcat.io/apps/harbor>

Once deployed, you will be able to find some `Alert`s defined on the Prometheus dashboard.

To export the list of alerts from the YAML file to include them in the readme you can use the following command:

```bash
yq e '.spec.groups[] | .rules[] |  "| " + .alert + " | " + (.annotations.summary // "-" | sub("\n",". "))+ " | " + (.annotations.description // "-" | sub("\n",". ")) + " |"' katalog/harbor/exporter/rules.yml
```

### Trivy Database Update Offline

The trivy configuration has been updated to download the new image with the updated vulnerability database every night. To do this we have added: [an image that is built every night](https://github.com/sighupio/container-image-sync/blob/main/modules/registry/custom/trivy-adapter-photon-offline/Dockerfile), an ad-hoc rbac and a cronjob to restart the pod. The new image is downloaded from the following [repository](https://registry.sighup.io/harbor/projects/37/repositories/goharbor%2Ftrivy-adapter-photon-offline/artifacts-tab?publicAndNotLogged=yes).
