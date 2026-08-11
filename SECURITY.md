# Security Policy

## Supported versions

Security fixes target the latest tagged release and the current `main` branch.

| Version | Supported |
| --- | --- |
| `0.4.x` | Yes |
| `< 0.4` | No |

## Reporting a vulnerability

Report suspected vulnerabilities through GitHub's [private vulnerability reporting](https://github.com/yehyakin/codex-sol-control/security/advisories/new). Do not open a public issue and do not include credentials, tokens, private paths, or private repository content.

Include the affected version or commit, operating system and Codex surface, reproduction steps, impact, and a minimally redacted proof of concept when safe. We aim to acknowledge a report within seven days and will share the next update after triage.

## Security scope

Reports are in scope when they concern:

- installer, uninstaller, validation, backup, checksum, path, or rollback behavior;
- unexpected writes, scope violations, permission escalation, or unsafe agent routing;
- exposure of secrets or private repository data caused by this repository;
- bypasses of the documented review, evidence, or fail-closed boundaries.

The following belong elsewhere:

- vulnerabilities in OpenAI, Codex, GitHub, an operating system, or another third-party service;
- model availability, model quality, latency, pricing, or cost-estimate disagreements;
- bugs in downstream business projects that do not originate in this repository.

Please report third-party product vulnerabilities to the affected vendor.
