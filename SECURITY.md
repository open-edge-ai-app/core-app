# Security Policy

## Supported Versions

Open Edge AI is in early development. Security fixes are applied to the `main`
branch until stable release branches are created.

## Reporting a Vulnerability

Please do not create a public GitHub issue for a suspected vulnerability.

Use GitHub's private vulnerability reporting flow for this repository when
available. If that is not available, contact the maintainers through a private
channel and include:

- affected commit, version, or branch;
- platform and device details;
- steps to reproduce;
- impact and affected data;
- any suggested mitigation.

We will acknowledge valid reports as soon as practical and coordinate a fix
before public disclosure.

## Security Scope

Relevant reports include:

- unsafe handling of local files, attachments, or content URIs;
- leakage of private chat data, embeddings, or indexed device data;
- insecure model download or model file validation behavior;
- native bridge misuse that can expose device capabilities unexpectedly;
- dependency vulnerabilities that affect shipped app behavior.

Please include only the minimum sensitive data needed to reproduce the issue.
