# Incremental Flutter build setup

This composite action prepares a reproducible Flutter build in four layers:

1. pinned Flutter SDK and Pub packages;
2. build_runner asset graph and generated Dart sources;
3. Flutter AOT intermediates;
4. Windows native assets and CMake/MSVC outputs.

The three Windows build paths are restored and saved together. Flutter may skip
native-asset generation when its AOT state is current, so caching only part of
that state can produce an incomplete Windows bundle.

Cache keys use the dependency lock plus a build-input fingerprint. Parallel
jobs and reruns of the same source state therefore share one immutable cache;
new source states can still restore the latest compatible cache incrementally.

## Usage

```yaml
- uses: ./.github/actions/prepare-flutter-build
  with:
    flutter-version: ${{ env.FLUTTER_VERSION }}
    cache-windows-build: "true"

- run: flutter build windows --debug --no-pub
```

`cache-windows-build` should be enabled only on Windows build jobs. Analysis and
test jobs still reuse the SDK, Pub, and generated-code layers.

Dependency resolution enforces the committed lockfile. The repository workflows
set `PUB_HOSTED_URL` to the hosted source recorded in that lockfile, preventing
source URL normalization from dirtying `pubspec.lock` during CI.

The maintainer-dispatched portable workflow also caches the completed bundle by
build-input fingerprint, build-recipe version, Flutter version, build mode, and
runner class. The fingerprint covers the workflow, this composite action, and
the packaging and verification scripts. An exact hit skips Flutter setup and
compilation, then the formal release packager regenerates and verifies the
user-ready portable archive and `app_files_manifest.json`.

## Prewarmed runners

Persistent runners can set `cache-flutter-sdk` and `cache-pub-dependencies` to
`"false"` after the pinned SDK and Pub cache have been preloaded. The manual
portable workflow allows a configured persistent runner only for `main` and
`v*` tag refs. Tagged releases already check out and verify their release tag.
Hosted and persistent runners use disjoint Pub, codegen, CMake, and exact-bundle
cache namespaces. Pull-request jobs remain on GitHub-hosted runners.

The optional repository variables are:

- `WINDOWS_FLUTTER_RUNNER`: trusted persistent runner label; when unset,
  workflows use `windows-2022`;
- `WINDOWS_FLUTTER_SDK_CACHE`: set to `false` when Flutter is preinstalled;
- `WINDOWS_PUB_CACHE`: set to `false` when the Pub cache persists locally.
