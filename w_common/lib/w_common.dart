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

/// Deprecated: 1.6.0
/// To be removed: 2.0.0
///
/// This entry point is deprecated in favor of consumers importing the specific
/// pieces of w_common they want to use. For example, to leverage the disposable
/// classes:
///
///     import 'package:w_common/disposable.dart';
@deprecated
library w_common;

export 'cache.dart';
export 'disposable.dart';
export 'func.dart' show Func;
export 'invalidation_mixin.dart' show InvalidationMixin, ValidationStatus;
export 'json_serializable.dart' show JsonSerializable;
