// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// This library is copied from package:glob for backward-compatibility.
// It defines both the 2.12-compatible versions of the APIs and the backward-
// compatible versions, in terms of each other. But since methods that are implemented
// take precedence over extensions, whichever one is provided by the library will
// be used instead of these.
// TODO: Remove this once Dart 2.12 is the minimum SDK supported.

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:glob/glob.dart';

/// Platform specific extensions for where `dart:io` exists, which use the
/// local file system.
extension ListLocalFileSystem on Glob {
  /// Convenience method for [Glob.listFileSystem] which uses the local file
  /// system.
  Stream<FileSystemEntity> list({String root, bool followLinks = true}) =>
      listFileSystem(const LocalFileSystem(),
          root: root, followLinks: followLinks);

  /// Convenience method for [Glob.listFileSystemSync] which uses the local
  /// file system.
  List<FileSystemEntity> listSync({String root, bool followLinks = true}) =>
      listFileSystemSync(const LocalFileSystem(),
          root: root, followLinks: followLinks);

  Stream<FileSystemEntity> listFileSystem(LocalFileSystem system,
          {String root, bool followLinks = true}) =>
      list(root: root, followLinks: followLinks);

  List<FileSystemEntity> listFileSystemSync(LocalFileSystem system,
          {String root, bool followLinks = true}) =>
      listSync(root: root, followLinks: followLinks);
}
