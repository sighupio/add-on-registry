# Compatibility Matrix

| Module Version / Kubernetes Version |       1.14.X       |       1.15.X       |       1.16.X       |       1.17.X       |       1.18.X       |       1.19.X       |       1.20.X       |       1.21.X       |       1.22.X       |       1.23.X       |       1.24.X       |       1.25.X       |       1.26.X       |       1.27.X       |       1.28.X       |
| ----------------------------------- | :----------------: | :----------------: | :----------------: | :----------------: | :----------------: | :----------------: | :----------------: | :----------------: | :----------------: | :----------------: | :----------------: | :----------------: | :----------------: | :----------------: | :----------------: |
| v1.0.0                              | :white_check_mark: | :white_check_mark: | :white_check_mark: | :white_check_mark: | :white_check_mark: |                    |                    |                    |                    |                    |                    |                    |                    |                    |                    |
| v1.0.1                              | :white_check_mark: | :white_check_mark: | :white_check_mark: | :white_check_mark: | :white_check_mark: |                    |                    |                    |                    |                    |                    |                    |                    |                    |                    |
| v1.1.0                              |                    |                    | :white_check_mark: | :white_check_mark: | :white_check_mark: |                    |                    |                    |                    |                    |                    |                    |                    |                    |                    |
| v1.1.1                              |                    |                    | :white_check_mark: | :white_check_mark: | :white_check_mark: |                    |                    |                    |                    |                    |                    |                    |                    |                    |                    |
| v1.1.2                              |                    |                    |                    |                    | :white_check_mark: | :white_check_mark: | :white_check_mark: |                    |                    |                    |                    |                    |                    |                    |                    |
| v1.2.0                              |                    |                    |                    |                    | :white_check_mark: | :white_check_mark: | :white_check_mark: | :white_check_mark: |                    |                    |                    |                    |                    |                    |                    |
| v2.0.0                              |                    |                    |                    |                    | :white_check_mark: | :white_check_mark: | :white_check_mark: | :white_check_mark: | :white_check_mark: | :white_check_mark: |                    |                    |                    |                    |                    |
| v3.0.0                              |                    |                    |                    |                    |                    |                    | :white_check_mark: | :white_check_mark: | :white_check_mark: | :white_check_mark: |                    |                    |                    |                    |                    |   
| v3.0.1                              |                    |                    |                    |                    |                    |                    | :white_check_mark: | :white_check_mark: | :white_check_mark: | :white_check_mark: |                    |                    |                    |                    |                    |  
| v3.0.2                              |                    |                    |                    |                    |                    |                    |                    |                    | :white_check_mark: | :white_check_mark: | :white_check_mark: | :white_check_mark: |                    |                    |                    |
| v3.1.0                              |                    |                    |                    |                    |                    |                    |                    |                    | :white_check_mark: | :white_check_mark: | :white_check_mark: | :white_check_mark: | :white_check_mark: | :white_check_mark: | :white_check_mark: |

- :white_check_mark: Compatible
- :warning: Has issues
- :x: Incompatible

## Warning while upgrading from 1.X to 1.2

If you are using notary in your Harbor setup and you updated the setup from 1.x to 1.2 you could hit the following [issue](https://github.com/goharbor/harbor/issues/14932).

## Warning while upgrading from 1.x to 2.0

There's no supported upgrade path. See [release note v2.0.0](releases/v2.0.0.md) for more information.

## Warning while upgrading from 2.x to 3.0

There's no supported upgrade path. See [release note v3.0.2](releases/v3.0.2.md) for more information.