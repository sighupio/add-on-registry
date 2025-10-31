# Harbor HA

This example deploys an Harbor instance with an High Availability configuration:

- External Postgres DB
- External Redis

## Usage

1. Clone this repository and enter in this folder in a terminal
2. Replace all configuration parameters as outlined below.
3. Run: `kustomize build . | kubectl apply -f - --server-side`

## Parameters

### Postgres DB

This setup assumes that you already have an existing Postgres instance and you want to use it with Harbor.

The parameters to be configured are:

| File                                                                               | String to be replaced     | Description                                                               | Example value                                                          |
| ---------------------------------------------------------------------------------- | ------------------------- | ------------------------------------------------------------------------- | ---------------------------------------------------------------------- |
| `kustomization.yaml`                                                               | `%YOUR_DB_HOSTNAME%`      | The hostname of the DB                                                    | `my-postgres.example.com`                                              |
| `kustomization.yaml`                                                               | `%YOUR_DB_PORT%`          | The port on which the DB is listening                                     | `5432`                                                                 |
| `kustomization.yaml`                                                               | `%YOUR_DB_USER%`          | The DB user to connect to the DB                                          | `harbor`                                                               |
| `kustomization.yaml`                                                               | `%YOUR_DB_PASSWORD%`      | The password for the DB user to connect to the DB                         | `password`                                                             |
| `kustomization.yaml`                                                               | `%YOUR_DB_NAME%`          | The DB name to be used with Harbor                                        | `registry`                                                             |

### Redis

This setup assumes that you already have an existing Redis instance and you want to use it with Harbor.

The parameters to be configured are:

> [!WARNING]
> As of Harbor 2.14.x, there is an issue with the Jobservice component of Harbor where a configuration with Redis Sentinel protected with a password
> (either on Sentinel only or both in Sentinel and Redis masters) is not working.
> The only way of working with an highly available Redis, for now, is to implement Sentinel without a password (you can still put a password on the Redis masters).
> We opened an [issue upstream](https://github.com/goharbor/harbor/issues/22538).

| File                                                                               | String to be replaced     | Description                                                               | Example value                                                          |
| ---------------------------------------------------------------------------------- | ------------------------- | ------------------------------------------------------------------------- | ---------------------------------------------------------------------- |
| `kustomization.yaml`, `patch/ingress.yml`                                          | `%YOUR_INGRESS_HOST%`     | The Ingress host that you want to use to expose harbor                    | `https://harbor.example.com`                                           |
| `kustomization.yaml`, `config/jobservice/config.yml`                               | `%YOUR_REDIS_SCHEME%`     | Either `redis` or `redis+sentinel`. See dedicated paragraph for more info | `redis+sentinel`                                                       |
| `kustomization.yaml`, `config/jobservice/config.yml`                               | `%YOUR_REDIS_PASSWORD%`   | The password for Redis. See dedicated paragraph for more info             | `password`                                                             |
| `kustomization.yaml`, `config/jobservice/config.yml`, `config/registry/config.yml` | `%YOUR_REDIS_HOSTS%`      | The host list for Redis. See dedicated paragraph for more info            | `redis-sentinel-0:26379,redis-sentinel-1:26379,redis-sentinel-2:26379` |
| `kustomization.yaml`                                                               | `%HARBOR_ADMIN_PASSWORD%` | The password for Harbor admin user                                        | `Harbor12345`                                                          |
| `config/registry/config.yml`                                                       | `%YOUR_REDIS_MASTER_SET%` | The password for Redis. See dedicated paragraph for more info             | `redisMaster`                                                          |
