# Harbor

## What is Harbor?

> Harbor is an open-source container image registry that secures images with role-based access control, scans images
> for vulnerabilities, and signs images as trusted. As a CNCF Graduated-level project, Harbor delivers compliance,
> performance, and interoperability to help you consistently and securely manage images across cloud-native compute
> platforms like Kubernetes and Docker.

*source: [goharbor.io](https://goharbor.io/)*

## Image repository and tag

* Harbor images synced from DockerHub to [Sighup Registry](https://registry.sighup.io/account/sign-in?globalSearch=goharbor):
  * goharbor/trivy-adapter-photon:v2.13.2
  * goharbor/harbor-core:v2.13.2
  * goharbor/harbor-db:v2.13.2
  * goharbor/harbor-jobservice:v2.13.2
  * goharbor/harbor-portal:v2.13.2
  * goharbor/redis-photon:v2.13.2
  * goharbor/registry-photon:v2.13.2
  * goharbor/harbor-registryctl:v2.13.2
  * goharbor/harbor-exporter:v2.13.2
* Custom images:
  * fury/goharbor/trivy-adapter-photon-offline:v2.13.2
* Harbor repository: [https://github.com/goharbor/harbor](https://github.com/goharbor/harbor)

## Distributions

* [full-harbor](distributions/full-harbor):
  * All components deployed together without external dependencies.
  * Requires a default storage class configured as all the components rely on persistent volumes to store data.
  * Requires cert-manager and ingress controller
  * Only tested against public endpoints with valid certificates.
  * Uses Trivy as default interrogation service
  * To avoid Github rate limits, we include a [custom image of Trivy](https://github.com/sighupio/container-image-sync/blob/main/modules/registry/custom/trivy-adapter-photon-offline/Dockerfile)
    which is built every night with the latest vulnerability DB.
  * See more in the [example](../../examples/full-harbor/)
* [harbor-without-psql](distributions/harbor-without-psql):
  * Same as above, with the exception of `harbor-db` which will not be included.
  * An external DB must already exist and you must provide credentials using Kustomize patches 
  * See more in the [example](../../examples/external-db/)

## License

For license details please see [LICENSE](../../LICENSE)
