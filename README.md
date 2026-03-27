# git-ios

`git-ios` packages Git as iOS XCFrameworks for hosts that already use the `ios_system` command model.

Current products:

- `git.xcframework`
- `gitremote.xcframework`

These are meant to be embedded in an iOS app and loaded through a command registry such as a-Shell's `commandDictionary.plist`.

The package reuses the existing a-Shell transport stack:

- `curl_ios`
- `openssl`
- `libssh2`
- `ssh_cmd`

So HTTPS and SSH stay on the same runtime stack the host already ships.

## Commands

The packaged entrypoints are:

- `git_main`
- `git_remote_http_main`
- `git_remote_https_main`

Typical host-side registration maps:

- `git` -> `git.framework/git` + `git_main`
- `git-remote-http` -> `gitremote.framework/gitremote` + `git_remote_http_main`
- `git-remote-https` -> `gitremote.framework/gitremote` + `git_remote_https_main`

For SSH remotes, point Git at the host's existing `ssh` command through `PATH` or `GIT_SSH`.

## Build

Build the xcframeworks with:

```sh
./build_xcframework.sh
```

By default the script expects these dependencies next to the repo:

- `../a-Shell/xcfs/.build/artifacts/xcfs/openssl/openssl.xcframework`
- `../a-Shell/xcfs/.build/artifacts/xcfs/curl_ios/curl_ios.xcframework`
- `../a-Shell/xcfs/.build/artifacts/xcfs/libssh2/libssh2.xcframework`

Build outputs:

- `Artifacts/git.xcframework`
- `Artifacts/gitremote.xcframework`

## Swift Package

Use it from SwiftPM with:

```swift
.package(url: "https://github.com/zats/git-ios", branch: "main")
```

Product:

- `GitIOS`

## Notes

- This targets embedded iOS hosts, not desktop Git installs.
- Hooks, pagers, editors, and other desktop integrations are outside the current scope.
- The source tree starts from upstream Git and adds the minimum packaging and compatibility changes needed for iOS embedding.
