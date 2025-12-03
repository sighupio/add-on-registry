# Compatibility Matrix

<!-- markdownlint-disable MD013 -->

| Module Version / Kubernetes Version |       1.29.X       |       1.30.X       |       1.31.X       |       1.32.X       |       1.33.X       |
| ----------------------------------- | :----------------: | :----------------: | :----------------: | :----------------: | :----------------: |
| v3.1.0                              | :white_check_mark: |                    |                    |                    |                    |
| v3.2.0                              | :white_check_mark: | :white_check_mark: | :white_check_mark: |                    |                    |
| v3.3.0                              | :white_check_mark: | :white_check_mark: | :white_check_mark: | :white_check_mark: |                    |
| v3.4.0                              | :white_check_mark: | :white_check_mark: | :white_check_mark: | :white_check_mark: | :white_check_mark: |
| v3.5.0                              | :white_check_mark: | :white_check_mark: | :white_check_mark: | :white_check_mark: | :white_check_mark: |

<!-- markdownlint-enable MD013 -->

- :white_check_mark: Compatible
- :warning: Has issues
- :x: Incompatible


## Warning while upgrading from 3.x to 3.3.0 and beyond

From the 3.3.0 version onwards, Harbor removed support to Notary and Chartmuseum, which were included in previous releases. See [v3.3.0 Release Notes](releases/v3.3.0.md) for detailed info.
