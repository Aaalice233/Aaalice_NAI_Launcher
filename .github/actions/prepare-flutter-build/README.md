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
build-input fingerprint, Flutter version, and build mode. Documentation,
workflow, and test-only commits can therefore reuse an identical bundle. An
exact hit skips Flutter setup and compilation, then uploads the verified bundle
directly.

## Prewarmed runners

Persistent runners can set `cache-flutter-sdk` and `cache-pub-dependencies` to
`"false"` after the pinned SDK and Pub cache have been preloaded. The manual
portable workflow and tagged release workflow expose this through repository
variables. Pull-request jobs remain on GitHub-hosted runners so untrusted code
does not execute on a persistent machine.

The optional repository variables are:

- `WINDOWS_FLUTTER_RUNNER`: trusted runner label, default `windows-2022`;
- `WINDOWS_FLUTTER_SDK_CACHE`: set to `false` when Flutter is preinstalled;
- `WINDOWS_PUB_CACHE`: set to `false` when the Pub cache persists locally.
