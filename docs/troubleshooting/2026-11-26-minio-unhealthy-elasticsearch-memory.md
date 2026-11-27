# MinIO "unhealthy" on `docker compose up`: Elasticsearch starving the Docker VM

**Date:** 2026-11-26 · **Stack:** OpenCTI on Docker Compose (Docker Desktop, macOS) · **Status:** resolved, with prevention steps still to do

## Symptom

`docker compose up -d` aborted:

```text
✘ Container xtm-minio-1      Error
✘ Container xtm-rabbitmq-1   Error
✘ Container xtm-redis-1      Error
✘ Container xtm-pgsql-xtm-one-1  Error
dependency failed to start: container xtm-minio-1 is unhealthy
```

MinIO, RabbitMQ, Redis and the XTM One Postgres all reported `Error`, although most other containers showed `Running`.

## Environment

| Item | Value |
| --- | --- |
| Host | MacBook Pro, 932 GiB SSD |
| Docker | Docker Desktop (Docker Engine 28.0.1, Compose v2.33.1), LinuxKit VM |
| Docker VM resources | 16 CPUs, ~8 GB RAM (7.654 GiB visible to containers) |
| Stack | OpenCTI platform, 3 workers, Elasticsearch 8.19, RabbitMQ, Redis, MinIO (Silo build), XTM One + Postgres, about 10 connectors |

## Investigation

### 1. Check MinIO's health state

```bash
docker inspect xtm-minio-1 --format '{{json .State.Health}}'
```

```json
{"Status":"healthy","FailingStreak":1,"Log":[
  {"ExitCode":0,"Output":"The cluster 'local' is ready\n"},
  {"ExitCode":0,"Output":"The cluster 'local' is ready\n"},
  ...
  {"ExitCode":-1,"Output":"Health check exceeded timeout (5s)"}]}
```

The check passed several times, then failed once with a **5 s timeout**. MinIO was not crashing. Its health command was occasionally too slow to answer.

### 2. Read the MinIO logs

```bash
docker compose logs --tail=100 minio
```

Key lines (trimmed):

```text
Error: node(127.0.0.1:9000): taking drive /data offline: unable to write+read for 32.596s
Error: data-scanner: all drives are offline or being healed, skipping scanner cycle
Error: Storage resources are insufficient for the write operation .minio.sys/buckets/.bloomcycle.bin
Error: .minio.sys/buckets/.usage-cache.bin has incomplete body (cmd.IncompleteBody)
node(127.0.0.1:9000): Read/Write/Delete successful, bringing drive /data online
INFO: IAM refresh took (duration: 100.30s)
```

MinIO took its own drive offline because a simple write+read took 32 s. The drive then came back, and IAM refreshes were taking 20 to 100 s. That pattern points to **slow storage I/O**, not a corrupt volume.

### 3. Rule out disk space

```bash
df -h /
docker system df
```

```text
/dev/disk1s2s1   932Gi   12Gi   490Gi   3%   /
Local Volumes   18   9   779.2MB
```

The host had 490 GiB free (3% used). Docker volumes totalled under 1 GB, and the MinIO volume held about 6 MB. **Disk space was not the cause.**

### 4. Look at live resource use

```bash
docker stats --no-stream
```

| Container | CPU | Memory |
| --- | --- | --- |
| `xtm-elasticsearch-1` | **418%** | **4.76 GiB / 7.654 GiB (62%)** |
| `xtm-opencti-1` | 94% | 446 MiB |
| Workers, Redis, others | under 12% each | small |

Every container also showed very large cumulative block I/O (tens to hundreds of GB), so the Docker VM's shared virtual disk was under heavy load. Elasticsearch stood out. It was using most of the VM's memory and several CPUs' worth of time while the stack was starting.

## Root cause

**Resource contention and I/O starvation inside the Docker Desktop VM, driven mainly by Elasticsearch memory and CPU pressure.**

All containers share one virtual disk and about 8 GB of RAM. While Elasticsearch, OpenCTI and about ten connectors were starting together, disk I/O saturated. MinIO's write+read probe stalled, and so did its 5 s Docker healthcheck. Compose then treated MinIO as unhealthy and aborted startup, even though MinIO was up and the drive recovered on its own.

*This was diagnosed from log and metrics evidence. I did not capture Elasticsearch heap or I/O-wait statistics, which would be the next step to confirm it.*

## Fix

Stop the optional services to free CPU, memory and I/O:

```bash
docker compose stop xtm-one xtm-one-worker xtm-composer connector-mitre connector-threatfox
```

Then re-check MinIO:

```bash
curl -I http://127.0.0.1:9000/minio/health/live      # HTTP/1.1 200 OK
docker inspect xtm-minio-1 --format '{{json .State.Health}}'   # FailingStreak: 0
```

Then re-run `docker compose up -d`.

## Verification

- MinIO `/minio/health/live` returned **200**, and `FailingStreak` was **0**, with five consecutive passing checks about 0.2 to 0.3 s each.
- `docker compose up -d` completed with **every service healthy**. OpenCTI reported healthy after about **59 s**.
- I stopped the same optional services again to keep the load down, and `docker compose ps` showed the core stack healthy.
- `curl -I http://127.0.0.1:8080` returned **HTTP 200**.

## Lessons

- "Dependency failed to start: unhealthy" can mean "too slow to answer", not "broken". Read the health log (`ExitCode`, `Output`) before assuming a service is faulty.
- Check disk space first, but don't stop there. Free space says nothing about **I/O throughput** on a shared virtual disk.
- `docker stats` quickly shows which container is taking the VM's resources. Here it was Elasticsearch, as in my earlier outage on this lab.
- Cumulative block-I/O counters show the load but not the cause on their own. Pair them with the service logs.
- Trimming optional services is a quick way to get back to a stable baseline.

## Prevention (recommendations, not yet applied)

- **Cap the Elasticsearch heap** with `ES_JAVA_OPTS=-Xms2g -Xmx2g` (or similar), sized to the VM.
- **Give Docker Desktop more RAM.** 8 GB is tight for OpenCTI, Elasticsearch, XTM One and many connectors.
- **Lengthen the healthcheck `timeout` and add a `start_period`** for MinIO, so a brief I/O stall doesn't fail the whole `up`.
- **Stagger the connectors** so they don't all start while Elasticsearch is warming up.
- **Use Compose profiles** for optional services (XTM One, composer, extra connectors), so the core stack can start on its own.

## Next

The pcap stage of the network-monitoring pipeline is now done in Docker; OpenCTI ingestion is still not started. See [tcpdump baseline and Zeek install](../lab-log/2026-11-26-tcpdump-baseline-and-zeek-install.md) and [Zeek and Suricata in Docker](../lab-log/2026-11-27-zeek-suricata-docker.md).

```text
network traffic → Zeek / Suricata → alerts / observables → OpenCTI
```

The goal is to see whether anyone is attacking the home network. The memory and I/O limits found above still matter for this step. Zeek or Suricata would add load on the same Docker host, so the Elasticsearch heap cap and optional-service profiles should be in place first.

Back to the [lab README](../../README.md).
