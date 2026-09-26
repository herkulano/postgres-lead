# postgres-lead

Postgres 18 with [Lead](https://github.com/planetscale/lead), PlanetScale's TIN-compatible text-search extension, built for development, tests, CI, and staging. In Lead's own words:

> Lead is a deliberately non-production Postgres text-search extension for exercising TIN-compatible application SQL in development, test, CI, and staging environments. […] It is intentionally unsuitable for production workloads.
>
> — [planetscale/lead README](https://github.com/planetscale/lead#readme)

## Usage

The image is `ghcr.io/herkulano/postgres-lead`, tagged with the Postgres version of its base. The tag stays put when only Lead moves, so pin it together with its digest. Each run of the publishing workflow prints the full string to pin in its summary.

```sh
docker run --rm -e POSTGRES_PASSWORD=postgres -p 5432:5432 \
  ghcr.io/herkulano/postgres-lead:18.6@sha256:<index digest>
```

```yaml
services:
  postgres:
    image: ghcr.io/herkulano/postgres-lead:18.6@sha256:<index digest>
    environment:
      POSTGRES_PASSWORD: postgres
    ports:
      - "5432:5432"
```

Then, in each database that searches:

```sql
CREATE EXTENSION tin;
```

Lead loads on demand, so nothing goes in `shared_preload_libraries`.

The digest to pin is the multi-arch index digest. It covers `linux/amd64` and `linux/arm64`, and Docker picks the platform the host runs.

## Updates

Every Monday, Renovate checks the Postgres base image, the Lead commit, and the GitHub Actions. It opens one pull request for all of them, and that pull request automerges once the image builds and passes its smoke test on both architectures. A new Postgres major version gets its own pull request and never automerges. The Rust toolchain and cargo-pgrx aren't pinned here. They follow Lead's own `rust-toolchain.toml` and `Cargo.lock`.

## License and source

Lead is licensed `AGPL-3.0-or-later` by PlanetScale. The image contains Lead compiled, unmodified, from the commit named by `LEAD_COMMIT` in the [`Dockerfile`](Dockerfile).

The Corresponding Source for that object code is:

- [Lead](https://github.com/planetscale/lead) at that commit, at `https://github.com/planetscale/lead/tree/<commit>`
- this repository at the commit in the image's `org.opencontainers.image.revision` label. Its `Dockerfile` and [`.github/workflows/image.yml`](.github/workflows/image.yml) are the build scripts.

Read both commits from an image you've pulled:

```sh
docker inspect --format '{{ index .Config.Labels "io.github.herkulano.postgres-lead.lead-commit" }}' <image>
docker inspect --format '{{ index .Config.Labels "org.opencontainers.image.revision" }}' <image>
```

The image carries Lead's license at `/usr/share/doc/lead/LICENSE`.

This repository is licensed `AGPL-3.0-or-later`, and [`LICENSE`](LICENSE) holds the text. PostgreSQL is under the PostgreSQL License. The base image's other packages keep their own licenses.

The image comes with no warranty, as sections 15 and 16 of the AGPL state.

## Trademarks and affiliation

This project is not affiliated with or endorsed by PlanetScale. TIN and PlanetScale are PlanetScale's names.
