# Harbor

## What is Harbor?

> Harbor is an open-source container image registry that secures images with role-based access control, scans images
> for vulnerabilities, and signs images as trusted. As a CNCF Graduated-level project, Harbor delivers compliance,
> performance, and interoperability to help you consistently and securely manage images across cloud-native compute
> platforms like Kubernetes and Docker.

*source: [goharbor.io](https://goharbor.io/)*

## Image repository and tag

All Harbor images are synced from [dockerhub](https://hub.docker.com/u/goharbor) into our [SIGHUP Registry](https://registry.sighup.io):

* Harbor images:
  * registry.sighup.io/fury/goharbor/harbor-core:v2.14.0
  * registry.sighup.io/fury/goharbor/harbor-db:v2.14.0
  * registry.sighup.io/fury/goharbor/harbor-jobservice:v2.14.0
  * registry.sighup.io/fury/goharbor/harbor-portal:v2.14.0
  * registry.sighup.io/fury/goharbor/redis-photon:v2.14.0
  * registry.sighup.io/fury/goharbor/registry-photon:v2.14.0
  * registry.sighup.io/fury/goharbor/harbor-registryctl:v2.14.0
  * registry.sighup.io/fury/goharbor/harbor-exporter:v2.14.0
* Custom images from [SIGHUP Registry]:
  * registry.sighup.io/fury/goharbor/trivy-adapter-photon-offline:v2.14.0 (uses the upstream `goharbor/trivy-adapter-photon` as base image)

## Distributions

* [full-harbor](distributions/full-harbor):
  * All components deployed together without external dependencies.
  * Requires a default storage class configured as all the components rely on persistent volumes to store data.
  * Requires cert-manager and ingress controller
  * Only tested against public endpoints with valid certificates.
  * Uses Trivy as default interrogation service
* [harbor-without-psql](distributions/harbor-without-psql/):
  * All components deployed together, except for the Postgres database
  * Requires to specify your own database connection information
  * Requires cert-manager and ingress controller
* [harbor-ha](distributions/harbor-ha/):
  * Deploys the Harbor components
  * Assumes the use of an S3-compatible object storage
  * Requires to specify your own database, Redis and object storage information
  * Requires cert-manager and ingress controller
  * All deployed components are stateless and do not require a storage class
  * All deployed components (except for the metrics exporter) are scaled to 2 replicas by default

You can see how to use them in the [examples](examples/).

## License

For license details please see [LICENSE](../../LICENSE)
