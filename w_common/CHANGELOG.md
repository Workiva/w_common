## [3.3.0](https://github.com/Workiva/w_common/compare/3.2.0...3.3.0)
- Allow a nullable to be managed via `Disposable.manageDisposable` and 
`Disposable.manageAndReturnTypedDisposable`.

## [3.2.0](https://github.com/Workiva/w_common/compare/3.1.0...3.2.0)

- Adds JsonMap and JsonMapObject typedefs

## [3.1.0](https://github.com/Workiva/w_common/compare/3.0.0...3.1.0)

- Adds JsonMap and JsonMapObject typedefs
- Update SDK minimum to 2.19.0 to support the non-function
 typedef language feature.
- Raised package versions to their first nullsafe version.

## [3.0.0](https://github.com/Workiva/w_common/compare/2.1.2...3.0.0)

- Migrate to null-safety.

## [2.1.1](https://github.com/Workiva/w_common/compare/2.1.0...2.1.1)

- Implement `_ObservableTimer.tick`, which allows timers created via
`Disposable.getManagedTimer` and `Disposable.getManagedPeriodicTimer` to be
controlled by the [`fake_async` package](https://pub.dev/packages/fake_async).

## [2.0.0](https://github.com/Workiva/w_common/compare/1.21.8...2.0.0)
_June 14, 2022_

**Breaking Changes:**
- Removes sass compilation tool from w_common. Use w_common_tools instead.
- Removes `DisposableManager`, `DisposableManagerV2`, `DisposableManagerV3`,
`DisposableManagerV4`, `DisposableManagerV5`, and `DisposableManagerV6`. Use
`DisposableManagerV7` instead.
- Removes `w_common.dart` entrypoint. Use the specific entrypoint related to
the pieces of w_common you want to use instead. For example,
`package:w_common/disposable.dart`.
- Changes to `Cache`:
  - Removes `keys` getter. Use `liveKeys` and `releasedKeys` instead.
  - Removes `values` getter. Use `liveValues` instead.
  - Removes `containsKey` method. Use `.contains` on `liveKeys` and `releasedKeys`
  instead.
- Changes to `Disposable`:
  - Removes `isDisposedOrDisposing`. Use `isOrWillBeDisposed` instead. This also returns
  true when the `Disposable` instance is in the "awaiting disposal" state that
  is entered as soon as [dispose] is called.
  - Removes `isDisposing`. Use `isOrWillBeDisposed` instead.
  - Removes `manageAndReturnDisposable`. Use `manageAndReturnTypedDisposable` instead.
  - Removes `manageDisposer`. Use `getManagedDisposer` instead.
  - Removes `manageStreamSubscription`. Use `listenToStream` instead.


## [1.21.8](https://github.com/Workiva/w_common/compare/1.21.7...1.21.8)
_June 2, 2022_

- Added w_common_tools as a separate package.
