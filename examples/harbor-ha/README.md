# Harbor HA

This example deploys an Harbor instance with an High Availability configuration:

- External Postgres DB
- External Redis
- External Object Storage

## Usage

1. Clone this repository and enter in this folder in a terminal
2. Replace all configuration parameters as outlined below.
3. Run: `kustomize build . | kubectl apply -f - --server-side`

## Parameters

### Postgres DB

This setup assumes that you already have an existing Postgres instance and you want to use it with Harbor.

The parameters to be configured are:

| File                                  | String to be replaced     | Description                                                     | Example value                                  |
| ------------------------------------- | ------------------------- | --------------------------------------------------------------- | ---------------------------------------------- |
| `kustomization.yaml`                  | `%YOUR_DB_HOSTNAME%`      | The hostname of the DB                                          | `my-postgres.example.com`                      |
| `kustomization.yaml`                  | `%YOUR_DB_PORT%`          | The port on which the DB is listening                           | `5432`                                         |
| `kustomization.yaml`                  | `%YOUR_DB_USER%`          | The DB user to connect to the DB                                | `harbor`                                       |
| `kustomization.yaml`                  | `%YOUR_DB_PASSWORD%`      | The password for the DB user to connect to the DB               | `password`                                     |
| `kustomization.yaml`                  | `%YOUR_DB_NAME%`          | The DB name to be used with Harbor                              | `registry`                                     |

### Redis

This setup assumes that you already have an existing Redis instance and you want to use it with Harbor.

The parameters to be configured are:

> [!WARNING]
> As of Harbor 2.14.x, there is an issue with the Jobservice component of Harbor where a configuration with Redis Sentinel protected with a password
> (either on Sentinel only or both in Sentinel and Redis masters) is not working.
> The only way of working with an highly available Redis, for now, is to implement Sentinel without a password (you can still put a password on the Redis masters).
> We opened an [issue upstream](https://github.com/goharbor/harbor/issues/22538).

| File                                                                               | String to be replaced     | Description                                            | Example value                                                          |
| ---------------------------------------------------------------------------------- | ------------------------- | ------------------------------------------------------ | ---------------------------------------------------------------------- |
| `kustomization.yaml`, `config/jobservice/config.yml`                               | `%YOUR_REDIS_SCHEME%`     | Either `redis` or `redis+sentinel`                     | `redis+sentinel`                                                       |
| `kustomization.yaml`, `config/jobservice/config.yml`                               | `%YOUR_REDIS_PASSWORD%`   | The password for Redis.                                | `password`                                                             |
| `kustomization.yaml`, `config/jobservice/config.yml`, `config/registry/config.yml` | `%YOUR_REDIS_HOSTS%`      | The host list for Redis.                               | `redis-sentinel-0:26379,redis-sentinel-1:26379,redis-sentinel-2:26379` |
| `config/registry/config.yml`                                                       | `%YOUR_REDIS_MASTER_SET%` | The password for Redis.                                | `redisMaster`                                                          |

### Object Storage

This setup assumes that you want to store your artifacts in an external object storage to enable HA for the registry component.

The following table shows the needed parameters:

| File                         | String to be replaced               | Description                                             | Example value                    |
| ---------------------------- | ----------------------------------- | ------------------------------------------------------- | -------------------------------- |
| `config/registry/config.yml` | `%YOUR_OBJECT_STORAGE_REGION%`      | The region where your object storage resides            | `us-east-1`                      |
| `config/registry/config.yml` | `%YOUR_OBJECT_STORAGE_BUCKET%`      | The bucket name where you want to store artifacts       | `registry`                       |
| `config/registry/config.yml` | `%YOUR_OBJECT_STORAGE_ENDPOINT%`    | The endpoint where the object storage is reachable      | `https://myendpoint.example.com` |
| `config/registry/config.yml` | `%YOUR_OBJECT_STORAGE_SKIP_VERIFY%` | Wether to skip TLS certificate verification             | `true`/`false`                   |
| `config/registry/config.yml` | `%YOUR_OBJECT_STORAGE_HTTPS%`       | Wether to use HTTPS or not to reach your object storage | `true`/`false`                   |
| `kustomization.yaml`         | `%YOUR_OBJECT_STORAGE_ACCESSKEY%`   | The ACCESS_KEY for your object storage                  | `MYACCESSKEY`                    |
| `kustomization.yaml`         | `%YOUR_OBJECT_STORAGE_SECRETKEY%`   | The SECRET_KEY for your object storage                  | `MYSECRETKEY`                    |

### Harbor values

The following table show the needed parameters to be customized for Harbor itself:

| File                                      | String to be replaced        | Description                                                  | Example value                                                     |
| ----------------------------------------- | ---------------------------- | ------------------------------------------------------------ | ----------------------------------------------------------------- |
| `kustomization.yaml`                      | `%HARBOR_ADMIN_PASSWORD%`    | The password for Harbor admin user                           | `Harbor12345`                                                     |
| `kustomization.yaml`, `patch/ingress.yml` | `%YOUR_INGRESS_HOST%`        | The Ingress host that you want to use to expose Harbor       | `https://harbor.example.com`                                      |
| `kustomization.yaml`                      | `%%YOUR_WANTED_REPLICAS%%`   | The number of replicas for all Harbor components             | `2`                                                               |
| `kustomization.yaml`                      | `%CORE_SECURE_KEY%`          | 16 characters secret string used by the core component       | Output of `head -c16 /dev/urandom \| base64 \| head -c16 && echo` |
| `kustomization.yaml`                      | `%CORE_SECURE_SECRET%`       | 16 characters secret string used by the core component       | Output of `head -c16 /dev/urandom \| base64 \| head -c16 && echo` |
| `kustomization.yaml`                      | `%JOBSERVICE_SECURE_SECRET%` | 16 characters secret string used by the jobservice component | Output of `head -c16 /dev/urandom \| base64 \| head -c16 && echo` |
| `kustomization.yaml`                      | `%REGISTRY_SECURE_SECRET%`   | 16 characters secret string used by the registry component   | Output of `head -c16 /dev/urandom \| base64 \| head -c16 && echo` |


## Configuration

# Image pull

When using an S3-compatible object storage, Harbor supports on of two different ways to allow end-users to pull images: 
- if redirect is enabled, the end-users will be redirected to pull image layers directly from the S3 bucket 
- if redirect is disabled, the registry component will act as a middleware and will effectively download the layers from S3 itself, and the end-users will be downloading them from Harbor.

[CNCF documentation](https://distribution.github.io/distribution/about/configuration/#redirect)

The parameter that governs this behaviour is "storage.redirect.disable" in the config/registry/config.yml file. 
