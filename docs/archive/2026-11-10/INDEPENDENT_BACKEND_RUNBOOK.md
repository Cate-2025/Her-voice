> Archived snapshot, preserved 10 November 2026. Historical instructions and results may be superseded. Use the [current review documents](../../README.md).

# Backend operations reference

Updated 6 November 2026. **Initial deployment steps have moved to [Deployment](DEPLOYMENT.md).** Read this reference when setting up monitoring, backups, restore and later updates. It is not a second startup guide.

## Monitoring and recovery

Monitor HTTPS reachability, readiness, API errors/latency, disk and memory, database connection/capacity, storage failures, mail delivery and pending/failed push records. API access logs are disabled in the image and no proxy access log is enabled; application exceptions still need review for accidental sensitive fields. Send alerts to a named operator with response coverage. Do not collect narratives, identity reveal values, attachment bytes, JWTs, passwords, email codes or device tokens in monitoring.

A health probe and restart policy do not constitute an external monitoring system. Select/configure the institution's monitoring service and test an alert before launch. Container logs are rotated locally, not automatically backed up or centrally retained.

Define recovery point and recovery time targets. Back up PostgreSQL and matching evidence objects, retain access to encryption keys and protect backup credentials separately. For an operator-managed PostgreSQL backup, install matching PostgreSQL client tools and configure a protected `pg_service.conf` and password file; then use a service name rather than credentials in shell history:

```bash
pg_dump 'service=hervoice-backup' --format=custom --file=/SECURE_BACKUP_PATH/hervoice.dump
# Restore into a NEW isolated database using a separately configured service.
pg_restore --dbname='service=hervoice-restore-test' --exit-on-error /SECURE_BACKUP_PATH/hervoice.dump
```

Use provider-native snapshot/PITR and private object backup tooling where appropriate. Record object inventory/version references alongside the database recovery point. In staging, restore both and demonstrate report visibility, evidence integrity, account isolation and audit history. A live database dump plus unsynchronised object copy is not automatically a consistent recovery set. Do not restore over the running personal prototype or production database during rehearsal.

For a release, record commit/image tag, schema revision, configuration version, migration backup and approver. Rebuild the tagged image, run migrations once, recreate API/proxy, check readiness and execute a fictional end-to-end journey. Keep the previous image. Application rollback is safe only with compatible schema/data; never blindly run Alembic downgrade on live evidence/case records. Database recovery requires a planned maintenance/recovery procedure.


## Deployment status

These procedures are prepared instructions. External image execution, provider integration, monitoring alerts, backup restoration and host reboot still require recorded acceptance checks. Docker socket permission previously prevented local container execution; no host permissions were changed.
