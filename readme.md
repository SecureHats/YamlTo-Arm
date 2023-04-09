![logo](./media/sh-banner.png)
=========
[![Maintenance](https://img.shields.io/maintenance/yes/2023.svg?style=flat-square)]()
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=flat-square)](http://makeapullrequest.com)</br>
[![Good First Issues](https://img.shields.io/github/issues/securehats/toolbox/good%20first%20issue?color=important&label=good%20first%20issue&style=flat)](https://github.com/securehats/toolbox/issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22)
[![Needs Feedback](https://img.shields.io/github/issues/securehats/toolbox/needs%20feedback?color=blue&label=needs%20feedback%20&style=flat)](https://github.com/securehats/toolbox/issues?q=is%3Aopen+is%3Aissue+label%3A%22needs+feedback%22)

# Microsoft Sentinel - template

This GitHub action can be used to ...<br />

### Example 1

> Add the following code block to your Github workflow:

```yaml
name: template
on:
  push:
    paths:
      - samples/**

jobs:
  template:
    name: Action Name
    runs-on: ubuntu-latest
    steps:
      - name: Check out repository code
        uses: actions/checkout@v3
      - name: SecureHats template
        uses: SecureHats/custom-logs@v1.0
        with:
          filesPath: samples
          workspaceId: ${{ secrets.WORKSPACEID }}
          workspaceKey: ${{ secrets.WORKSPACEKEY }}
```

### Example 2 only send changed files

> The output value from this action can be used as an input value for the `filesPath` parameter.

```yaml      
      - name: SecureHats template
        uses: SecureHats/template@v1.0
        with:
          workspaceId: ${{ secrets.WORKSPACEID }}
          workspaceKey: ${{ secrets.WORKSPACEKEY }}
```

### Inputs

This Action has the following format inputs.

| Name | Req | Description
|-|-|-|
| **`filesPath`**  | false | Path to the directory containing the log files to be send, relative to the root of the project.<br /> This path is optional and defaults to the project root, in which case all files CSV files and JSON wills across the entire project tree will be discovered.
| **`workspaceId`** | true | The workspace-id of the Log Analytics workspace.<br /> This value needs to be provided as a GitHub secret. see [documentation](https://github.com/Azure/actions-workflow-samples/blob/master/assets/create-secrets-for-GitHub-workflows.md) on how to create secrets in GitHub
| **`workspaceKey`** | true | The primary or secondary key of the Log Analytics workspace.<br /> This value needs to be provided as a GitHub secret. see [documentation](https://github.com/Azure/actions-workflow-samples/blob/master/assets/create-secrets-for-GitHub-workflows.md) on how to create secrets in GitHub


## Current limitations / Under Development

See backlog

If you encounter any issues, or hae suggestions for improvements, feel free to open an Issue

[Create Issue](../../issues/new/choose)
