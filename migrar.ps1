025-Dec-12 20:40:38.655212
Starting deployment of plnamente/blue-taurus:main to localhost.
2025-Dec-12 20:40:39.315528
Preparing container with helper image: ghcr.io/coollabsio/coolify-helper:1.0.12
2025-Dec-12 20:40:41.768126
----------------------------------------
2025-Dec-12 20:40:41.775931
Importing plnamente/blue-taurus:main (commit sha bc29e5d4e00f6f9884c65773250a9822cc747975) to /artifacts/ns4kc4s4s4w8ogscg0okk00w.
2025-Dec-12 20:40:44.248356
Image not found (uk4gco4wgco84s0gco0w4co8:bc29e5d4e00f6f9884c65773250a9822cc747975). Building new image.
2025-Dec-12 20:40:48.283130
----------------------------------------
2025-Dec-12 20:40:48.289898
Building docker image started.
2025-Dec-12 20:40:48.297103
To check the current progress, click on Show Debug Logs.
2025-Dec-12 20:41:25.049450
========================================
2025-Dec-12 20:41:25.058153
Deployment failed: Command execution failed (exit code 1): docker exec ns4kc4s4s4w8ogscg0okk00w bash -c 'bash /artifacts/build.sh'
2025-Dec-12 20:41:25.058153
Error: #0 building with "default" instance using docker driver
2025-Dec-12 20:41:25.058153
2025-Dec-12 20:41:25.058153
#1 [internal] load build definition from Dockerfile
2025-Dec-12 20:41:25.058153
#1 transferring dockerfile: 1.86kB done
2025-Dec-12 20:41:25.058153
#1 WARN: FromAsCasing: 'as' and 'FROM' keywords' casing do not match (line 3)
2025-Dec-12 20:41:25.058153
#1 DONE 0.0s
2025-Dec-12 20:41:25.058153
2025-Dec-12 20:41:25.058153
#2 [internal] load metadata for docker.io/library/rust:1.83-slim-bookworm
2025-Dec-12 20:41:25.058153
#2 ...
2025-Dec-12 20:41:25.058153
2025-Dec-12 20:41:25.058153
#3 [internal] load metadata for docker.io/library/debian:bookworm-slim
2025-Dec-12 20:41:25.058153
#3 DONE 0.8s
2025-Dec-12 20:41:25.058153
2025-Dec-12 20:41:25.058153
#2 [internal] load metadata for docker.io/library/rust:1.83-slim-bookworm
2025-Dec-12 20:41:25.058153
#2 DONE 1.6s
2025-Dec-12 20:41:25.058153
2025-Dec-12 20:41:25.058153
#4 [internal] load .dockerignore
2025-Dec-12 20:41:25.058153
#4 transferring context: 114B done
2025-Dec-12 20:41:25.058153
#4 DONE 0.0s
2025-Dec-12 20:41:25.058153
2025-Dec-12 20:41:25.058153
#5 [stage-1 1/6] FROM docker.io/library/debian:bookworm-slim@sha256:e899040a73d36e2b36fa33216943539d9957cba8172b858097c2cabcdb20a3e2
2025-Dec-12 20:41:25.058153
#5 DONE 0.0s
2025-Dec-12 20:41:25.058153
2025-Dec-12 20:41:25.058153
#6 [stage-1 2/6] RUN apt-get update && apt-get install -y libssl-dev ca-certificates && rm -rf /var/lib/apt/lists/*
2025-Dec-12 20:41:25.058153
#6 CACHED
2025-Dec-12 20:41:25.058153
2025-Dec-12 20:41:25.058153
#7 [stage-1 3/6] WORKDIR /app
2025-Dec-12 20:41:25.058153
#7 CACHED
2025-Dec-12 20:41:25.058153
2025-Dec-12 20:41:25.058153
#8 [internal] load build context
2025-Dec-12 20:41:25.058153
#8 transferring context: 109.05kB done
2025-Dec-12 20:41:25.058153
#8 DONE 0.0s
2025-Dec-12 20:41:25.058153
2025-Dec-12 20:41:25.058153
#9 [builder 1/5] FROM docker.io/library/rust:1.83-slim-bookworm@sha256:540c902e99c384163b688bbd8b5b8520e94e7731b27f7bd0eaa56ae1960627ab
2025-Dec-12 20:41:25.058153
#9 resolve docker.io/library/rust:1.83-slim-bookworm@sha256:540c902e99c384163b688bbd8b5b8520e94e7731b27f7bd0eaa56ae1960627ab done
2025-Dec-12 20:41:25.058153
#9 sha256:38f33650b7d1aebcb6418b89c1c0b10773668da0cc60b3e6e2fbdf3c02f3166e 2.94kB / 2.94kB done
2025-Dec-12 20:41:25.058153
#9 sha256:fd674058ff8f8cfa7fb8a20c006fc0128541cbbad7f7f7f28df570d08f9e4d92 0B / 28.23MB 0.1s
2025-Dec-12 20:41:25.058153
#9 sha256:67f017dc59dd7cc1b48f98090d0a6561de33c508a2f3f37e37be17d3cce28df8 0B / 262.02MB 0.1s
2025-Dec-12 20:41:25.058153
#9 sha256:540c902e99c384163b688bbd8b5b8520e94e7731b27f7bd0eaa56ae1960627ab 7.80kB / 7.80kB done
2025-Dec-12 20:41:25.058153
#9 sha256:0f0dc99eb74e410d9420149cbb2b9be84abe00e8dbed6a4201a591a2c81844df 1.37kB / 1.37kB done
2025-Dec-12 20:41:25.058153
#9 sha256:fd674058ff8f8cfa7fb8a20c006fc0128541cbbad7f7f7f28df570d08f9e4d92 14.68MB / 28.23MB 0.7s
2025-Dec-12 20:41:25.058153
#9 sha256:67f017dc59dd7cc1b48f98090d0a6561de33c508a2f3f37e37be17d3cce28df8 16.78MB / 262.02MB 0.7s
2025-Dec-12 20:41:25.058153
#9 sha256:fd674058ff8f8cfa7fb8a20c006fc0128541cbbad7f7f7f28df570d08f9e4d92 28.23MB / 28.23MB 0.9s
2025-Dec-12 20:41:25.058153
#9 sha256:fd674058ff8f8cfa7fb8a20c006fc0128541cbbad7f7f7f28df570d08f9e4d92 28.23MB / 28.23MB 0.9s done
2025-Dec-12 20:41:25.058153
#9 extracting sha256:fd674058ff8f8cfa7fb8a20c006fc0128541cbbad7f7f7f28df570d08f9e4d92 0.1s
2025-Dec-12 20:41:25.058153
#9 sha256:67f017dc59dd7cc1b48f98090d0a6561de33c508a2f3f37e37be17d3cce28df8 31.46MB / 262.02MB 1.1s
2025-Dec-12 20:41:25.058153
#9 sha256:67f017dc59dd7cc1b48f98090d0a6561de33c508a2f3f37e37be17d3cce28df8 49.28MB / 262.02MB 1.6s
2025-Dec-12 20:41:25.058153
#9 sha256:67f017dc59dd7cc1b48f98090d0a6561de33c508a2f3f37e37be17d3cce28df8 71.13MB / 262.02MB 2.1s
2025-Dec-12 20:41:25.058153
#9 sha256:67f017dc59dd7cc1b48f98090d0a6561de33c508a2f3f37e37be17d3cce28df8 84.93MB / 262.02MB 2.5s
2025-Dec-12 20:41:25.058153
#9 extracting sha256:fd674058ff8f8cfa7fb8a20c006fc0128541cbbad7f7f7f28df570d08f9e4d92 1.5s done
2025-Dec-12 20:41:25.058153
#9 sha256:67f017dc59dd7cc1b48f98090d0a6561de33c508a2f3f37e37be17d3cce28df8 105.91MB / 262.02MB 2.9s
2025-Dec-12 20:41:25.058153
#9 sha256:67f017dc59dd7cc1b48f98090d0a6561de33c508a2f3f37e37be17d3cce28df8 119.54MB / 262.02MB 3.5s
2025-Dec-12 20:41:25.058153
#9 sha256:67f017dc59dd7cc1b48f98090d0a6561de33c508a2f3f37e37be17d3cce28df8 135.27MB / 262.02MB 4.2s
2025-Dec-12 20:41:25.058153
#9 sha256:67f017dc59dd7cc1b48f98090d0a6561de33c508a2f3f37e37be17d3cce28df8 152.04MB / 262.02MB 4.8s
2025-Dec-12 20:41:25.058153
#9 sha256:67f017dc59dd7cc1b48f98090d0a6561de33c508a2f3f37e37be17d3cce28df8 170.92MB / 262.02MB 5.3s
2025-Dec-12 20:41:25.058153
#9 sha256:67f017dc59dd7cc1b48f98090d0a6561de33c508a2f3f37e37be17d3cce28df8 185.60MB / 262.02MB 5.6s
2025-Dec-12 20:41:25.058153
#9 sha256:67f017dc59dd7cc1b48f98090d0a6561de33c508a2f3f37e37be17d3cce28df8 203.42MB / 262.02MB 6.2s
2025-Dec-12 20:41:25.058153
#9 sha256:67f017dc59dd7cc1b48f98090d0a6561de33c508a2f3f37e37be17d3cce28df8 222.30MB / 262.02MB 6.7s
2025-Dec-12 20:41:25.058153
#9 sha256:67f017dc59dd7cc1b48f98090d0a6561de33c508a2f3f37e37be17d3cce28df8 235.93MB / 262.02MB 7.1s
2025-Dec-12 20:41:25.058153
#9 sha256:67f017dc59dd7cc1b48f98090d0a6561de33c508a2f3f37e37be17d3cce28df8 249.56MB / 262.02MB 7.9s
2025-Dec-12 20:41:25.058153
#9 sha256:67f017dc59dd7cc1b48f98090d0a6561de33c508a2f3f37e37be17d3cce28df8 262.02MB / 262.02MB 8.9s done
2025-Dec-12 20:41:25.058153
#9 extracting sha256:67f017dc59dd7cc1b48f98090d0a6561de33c508a2f3f37e37be17d3cce28df8
2025-Dec-12 20:41:25.058153
#9 extracting sha256:67f017dc59dd7cc1b48f98090d0a6561de33c508a2f3f37e37be17d3cce28df8 5.1s
2025-Dec-12 20:41:25.058153
#9 extracting sha256:67f017dc59dd7cc1b48f98090d0a6561de33c508a2f3f37e37be17d3cce28df8 10.1s
2025-Dec-12 20:41:25.058153
#9 extracting sha256:67f017dc59dd7cc1b48f98090d0a6561de33c508a2f3f37e37be17d3cce28df8 13.2s done
2025-Dec-12 20:41:25.058153
#9 DONE 23.7s
2025-Dec-12 20:41:25.058153
2025-Dec-12 20:41:25.058153
#10 [builder 2/5] RUN apt-get update && apt-get install -y pkg-config libssl-dev && rm -rf /var/lib/apt/lists/*
2025-Dec-12 20:41:25.058153
#10 0.141 Get:1 http://deb.debian.org/debian bookworm InRelease [151 kB]
2025-Dec-12 20:41:25.058153
#10 0.169 Get:2 http://deb.debian.org/debian bookworm-updates InRelease [55.4 kB]
2025-Dec-12 20:41:25.058153
#10 0.169 Get:3 http://deb.debian.org/debian-security bookworm-security InRelease [48.0 kB]
2025-Dec-12 20:41:25.058153
#10 0.266 Get:4 http://deb.debian.org/debian bookworm/main amd64 Packages [8791 kB]
2025-Dec-12 20:41:25.058153
#10 0.381 Get:5 http://deb.debian.org/debian bookworm-updates/main amd64 Packages [6924 B]
2025-Dec-12 20:41:25.058153
#10 0.389 Get:6 http://deb.debian.org/debian-security bookworm-security/main amd64 Packages [290 kB]
2025-Dec-12 20:41:25.058153
#10 1.362 Fetched 9343 kB in 1s (7580 kB/s)
2025-Dec-12 20:41:25.058153
#10 1.362 Reading package lists...
2025-Dec-12 20:41:25.058153
#10 2.347 Reading package lists...
2025-Dec-12 20:41:25.058153
#10 3.373 Building dependency tree...
2025-Dec-12 20:41:25.058153
#10 3.552 Reading state information...
2025-Dec-12 20:41:25.058153
#10 3.701 The following additional packages will be installed:
2025-Dec-12 20:41:25.058153
#10 3.701   libpkgconf3 libssl3 openssl pkgconf pkgconf-bin
2025-Dec-12 20:41:25.058153
#10 3.702 Suggested packages:
2025-Dec-12 20:41:25.058153
#10 3.702   libssl-doc
2025-Dec-12 20:41:25.058153
#10 3.768 The following NEW packages will be installed:
2025-Dec-12 20:41:25.058153
#10 3.769   libpkgconf3 libssl-dev pkg-config pkgconf pkgconf-bin
2025-Dec-12 20:41:25.058153
#10 3.769 The following packages will be upgraded:
2025-Dec-12 20:41:25.058153
#10 3.770   libssl3 openssl
2025-Dec-12 20:41:25.058153
#10 3.801 2 upgraded, 5 newly installed, 0 to remove and 53 not upgraded.
2025-Dec-12 20:41:25.058153
#10 3.801 Need to get 6009 kB of archives.
2025-Dec-12 20:41:25.058153
#10 3.801 After this operation, 12.9 MB of additional disk space will be used.
2025-Dec-12 20:41:25.058153
#10 3.801 Get:1 http://deb.debian.org/debian bookworm/main amd64 libpkgconf3 amd64 1.8.1-1 [36.1 kB]
2025-Dec-12 20:41:25.058153
#10 3.817 Get:2 http://deb.debian.org/debian-security bookworm-security/main amd64 libssl3 amd64 3.0.17-1~deb12u3 [2028 kB]
2025-Dec-12 20:41:25.058153
#10 3.841 Get:3 http://deb.debian.org/debian-security bookworm-security/main amd64 libssl-dev amd64 3.0.17-1~deb12u3 [2441 kB]
2025-Dec-12 20:41:25.058153
#10 3.863 Get:4 http://deb.debian.org/debian-security bookworm-security/main amd64 openssl amd64 3.0.17-1~deb12u3 [1434 kB]
2025-Dec-12 20:41:25.058153
#10 3.875 Get:5 http://deb.debian.org/debian bookworm/main amd64 pkgconf-bin amd64 1.8.1-1 [29.5 kB]
2025-Dec-12 20:41:25.058153
#10 3.875 Get:6 http://deb.debian.org/debian bookworm/main amd64 pkgconf amd64 1.8.1-1 [25.9 kB]
2025-Dec-12 20:41:25.058153
#10 3.875 Get:7 http://deb.debian.org/debian bookworm/main amd64 pkg-config amd64 1.8.1-1 [13.7 kB]
2025-Dec-12 20:41:25.058153
#10 4.245 debconf: delaying package configuration, since apt-utils is not installed
2025-Dec-12 20:41:25.058153
#10 4.273 Fetched 6009 kB in 0s (59.5 MB/s)
2025-Dec-12 20:41:25.058153
#10 4.303 Selecting previously unselected package libpkgconf3:amd64.
2025-Dec-12 20:41:25.058153
#10 4.303 (Reading database ... 
(Reading database ... 5%
(Reading database ... 10%
(Reading database ... 15%
(Reading database ... 20%
(Reading database ... 25%
(Reading database ... 30%
(Reading database ... 35%
(Reading database ... 40%
(Reading database ... 45%
(Reading database ... 50%
(Reading database ... 55%
(Reading database ... 60%
(Reading database ... 65%
(Reading database ... 70%
(Reading database ... 75%
(Reading database ... 80%
(Reading database ... 85%
(Reading database ... 90%
(Reading database ... 95%
(Reading database ... 100%
(Reading database ... 9027 files and directories currently installed.)
2025-Dec-12 20:41:25.058153
#10 4.313 Preparing to unpack .../0-libpkgconf3_1.8.1-1_amd64.deb ...
2025-Dec-12 20:41:25.058153
#10 4.319 Unpacking libpkgconf3:amd64 (1.8.1-1) ...
2025-Dec-12 20:41:25.058153
#10 4.354 Preparing to unpack .../1-libssl3_3.0.17-1~deb12u3_amd64.deb ...
2025-Dec-12 20:41:25.058153
#10 4.362 Unpacking libssl3:amd64 (3.0.17-1~deb12u3) over (3.0.15-1~deb12u1) ...
2025-Dec-12 20:41:25.058153
#10 4.578 Selecting previously unselected package libssl-dev:amd64.
2025-Dec-12 20:41:25.058153
#10 4.581 Preparing to unpack .../2-libssl-dev_3.0.17-1~deb12u3_amd64.deb ...
2025-Dec-12 20:41:25.058153
#10 4.583 Unpacking libssl-dev:amd64 (3.0.17-1~deb12u3) ...
2025-Dec-12 20:41:25.058153
#10 4.835 Preparing to unpack .../3-openssl_3.0.17-1~deb12u3_amd64.deb ...
2025-Dec-12 20:41:25.058153
#10 4.842 Unpacking openssl (3.0.17-1~deb12u3) over (3.0.15-1~deb12u1) ...
2025-Dec-12 20:41:25.058153
#10 4.950 Selecting previously unselected package pkgconf-bin.
2025-Dec-12 20:41:25.058153
#10 4.953 Preparing to unpack .../4-pkgconf-bin_1.8.1-1_amd64.deb ...
2025-Dec-12 20:41:25.058153
#10 4.956 Unpacking pkgconf-bin (1.8.1-1) ...
2025-Dec-12 20:41:25.058153
#10 4.985 Selecting previously unselected package pkgconf:amd64.
2025-Dec-12 20:41:25.058153
#10 4.987 Preparing to unpack .../5-pkgconf_1.8.1-1_amd64.deb ...
2025-Dec-12 20:41:25.058153
#10 4.991 Unpacking pkgconf:amd64 (1.8.1-1) ...
2025-Dec-12 20:41:25.058153
#10 5.016 Selecting previously unselected package pkg-config:amd64.
2025-Dec-12 20:41:25.058153
#10 5.018 Preparing to unpack .../6-pkg-config_1.8.1-1_amd64.deb ...
2025-Dec-12 20:41:25.058153
#10 5.022 Unpacking pkg-config:amd64 (1.8.1-1) ...
2025-Dec-12 20:41:25.058153
#10 5.049 Setting up libssl3:amd64 (3.0.17-1~deb12u3) ...
2025-Dec-12 20:41:25.058153
#10 5.056 Setting up libpkgconf3:amd64 (1.8.1-1) ...
2025-Dec-12 20:41:25.058153
#10 5.063 Setting up libssl-dev:amd64 (3.0.17-1~deb12u3) ...
2025-Dec-12 20:41:25.058153
#10 5.069 Setting up pkgconf-bin (1.8.1-1) ...
2025-Dec-12 20:41:25.058153
#10 5.075 Setting up openssl (3.0.17-1~deb12u3) ...
2025-Dec-12 20:41:25.058153
#10 5.086 Setting up pkgconf:amd64 (1.8.1-1) ...
2025-Dec-12 20:41:25.058153
#10 5.094 Setting up pkg-config:amd64 (1.8.1-1) ...
2025-Dec-12 20:41:25.058153
#10 5.104 Processing triggers for libc-bin (2.36-9+deb12u9) ...
2025-Dec-12 20:41:25.058153
#10 DONE 5.4s
2025-Dec-12 20:41:25.058153
2025-Dec-12 20:41:25.058153
#11 [builder 3/5] WORKDIR /app
2025-Dec-12 20:41:25.058153
#11 DONE 0.0s
2025-Dec-12 20:41:25.058153
2025-Dec-12 20:41:25.058153
#12 [builder 4/5] COPY . .
2025-Dec-12 20:41:25.058153
#12 DONE 0.0s
2025-Dec-12 20:41:25.058153
2025-Dec-12 20:41:25.058153
#13 [builder 5/5] RUN cargo build --release --bin server
2025-Dec-12 20:41:25.058153
#13 0.151     Updating crates.io index
2025-Dec-12 20:41:25.058153
#13 2.413      Locking 325 packages to latest compatible versions
2025-Dec-12 20:41:25.058153
#13 2.416       Adding axum v0.6.20 (available: v0.8.7)
2025-Dec-12 20:41:25.058153
#13 2.418       Adding base64 v0.21.7 (available: v0.22.1)
2025-Dec-12 20:41:25.058153
#13 2.418       Adding base64ct v1.8.1 (requires Rust 1.85)
2025-Dec-12 20:41:25.058153
#13 2.426       Adding generic-array v0.14.7 (available: v0.14.9)
2025-Dec-12 20:41:25.058153
#13 2.430       Adding home v0.5.12 (requires Rust 1.88)
2025-Dec-12 20:41:25.058153
#13 2.442       Adding rand v0.8.5 (available: v0.9.2)
2025-Dec-12 20:41:25.058153
#13 2.444       Adding reqwest v0.11.27 (available: v0.12.25)
2025-Dec-12 20:41:25.058153
#13 2.456       Adding sqlx v0.7.4 (available: v0.8.6)
2025-Dec-12 20:41:25.058153
#13 2.462       Adding sysinfo v0.29.11 (available: v0.36.1)
2025-Dec-12 20:41:25.058153
#13 2.463       Adding thiserror v1.0.69 (available: v2.0.17)
2025-Dec-12 20:41:25.058153
#13 2.466       Adding tokio-tungstenite v0.20.1 (available: v0.28.0)
2025-Dec-12 20:41:25.058153
#13 2.466       Adding tower v0.4.13 (available: v0.5.2)
2025-Dec-12 20:41:25.058153
#13 2.466       Adding tower-http v0.4.4 (available: v0.6.8)
2025-Dec-12 20:41:25.058153
#13 2.494  Downloading crates ...
2025-Dec-12 20:41:25.058153
#13 2.544   Downloaded async-compression v0.4.36
2025-Dec-12 20:41:25.058153
#13 2.558   Downloaded hex v0.4.3
2025-Dec-12 20:41:25.058153
#13 2.561   Downloaded tinyvec_macros v0.1.1
2025-Dec-12 20:41:25.058153
#13 2.563   Downloaded thread_local v1.1.9
2025-Dec-12 20:41:25.058153
#13 2.566   Downloaded tinyvec v1.10.0
2025-Dec-12 20:41:25.058153
#13 2.572   Downloaded try-lock v0.2.5
2025-Dec-12 20:41:25.058153
#13 2.574   Downloaded tracing-log v0.2.0
2025-Dec-12 20:41:25.058153
#13 2.579   Downloaded ppv-lite86 v0.2.21
2025-Dec-12 20:41:25.058153
#13 2.583   Downloaded simd-adler32 v0.3.8
2025-Dec-12 20:41:25.058153
#13 2.590   Downloaded tracing v0.1.43
2025-Dec-12 20:41:25.058153
#13 2.600   Downloaded sqlx-postgres v0.7.4
2025-Dec-12 20:41:25.058153
#13 2.616   Downloaded syn v1.0.109
2025-Dec-12 20:41:25.058153
#13 2.640   Downloaded serde_path_to_error v0.1.20
2025-Dec-12 20:41:25.058153
#13 2.647   Downloaded parking_lot v0.12.5
2025-Dec-12 20:41:25.058153
#13 2.654   Downloaded pkcs1 v0.7.5
2025-Dec-12 20:41:25.058153
#13 2.661   Downloaded quote v1.0.42
2025-Dec-12 20:41:25.058153
#13 2.669   Downloaded rand v0.8.5
2025-Dec-12 20:41:25.058153
#13 2.680   Downloaded parking_lot_core v0.9.12
2025-Dec-12 20:41:25.058153
#13 2.687   Downloaded proc-macro2 v1.0.103
2025-Dec-12 20:41:25.058153
#13 2.694   Downloaded sync_wrapper v0.1.2
2025-Dec-12 20:41:25.058153
#13 2.700   Downloaded rustc_version v0.4.1
2025-Dec-12 20:41:25.058153
#13 2.704   Downloaded sha1 v0.10.6
2025-Dec-12 20:41:25.058153
#13 2.724   Downloaded scopeguard v1.2.0
2025-Dec-12 20:41:25.058153
#13 2.728   Downloaded semver v0.9.0
2025-Dec-12 20:41:25.058153
#13 2.732   Downloaded serde_urlencoded v0.7.1
2025-Dec-12 20:41:25.058153
#13 2.735   Downloaded serde_derive v1.0.228
2025-Dec-12 20:41:25.058153
#13 2.752   Downloaded serde_core v1.0.228
2025-Dec-12 20:41:25.058153
#13 2.760   Downloaded socket2 v0.5.10
2025-Dec-12 20:41:25.058153
#13 2.784   Downloaded icu_properties_data v2.1.2
2025-Dec-12 20:41:25.058153
#13 2.829   Downloaded serde_with v1.14.0
2025-Dec-12 20:41:25.058153
#13 2.845   Downloaded sqlx-core v0.7.4
2025-Dec-12 20:41:25.058153
#13 2.862   Downloaded serde_json v1.0.145
2025-Dec-12 20:41:25.058153
#13 2.894   Downloaded rayon v1.11.0
2025-Dec-12 20:41:25.058153
#13 2.916   Downloaded chrono v0.4.42
2025-Dec-12 20:41:25.058153
#13 2.942   Downloaded sqlx v0.7.4
2025-Dec-12 20:41:25.058153
#13 3.004   Downloaded hyper v0.14.32
2025-Dec-12 20:41:25.058153
#13 3.018   Downloaded hkdf v0.12.4
2025-Dec-12 20:41:25.058153
#13 3.022   Downloaded ryu v1.0.20
2025-Dec-12 20:41:25.058153
#13 3.028   Downloaded socket2 v0.6.1
2025-Dec-12 20:41:25.058153
#13 3.031   Downloaded syn v2.0.111
2025-Dec-12 20:41:25.058153
#13 3.051   Downloaded sqlx-macros-core v0.7.4
2025-Dec-12 20:41:25.058153
#13 3.056   Downloaded sharded-slab v0.1.7
2025-Dec-12 20:41:25.058153
#13 3.062   Downloaded reqwest v0.11.27
2025-Dec-12 20:41:25.058153
#13 3.076   Downloaded rustix v1.1.2
2025-Dec-12 20:41:25.058153
#13 3.166   Downloaded rayon-core v1.13.0
2025-Dec-12 20:41:25.058153
#13 3.188   Downloaded idna v1.1.0
2025-Dec-12 20:41:25.058153
#13 3.197   Downloaded ed25519-dalek v2.2.0
2025-Dec-12 20:41:25.058153
#13 3.205   Downloaded rand_core v0.6.4
2025-Dec-12 20:41:25.058153
#13 3.223   Downloaded subtle v2.6.1
2025-Dec-12 20:41:25.058153
#13 3.226   Downloaded sqlx-mysql v0.7.4
2025-Dec-12 20:41:25.058153
#13 3.249   Downloaded rustversion v1.0.22
2025-Dec-12 20:41:25.058153
#13 3.255   Downloaded rustls-pemfile v1.0.4
2025-Dec-12 20:41:25.058153
#13 3.259   Downloaded synstructure v0.13.2
2025-Dec-12 20:41:25.058153
#13 3.261   Downloaded sqlformat v0.2.6
2025-Dec-12 20:41:25.058153
#13 3.264   Downloaded spki v0.7.3
2025-Dec-12 20:41:25.058153
#13 3.268   Downloaded strsim v0.10.0
2025-Dec-12 20:41:25.058153
#13 3.272   Downloaded stringprep v0.1.5
2025-Dec-12 20:41:25.058153
#13 3.275   Downloaded sqlx-macros v0.7.4
2025-Dec-12 20:41:25.058153
#13 3.276   Downloaded slab v0.4.11
2025-Dec-12 20:41:25.058153
#13 3.279   Downloaded rsa v0.9.9
2025-Dec-12 20:41:25.058153
#13 3.309   Downloaded serde_with_macros v1.5.2
2025-Dec-12 20:41:25.058153
#13 3.311   Downloaded semver-parser v0.7.0
2025-Dec-12 20:41:25.058153
#13 3.329   Downloaded semver v1.0.27
2025-Dec-12 20:41:25.058153
#13 3.333   Downloaded sysinfo v0.29.11
2025-Dec-12 20:41:25.058153
#13 3.351   Downloaded icu_properties v2.1.2
2025-Dec-12 20:41:25.058153
#13 3.355   Downloaded icu_normalizer_data v2.1.1
2025-Dec-12 20:41:25.058153
#13 3.359   Downloaded der v0.7.10
2025-Dec-12 20:41:25.058153
#13 3.369   Downloaded crossbeam-epoch v0.9.18
2025-Dec-12 20:41:25.058153
#13 3.374   Downloaded smallvec v1.15.1
2025-Dec-12 20:41:25.058153
#13 3.478   Downloaded serde v1.0.228
2025-Dec-12 20:41:25.058153
#13 3.487   Downloaded futures v0.3.31
2025-Dec-12 20:41:25.058153
#13 3.498   Downloaded crc32fast v1.5.0
2025-Dec-12 20:41:25.058153
#13 3.502   Downloaded rand_chacha v0.3.1
2025-Dec-12 20:41:25.058153
#13 3.505   Downloaded stable_deref_trait v1.2.1
2025-Dec-12 20:41:25.058153
#13 3.506   Downloaded sqlx-sqlite v0.7.4
2025-Dec-12 20:41:25.058153
#13 3.537   Downloaded signal-hook-registry v1.4.7
2025-Dec-12 20:41:25.058153
#13 3.540   Downloaded libm v0.2.15
2025-Dec-12 20:41:25.058153
#13 3.565   Downloaded utf8_iter v1.0.4
2025-Dec-12 20:41:25.058153
#13 3.580   Downloaded heck v0.4.1
2025-Dec-12 20:41:25.058153
#13 3.582   Downloaded fastrand v2.3.0
2025-Dec-12 20:41:25.058153
#13 3.585   Downloaded linux-raw-sys v0.11.0
2025-Dec-12 20:41:25.058153
#13 3.868   Downloaded dyn-clone v1.0.20
2025-Dec-12 20:41:25.058153
#13 3.871   Downloaded ipnet v2.11.0
2025-Dec-12 20:41:25.058153
#13 3.874   Downloaded zerovec-derive v0.11.2
2025-Dec-12 20:41:25.058153
#13 3.876   Downloaded unicode-normalization v0.1.25
2025-Dec-12 20:41:25.058153
#13 3.881   Downloaded hyper-tls v0.5.0
2025-Dec-12 20:41:25.058153
#13 3.883   Downloaded futures-task v0.3.31
2025-Dec-12 20:41:25.058153
#13 3.884   Downloaded const-oid v0.9.6
2025-Dec-12 20:41:25.058153
#13 3.887   Downloaded compression-codecs v0.4.35
2025-Dec-12 20:41:25.058153
#13 3.894   Downloaded shlex v1.3.0
2025-Dec-12 20:41:25.058153
#13 3.896   Downloaded rustc_version v0.2.3
2025-Dec-12 20:41:25.058153
#13 3.898   Downloaded paste v1.0.15
2025-Dec-12 20:41:25.058153
#13 3.915   Downloaded lazy_static v1.5.0
2025-Dec-12 20:41:25.058153
#13 3.918   Downloaded encoding_rs v0.8.35
2025-Dec-12 20:41:25.058153
#13 4.007   Downloaded unicode-segmentation v1.12.0
2025-Dec-12 20:41:25.058153
#13 4.028   Downloaded iana-time-zone v0.1.64
2025-Dec-12 20:41:25.058153
#13 4.033   Downloaded getrandom v0.2.16
2025-Dec-12 20:41:25.058153
#13 4.039   Downloaded futures-intrusive v0.5.0
2025-Dec-12 20:41:25.058153
#13 4.048   Downloaded percent-encoding v2.3.2
2025-Dec-12 20:41:25.058153
#13 4.050   Downloaded openssl v0.10.75
2025-Dec-12 20:41:25.058153
#13 4.083   Downloaded num-bigint-dig v0.8.6
2025-Dec-12 20:41:25.058153
#13 4.091   Downloaded nu-ansi-term v0.50.3
2025-Dec-12 20:41:25.058153
#13 4.095   Downloaded matchit v0.7.3
2025-Dec-12 20:41:25.058153
#13 4.098   Downloaded log v0.4.29
2025-Dec-12 20:41:25.058153
#13 4.103   Downloaded version_check v0.9.5
2025-Dec-12 20:41:25.058153
#13 4.105   Downloaded vcpkg v0.2.15
2025-Dec-12 20:41:25.058153
#13 4.202   Downloaded urlencoding v2.1.3
2025-Dec-12 20:41:25.058153
#13 4.204   Downloaded find-msvc-tools v0.1.5
2025-Dec-12 20:41:25.058153
#13 4.206   Downloaded curve25519-dalek v4.1.3
2025-Dec-12 20:41:25.058153
#13 4.221   Downloaded crc v3.4.0
2025-Dec-12 20:41:25.058153
#13 4.226   Downloaded bitflags v1.3.2
2025-Dec-12 20:41:25.058153
#13 4.249   Downloaded axum v0.6.20
2025-Dec-12 20:41:25.058153
#13 4.263   Downloaded miniz_oxide v0.8.9
2025-Dec-12 20:41:25.058153
#13 4.268   Downloaded mime_guess v2.0.5
2025-Dec-12 20:41:25.058153
#13 4.271   Downloaded zerovec v0.11.5
2025-Dec-12 20:41:25.058153
#13 4.281   Downloaded typenum v1.19.0
2025-Dec-12 20:41:25.058153
#13 4.286   Downloaded icu_provider v2.1.1
2025-Dec-12 20:41:25.058153
#13 4.340   Downloaded http v0.2.12
2025-Dec-12 20:41:25.058153
#13 4.346   Downloaded futures-util v0.3.31
2025-Dec-12 20:41:25.058153
#13 4.368   Downloaded foreign-types v0.3.2
2025-Dec-12 20:41:25.058153
#13 4.369   Downloaded flate2 v1.1.5
2025-Dec-12 20:41:25.058153
#13 4.378   Downloaded darling v0.13.4
2025-Dec-12 20:41:25.058153
#13 4.382   Downloaded native-tls v0.2.14
2025-Dec-12 20:41:25.058153
#13 4.386   Downloaded memchr v2.7.6
2025-Dec-12 20:41:25.058153
#13 4.395   Downloaded litemap v0.8.1
2025-Dec-12 20:41:25.058153
#13 4.399   Downloaded itoa v1.0.15
2025-Dec-12 20:41:25.058153
#13 4.401   Downloaded url v2.5.7
2025-Dec-12 20:41:25.058153
#13 4.405   Downloaded unicode-ident v1.0.22
2025-Dec-12 20:41:25.058153
#13 4.410   Downloaded unicode-bidi v0.3.18
2025-Dec-12 20:41:25.058153
#13 4.414   Downloaded tungstenite v0.20.1
2025-Dec-12 20:41:25.058153
#13 4.420   Downloaded icu_normalizer v2.1.1
2025-Dec-12 20:41:25.058153
#13 4.426   Downloaded icu_locale_core v2.1.1
2025-Dec-12 20:41:25.058153
#13 4.438   Downloaded http-body v0.4.6
2025-Dec-12 20:41:25.058153
#13 4.441   Downloaded home v0.5.12
2025-Dec-12 20:41:25.058153
#13 4.483 error: failed to parse manifest at `/usr/local/cargo/registry/src/index.crates.io-6f17d22bba15001f/home-0.5.12/Cargo.toml`
2025-Dec-12 20:41:25.058153
#13 4.483
2025-Dec-12 20:41:25.058153
#13 4.483 Caused by:
2025-Dec-12 20:41:25.058153
#13 4.483   feature `edition2024` is required
2025-Dec-12 20:41:25.058153
#13 4.483
2025-Dec-12 20:41:25.058153
#13 4.483   The package requires the Cargo feature called `edition2024`, but that feature is not stabilized in this version of Cargo (1.83.0 (5ffbef321 2024-10-29)).
2025-Dec-12 20:41:25.058153
#13 4.483   Consider trying a newer version of Cargo (this may require the nightly release).
2025-Dec-12 20:41:25.058153
#13 4.483   See https://doc.rust-lang.org/nightly/cargo/reference/unstable.html#edition-2024 for more information about the status of this feature.
2025-Dec-12 20:41:25.058153
#13 ERROR: process "/bin/sh -c cargo build --release --bin server" did not complete successfully: exit code: 101
2025-Dec-12 20:41:25.058153
------
2025-Dec-12 20:41:25.058153
> [builder 5/5] RUN cargo build --release --bin server:
2025-Dec-12 20:41:25.058153
4.438   Downloaded http-body v0.4.6
2025-Dec-12 20:41:25.058153
4.441   Downloaded home v0.5.12
2025-Dec-12 20:41:25.058153
4.483 error: failed to parse manifest at `/usr/local/cargo/registry/src/index.crates.io-6f17d22bba15001f/home-0.5.12/Cargo.toml`
2025-Dec-12 20:41:25.058153
4.483
2025-Dec-12 20:41:25.058153
4.483 Caused by:
2025-Dec-12 20:41:25.058153
4.483   feature `edition2024` is required
2025-Dec-12 20:41:25.058153
4.483
2025-Dec-12 20:41:25.058153
4.483   The package requires the Cargo feature called `edition2024`, but that feature is not stabilized in this version of Cargo (1.83.0 (5ffbef321 2024-10-29)).
2025-Dec-12 20:41:25.058153
4.483   Consider trying a newer version of Cargo (this may require the nightly release).
2025-Dec-12 20:41:25.058153
4.483   See https://doc.rust-lang.org/nightly/cargo/reference/unstable.html#edition-2024 for more information about the status of this feature.
2025-Dec-12 20:41:25.058153
------
2025-Dec-12 20:41:25.058153
2025-Dec-12 20:41:25.058153
1 warning found (use docker --debug to expand):
2025-Dec-12 20:41:25.058153
- FromAsCasing: 'as' and 'FROM' keywords' casing do not match (line 3)
2025-Dec-12 20:41:25.058153
Dockerfile:20
2025-Dec-12 20:41:25.058153
--------------------
2025-Dec-12 20:41:25.058153
18 |     # Compilar o binario do SERVIDOR em modo release
2025-Dec-12 20:41:25.058153
19 |     # O binario do agente nao precisa ser compilado aqui, pois roda no cliente Windows
2025-Dec-12 20:41:25.058153
20 | >>> RUN cargo build --release --bin server
2025-Dec-12 20:41:25.058153
21 |
2025-Dec-12 20:41:25.058153
22 |     # --- ESTAGIO 2: RUNTIME (Execucao Leve) ---
2025-Dec-12 20:41:25.058153
--------------------
2025-Dec-12 20:41:25.058153
ERROR: failed to build: failed to solve: process "/bin/sh -c cargo build --release --bin server" did not complete successfully: exit code: 101
2025-Dec-12 20:41:25.058153
exit status 1
2025-Dec-12 20:41:25.149602
========================================
2025-Dec-12 20:41:25.159265
