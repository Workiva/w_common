// Copyright 2016 Workiva Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

/// This entry point has been split into separate VM and browser entry points;
/// use disposable_vm.dart or disposable_browser.dart instead.
@deprecated
export 'package:w_common/src/disposable/disposable_vm.dart'
    show Disposable, Disposer;
export 'package:w_common/src/disposable_manager/disposable_manager_vm.dart'
    show
        DisposableManager,
        DisposableManagerV2,
        DisposableManagerV3,
        ObjectDisposedException;
