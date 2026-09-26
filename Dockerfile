# Postgres with Lead, PlanetScale's TIN-compatible text-search extension for development,
# tests, CI, and staging. Lead ships no image and no binary, so this file builds it from
# Rust source and copies the result into a clean Postgres image.
#
# `.github/workflows/image.yml` publishes this to ghcr.io/herkulano/postgres-lead, as one
# multi-arch index tagged with the Postgres version of the base below.
#
# Lead's commit is the only pin this file keeps for Lead. The Rust toolchain comes from
# Lead's `rust-toolchain.toml` and cargo-pgrx from Lead's `Cargo.lock`, so both move with
# LEAD_COMMIT. Renovate moves LEAD_COMMIT and the base image.

# Lead publishes no tag and no release, so the source is pinned by commit on `main`.
# renovate: datasource=git-refs depName=lead packageName=https://github.com/planetscale/lead branch=main
ARG LEAD_COMMIT=bd95c7e51b6afce81396790852ee2f2c169570ad
# Lead's license at that commit, as its `Cargo.toml` declares it. The build fails when the
# two disagree, so a relicensing Lead bump stops for a person to update this, the README,
# and the label below, rather than automerging.
ARG LEAD_LICENSE=AGPL-3.0-or-later

# The Debian variant, because the Alpine one deletes its build toolchain and no source
# states that Lead builds against musl. Both stages name one base, pinned by its multi-arch
# index digest: the builder compiles against this server's headers and the runtime loads
# the result. Renovate moves the two lines together.
FROM postgres:18.6-trixie@sha256:5a5a84b19854a9ffaa54082c166ff4ec27473a361e496e5ea167f298f2da9722 AS builder

ARG LEAD_COMMIT
ARG LEAD_LICENSE

# `postgresql-server-dev-18` carries the headers and the `pg_config` that pgrx targets.
# clang and libclang are what pgrx runs bindgen with.
RUN apt-get update \
	&& apt-get install --yes --no-install-recommends \
		build-essential \
		ca-certificates \
		clang \
		curl \
		git \
		libclang-dev \
		pkg-config \
		postgresql-server-dev-18 \
	&& rm -rf /var/lib/apt/lists/*

ENV RUSTUP_HOME=/usr/local/rustup \
	CARGO_HOME=/usr/local/cargo \
	PATH=/usr/local/cargo/bin:$PATH

# No default toolchain: Lead's `rust-toolchain.toml` names the one it builds with.
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
	| sh -s -- -y --profile minimal --default-toolchain none

RUN git clone --filter=blob:none https://github.com/planetscale/lead.git /lead \
	&& git -C /lead checkout "$LEAD_COMMIT"

WORKDIR /lead

RUN grep -Fqx "license = \"$LEAD_LICENSE\"" Cargo.toml \
	|| { echo "Lead's Cargo.toml no longer declares $LEAD_LICENSE:" >&2; grep -n '^license' Cargo.toml >&2; exit 1; }

# Installs the toolchain `rust-toolchain.toml` names, so every later cargo call uses it.
RUN rustup toolchain install

# Lead requires one exact pgrx version, and cargo-pgrx must match it exactly. Reading it
# from `Cargo.lock` keeps the two in step whenever LEAD_COMMIT moves.
RUN pgrx_version="$(awk '$0 == "name = \"pgrx\"" { getline; gsub(/^version = "|"$/, ""); print }' Cargo.lock)" \
	&& test -n "$pgrx_version" \
	&& cargo install cargo-pgrx --version "$pgrx_version" --locked

# `package` reads PGRX_HOME even when it is told which server to build against, so the
# build fails with "$PGRX_HOME does not exist" without this. Passing the image's own
# pg_config registers that server, so nothing downloads or compiles Postgres here.
ENV PGRX_HOME=/usr/local/pgrx
RUN cargo pgrx init --pg18 /usr/lib/postgresql/18/bin/pg_config

# `--pg-config` points the build at the server this image already carries, so nothing
# downloads or compiles Postgres. `package` writes a tree rooted at `/`, which is what
# lets the runtime stage copy it whole.
RUN cargo pgrx package \
	--package tin \
	--no-default-features \
	--features pg18 \
	--pg-config /usr/lib/postgresql/18/bin/pg_config \
	--out-dir /out

FROM postgres:18.6-trixie@sha256:5a5a84b19854a9ffaa54082c166ff4ec27473a361e496e5ea167f298f2da9722

ARG LEAD_COMMIT
ARG LEAD_LICENSE

# The workflow adds `org.opencontainers.image.revision` with this repository's commit.
LABEL org.opencontainers.image.source="https://github.com/herkulano/postgres-lead" \
	org.opencontainers.image.licenses="$LEAD_LICENSE AND PostgreSQL" \
	org.opencontainers.image.description="Postgres 18 with PlanetScale's Lead, a non-production TIN-compatible text-search extension" \
	io.github.herkulano.postgres-lead.lead-commit="$LEAD_COMMIT"

# Nothing preloads. Lead loads on demand, so the image needs no `shared_preload_libraries`
# and no initdb script. A database gets the extension through `CREATE EXTENSION tin`.
COPY --from=builder /out/ /
COPY --from=builder /lead/LICENSE /usr/share/doc/lead/LICENSE
