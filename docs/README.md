# HERVOICE — review documents

Start with **Description**, then **Deployment**. Only five main documents are
needed to review and operate the current project.

| Document | Use it for |
| --- | --- |
| [Description](DESCRIPTION.md) | Product, implemented features, boundaries, file map and current verification position |
| [Deployment](DEPLOYMENT.md) | Independent API hosting, database/evidence, SMTP, optional Firebase, signed Android distribution, monitoring, backups and recovery |
| [Development](DEVELOPMENT.md) | Laptop startup, Android Studio/adb, local service rehearsal, code/recovery explanation and developer checks |
| [Release checklist](RELEASE_CHECKLIST.md) | Record acceptance against the exact hosted build, device, providers and release decision |
| [Decisions](DECISIONS.md) | Stakeholder answer sheet D01–D16, v1 scope, case-handling, privacy, operations and BI questions |

## Detailed reference

[API contract](reference/API_CONTRACT.md) and [generated OpenAPI](openapi.json) are
technical reference, not additional deployment guides. [PRODUCT.md](../PRODUCT.md)
and [DESIGN.md](../DESIGN.md) remain project/design contracts at repository root.

## History

Older plans, comparisons, audits, screenshots and the original stakeholder Word
workbook are in [Archive](archive/README.md). Nothing was discarded. Historical
unfinished-item lists and test counts do not override the current guides.

Documentation was consolidated on 10 November 2026. This reorganisation changed
no application behaviour, running service, deployment credentials or device data.
