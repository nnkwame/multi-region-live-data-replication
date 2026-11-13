# Implementation log

## 2026-11-10 — Advisory planning and requirements review

Reviewed AGENTS.md, both target milestone files and the original Kafka plan. Operational documentation files were empty; no application/infrastructure assets were found in the visible workspace.

Recorded the user's approval boundary and documentation ownership. Added README, gated roadmap, architecture proposal, correctness contract, decisions, research sources and presentation notes. Appended the changed direction to the historical plan without rewriting it.

Main finding: database-first stores require snapshot/live capture and correct multi-table target application; MirrorMaker alone is insufficient. Ambiguous checkout retries and writer fencing are early feasibility gates. Recommended same-product A/B, Compose first, and cloud as a mandatory completion gate.

Consulted official sources for store installation/APIs/licenses, Debezium/JDBC, MirrorMaker/Kafka semantics, RabbitMQ Streams, Kubernetes autoscaling and Hetzner geography. These establish capability, not tested compatibility or performance.

The workspace exposes .git, but `git status` reports that it is not a Git repository. No checkpoint was created. Resolve metadata access before Git-based milestones; do not initialize over an existing repository without understanding the environment.

This step changes documentation only. No containers, packages, cloud resources, features or bug fixes were implemented. Validation is limited to local documentation links and consistency.

### Deadline and available hardware clarification

The user confirmed Friday 10:00 submission, mostly all-day availability, an older Lenovo Z710 and access to a 64 GB RAM second machine. Added a three-day submission schedule, hard feasibility review points, Wednesday cloud target and Thursday feature freeze. Submission timezone and actual cloud permissions remain to be confirmed. No runtime work authorized or performed.

### Revised topology, automation ownership and reset requirements

The user clarified that they will provision local stores, starting on the older laptop. Each store keeps one database; Kubernetes workload autoscaling starts disabled. Codex will own reproducible data preparation, baseline restore and order generation once the concrete plan is approved. Dedicated secrets tooling is deferred.

Researched official Bagisto Docker/load-balancing guidance and PrestaShop versioned schema updates. Revised the store recommendation toward Bagisto for the explicit scaling requirement; no final version pair or runtime capability has been tested. Added reusable baseline manifests/restores and consistent CDC/Kafka reset requirements. Recorded why same-version relocation is valid and why version upgrades complicate replication. Documentation only; no implementation performed.

### Release research and deployment/API handoff

The user agreed to Bagisto and prioritized local same-version migration, GitHub Actions, necessary cloud scenarios, AWS DR, then different products/versions. Researched Bagisto 2.4.13 release/source requirements and API 2.4.4 documentation. Recommended these with PHP 8.3 and an external MariaDB 10.11 line; database/runtime exact patch/digest and exact-pair integration remain unverified. Added a deployment/API contract covering ownership, endpoints, schema discovery, checkout/correlation, fixture domain and repeatable baselines.

The catalog now represents synthetic worldwide business buyers of expensive energy machinery. Avoided adding procurement/FX/tax scope. No stores, dependencies or scripts were implemented.

### API packaging, cloud sequence and fixture clarification

Clarified that bagisto/bagisto-api is an in-application Composer package rather than a separate service. Documented build versus database-initialization responsibilities. User selected AWS-to-AWS in two regions before hybrid migration, with shared Terraform code and explicit state/connectivity boundaries.

Updated fixture contract to 80 companies, 15 countries and EUR; added small 30-order and parameterized stress profiles with measurement/claim boundaries. User confirmed Chaos Mesh, deferred until clean-condition success. Documentation only; no infrastructure, images, packages or scripts changed.

### Generator placement and Bagisto metrics investigation

Recorded the user's dedicated cloud generator instance and minimal colocated local stream. Reviewed Bagisto official monitoring/health guidance and pinned Composer dependencies; no documented native Prometheus endpoint was established. Source audit was incomplete, so absence is not asserted as proven. Official guidance describes `/up` as boot-only health.

Documented external instrumentation using generator/verifier metrics, logs, DB exporter and optional HTTP/web exporters, without custom shop instrumentation. Added Kubernetes handoff requirements including CDC-ready database configuration and collectable logs. Highlighted the already selected API installer's file changes and unresolved persistent correlation requirement. Documentation only.

### Supported integrations explicitly accepted

The user clarified that documented Bagisto packages/configuration and API installer modifications are acceptable; the concern is avoidable bespoke immature shop code. Recorded that boundary and added host/node-exporter visibility alongside pod/container monitoring. No runtime changes performed.

## 2026-11-12 — Laravel runtime failures and media persistence

The user restored a 147-table database backup into external MariaDB. Store A then returned HTTP 500. Laravel logs identified a root-owned non-group-writable log file, followed by failed file-cache writes; temporary repairs confirmed the affected pages could load. A clean restart reproduced a root-owned Laravel log created during startup.

With the user’s approval, updated the app manifest to prepare Laravel runtime ownership after the upstream entrypoint’s setup and before Supervisor, and to mount a per-namespace PVC for public media, initially seeded only when empty. Both Kustomize overlays rendered locally. Minikube sockets remain blocked in the agent sandbox; no deployment or full-store validation has been performed. The existing media backup needs restoration to the new volume and verification.

### Pod restart verification

The user applied the Store A overlay, restored the public-media backup and restarted the deployment. The media PVC was Bound; a restored WebP file matched its backup SHA-256. Requests to `/` and `/footwear` returned HTTP 200, and `laravel.log` was owned by `www-data`. This verifies the reported paths and sampled file after one restart; it does not prove every page, full media completeness, API readiness or migration correctness.

## 2026-11-12 — Bagisto API enabled without an image rebuild

After Minikube network access was enabled, backed up Store A MariaDB and public media into ignored `artifacts/baselines/api-preinstall/`. Created a disposable database and isolated copy of the application. Bagisto API 2.4.4's documented installer completed on that copy, producing 219 Shop routes and 512 Admin routes. An authenticated Shop catalog request returned HTTP 200. Replayed its generated application configuration on a second disposable app copy and repeated the Shop API check.

The installer modifies Composer configuration, Bagisto bootstrap and TranslatableModel, API Platform configuration, assets, database migrations and a storefront key. Kept the existing image and original Composer files; added installer-generated configuration under `k8s/bagisto/app/api`, and configured Kustomize to mount it. Composer lock was refreshed without changing package versions. Startup performs package discovery and publishes the API assets; migrations and key generation do not run on every restart. Added a TCP readiness probe to avoid reporting the app ready before port 80 listens.

Applied the six pending API migrations to Store A after the backup. Created a dedicated Store A storefront key in ignored local run data. Applied the overlay and verified after pod replacement: authenticated Shop API returned 30 products; `/`, `/footwear` and `/api/shop/docs` returned HTTP 200; a sampled public-media hash matched. Deleted the disposable database created for the test. Store B, Admin API authenticated operations, checkout, restore and complete storefront behavior remain untested.

Composer's lock refresh reported 22 security advisories affecting 11 packages; this includes the resolved dependency set and has not been triaged. The `vendor:publish` command in the first rollout logged missing optional configuration source paths but returned success; changed later startup to publish only required asset tags.

## 2026-11-12 — Fixture API spike on an isolated store copy

The Store A Admin Integration token authenticated for reads, but category creation returned HTTP 403. A read-only inspection showed its scope was limited to `integration` and `integration.generate`. Requested catalog/customer/inventory/settings/order permissions from the user; the live store was not seeded. Backed up the current Store A database and public media to ignored `artifacts/baselines/fixture-preparation/`.

Created a disposable `capstone_fixture_spike` database from that backup and a separate app copy. For testing only, changed the copied token's scope in that disposable database; the live token and live business data were not changed. Added parameterized synthetic fixture generation, API bootstrap, media upload, offline checkout and order-verification scripts. The isolated test created EUR, 12 product records, and one customer/address in each of 15 countries. A repeat bootstrap did not duplicate the first two customers or products.

Two isolated offline Shop API checkouts produced pending EUR orders; Admin API readback matched customer, items, quantity and total. A deliberately altered expected amount was rejected. A later revised ledger format was tested with another order. Two appropriately licensed illustrative images were uploaded to the isolated store; repeat upload detected them by alt text. Saved source attribution in `fixtures/static/ASSETS.md`.

Limitations: this is not a completed live fixture. Storefront theme/banners, full imagery, 80-customer/30-order run, reset/export automation, B baseline, retry resolution and complete verification remain unfinished. The ledger stops on ambiguous submissions; it does not supply server-side exactly-once semantics. The temporary database and app copy are test resources, not the migration source.

## 2026-11-12 to 2026-11-13 — Store fixture milestone

After the user expanded the demo Admin token permissions, the tested fixture scripts populated Store A via Bagisto APIs: EUR, 12 products, 80 synthetic customers in 15 countries, 30 pending offline-payment orders and 12 product images. A theme banner and visible attribution were configured. Eight original top-level sample categories and unrelated homepage sections were disabled, not deleted. The sample bulk status API failed on booking products, so original sample products remain and can appear in search.

All 30 orders matched the independent API verifier; its negative amount test failed as expected. Twelve product pages, six category pages and twelve image URLs returned HTTP 200. A missing :8080 image URL was fixed in the Store A Kustomize overlay. These checks are scoped evidence, not proof of every link or payment processing.

Exported quiesced database/public-media bundles into ignored local artifacts. Restored A into a disposable database and media directory: selected business rows and all 361 media-file hashes matched; a restored app passed 30 order readbacks and three page checks. Prepared a separate clean B baseline from the original store: 12 matching product IDs/SKUs/names/prices, zero customers and orders. Its restored database and 367 media hashes matched; three restored app pages worked. These are isolated local app/database tests, not separate deployed clusters or a Kafka migration. B media paths differ from A and require explicit migration handling.

The user interrupted the previous turn for status. Store A and both PVCs remain running/bound. Store B deployment, Kafka cutover, cloud deployment, full sample cleanup, complete end-to-end generator and ambiguous checkout resolution remain open. No commits were created.

## 2026-11-13 — Store B deployed locally

Applied Store B database and application overlays in Minikube. The application initially restarted against its empty database, so the checksum-verified B baseline database was imported first after confirming the database was empty and the APP_KEY fingerprint matched. Replaced only the fresh media PVC initialization contents with the verified matching B media archive. Both pods became ready; the homepage, category, product page, API documentation and a product image returned HTTP 200. SQL showed 12 fixture products and zero customers or orders. Updated the local JDBC sink URL to Store B; connectors were not started. The sink still matches all Store A table topics and uses errors.tolerance=all, so it requires review before replication.

## 2026-11-13 — Default catalog replacement in progress

Validated the pre-customization database and media checksums, restored them to isolated databases, and generated test data without changing the running Store A. A 5,000-customer/50,000-order benchmark completed in 14.7 seconds. The 100,000-customer/1,000,000-order isolated load completed in 4m15s and its database reports approximately 1,420 MiB; this has not yet been deployed to Store A. User is deciding whether to use this load now. The default homepage, footwear page and hero image worked in an isolated app. A restore runner was created and its Store B test is in progress.

### Default fixture completion

Created A fixtures with 8,000 customers/50,000 orders and 100,000 customers/1,000,000 orders, plus B fixtures with zero orders and zero, 8,000, or 100,000 matching customers. SQL checks found zero custom EN-prefixed products or order items and no missing product/customer associations or mismatched item totals. Orders randomly select four standalone default catalog products. The million-order DB occupied approximately 1,420 MiB before dump; compressed SQL was 103,673,925 bytes. The build-all script passed a reduced-size end-to-end run. Checksum-verified bundles and restore scripts are local ignored artifacts pending the user’s commit review.

Restored the large A bundle and empty B bundle to their respective live namespaces. Both application deployments were deleted and reapplied while preserving database and media PVCs; both returned Ready. Home, footwear, default hero media and admin login returned HTTP 200; seven extracted homepage media URLs per store returned HTTP 200. Store A customer API login succeeded and admin API reads of orders 1, 500000 and 1000000 returned the expected default-product items. A B bundle with 8,000 customers and no orders was also restored and checked before returning B to the empty-customer variant. These checks do not prove every link or live migration. The source connector table allowlist was prepared but not deployed or tested; the keyless customer_password_resets table was omitted.

## 2026-11-13 — Strimzi WIP and local prerequisite setup

Committed the user’s data-replication WIP as fe67beb. Selected Strimzi 1.3.1/Kafka 4.3.1 with Debezium 3.7.1.Final because the Strimzi compatibility table supports this Kubernetes/Kafka pair and Debezium reports building/testing 3.7.1 against Kafka 4.3.1. Installed the operator in data-replication using the pinned official release. Restored A to 8,000 customers and 50,000 orders and B to 8,000 customers and zero orders, each with an automatic pre-restore backup. Added Store A MariaDB row-format binlogging and dedicated CDC privileges; confirmed log_bin=ON, binlog_format=ROW, binlog_row_image=FULL and server_id=101. Enabled Minikube’s local registry addon for Strimzi Connect image output. Kafka/Connect JMX exporter configuration is included; Prometheus/Grafana are not yet deployed.

The Strimzi Buildah pod expanded to more than 9 GiB on the laptop's nested filesystem and was stopped before the disk filled. Its generated Dockerfile was retained; a host Docker build of the same pinned Kafka base and plugin archives was loaded into Minikube instead. The in-cluster build configuration remains a possible cloud option, subject to a configured TLS registry and credentials. The Minikube Docker container was increased from 3 GiB to 5 GiB after API timeouts at the original limit; `docker update` changes the existing container rather than the persisted Minikube profile, so this must be revisited when recreating Minikube. Kafka and Connect JMX endpoints returned HTTP 200. The connector REST API reported both expected Debezium 3.7.1 plugins.

The initial sink failed because the Kafka Connect dead-letter queue defaulted to three replicas while the local broker has one. Set the local DLQ replication factor to one, preserving the user's requested `errors.tolerance=all`. The source snapshot completed; the sink first applied parent orders. A and B each reached 50,000 orders and the ordered full-row SHA-256 digests matched. The sink was then expanded to child tables; checks remain in progress. Counts and matching selected rows do not prove a live cutoff or exactly-once payments.

The small local replication test completed: Store A and Store B each held 50,000 order rows after catch-up. Ordered full-row SHA-256 hashes matched for customers, orders, order items, order payments, addresses, product inventories, inventory indices and ordered inventories. Both connector tasks reported RUNNING and the local dead-letter topic end offset was zero. A one-second `updated_at` change to a synthetic order propagated A-to-B and the reversal also propagated. The B Admin API returned orders 1, 25000 and 50000 with an item each. This is evidence for the selected snapshot and one update, not proof of complete ordering, actual payment, uninterrupted traffic or cutover correctness.

## 2026-11-13 — Local monitoring trial

Deployed a separate standalone Prometheus/Grafana and node exporter in data-replication without modifying the earlier WIP Operator-based monitoring manifests. Prometheus discovers Kafka/Connect pods and scrapes node exporter plus cAdvisor through the Kubernetes API. The two Strimzi 1.3.1 dashboards were provisioned in Grafana. Prometheus targets for Kafka, Connect, cAdvisor and node exporter were healthy; representative Kafka/Connect, container CPU and node memory queries returned data. `promtool` validated four alert rules and a simulated skipped-record test fired as expected. Grafana and Prometheus use ephemeral storage in this trial, no Alertmanager or central log collection is configured, and the user has not approved a monitoring commit.

For a local rebuild, run `k8s/data_replication/scripts/build-connect-local.sh` to build the checked-in Dockerfile with host Docker and load it into Minikube, then `k8s/data_replication/scripts/deploy-connect-local.sh minikube`. The Dockerfile pins the Strimzi/Kafka base digest and both Debezium archive SHA-512 checksums. The optional Strimzi Build configuration requires replacing its placeholder registry and configuring registry authentication; cloud registry and CI behavior have not been validated. The local standalone monitoring deployment is reproducible with `k8s/data_replication/monitoring/local/deploy.sh minikube`; it remains uncommitted pending user review.

## 2026-11-13 — Watched clean replication rerun

At the user's request, stopped the source/sink and Connect, restored the small A/B bundles, and reset the local Kafka cluster before starting Kafka, Connect, an orders-only sink and then the source. Minikube's hostpath provisioner reused the same backing directory after PVC deletion, so the first new broker found the old cluster ID. Removed the released old Kafka PV and explicitly cleared only the Kafka test volume while the broker was stopped; restarted the operator after a previous reconciliation remained in progress. The new cluster then started successfully. The source snapshot began at approximately 06:52 UTC. After orders reached 50,000 on B, enabled the remaining captured tables. All eight selected business/inventory table hashes matched, both connector tasks were RUNNING, and the dead-letter topic offset was zero. Grafana and Prometheus remained running. This is a clean snapshot/catch-up demonstration, not a cutover or exactly-once payment proof.

## 2026-11-13 — EKS stack evaluation and rework

Inspected `infra/aws_eks/store_a` (and its near-copies in store_b/data_replication) and found: `terraform validate` failed on an undeclared `eks_exclude_azs` variable; the spot node group used the nonexistent `instance_availability_type` attribute, so it was silently ON_DEMAND; all stacks shared one S3 state key; no DNS existed despite the `ironlabs.online` zone being available (verified the zone in the account, no conflicting `kwame*` records); and the tainted spot group had no tolerating workload.

Reworked all three stacks: per-stack state keys and provider region from variable; region split (store_b → eu-central-1, verified 1.36 standard support and no EKS-excluded AZs there); Route53 alias records for the three store/monitoring domains, gated by `enable_domain_record` and wired by a new `dns.sh`; pinned nginx ingress controller (controller-v1.15.1) installed by `up.sh`; store overlays switched to ClusterIP + per-store Ingresses serving both the store host and `kwamesdemostore.ironlabs.online`; bagisto Deployment tolerates the spot taint with preferred stateless affinity; data_replication moved to x86_64 m6a.xlarge (AL2023) with its spot group at desired 0; distinct /16 VPCs per stack. Added SSM Session Manager policy to node roles (no EC2 key pairs needed). All three stacks pass `terraform validate`; overlays render with `kubectl kustomize`; scripts pass `bash -n`. `terraform apply` has not been run — this is configuration-level validation only.

## 2026-11-13 — Cloud EKS applies and TLS bootstrap

Store A (us-east-1) and store B (eu-central-1) applied successfully. Store B's first apply failed on the spot node group (`UnfulfillableCapacity` for single-type t4g.medium in Frankfurt); diversifying instance types per AMI architecture fixed it — AWS spot guidance is to diversify, and this was the second AWS behavior of the day that only surfaces at apply time. A mid-run script edit by the agent also corrupted one bootstrap run (bash reads scripts by byte offset; `kubectl wait` was re-parsed as the `wait` builtin) — lesson: never edit a script while it executes.

cert-manager v1.21.3 + IRSA (least-privilege Route53 zone policy) installed on both clusters. EKS module v21 exposes the OIDC provider as two outputs (`oidc_provider` is the issuer string, `oidc_provider_arn` the ARN) — the IRSA module wants the ARN. ClusterIssuers initially stayed NotReady: Let's Encrypt rejects `example.com` ACME contacts, and a placeholder address had leaked into the manifest from local config; cert-manager also caches ACME account keys in secrets, so both account-key secrets were deleted to force clean re-registration. After substituting the real contact, both issuers report Ready on both clusters. Remaining: first real DNS-01 issuance happens when the store Ingresses are deployed (start with staging issuer per class convention, then flip to prod).
