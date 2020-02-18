@TestOn('browser')

import 'package:test/test.dart';

// ignore_for_file: unused_import
// These 'unused' imports are here to see files in coverage that are not hit by unit tests.
import 'package:w_common/disposable.dart';
import 'package:w_common/invalidation_mixin.dart';
import 'package:w_common/time.dart';
import 'package:w_common/cache.dart';
import 'package:w_common/disposable_browser.dart';
import 'package:w_common/func.dart';
import 'package:w_common/json_serializable.dart';
import 'package:w_common/web_compiler.dart';
import 'package:w_common/w_common.dart';
import 'package:w_common/src/browser/disposable_browser.dart';
import 'package:w_common/src/browser/web_compiler.dart';
import 'package:w_common/src/common/cache/cache.dart';
import 'package:w_common/src/common/cache/least_recently_used_strategy.dart';
import 'package:w_common/src/common/cache/reference_counting_strategy.dart';
import 'package:w_common/src/common/disposable.dart';
import 'package:w_common/src/common/disposable_manager.dart';
import 'package:w_common/src/common/disposable_state.dart';
import 'package:w_common/src/common/managed_stream_subscription.dart';

void main() {}