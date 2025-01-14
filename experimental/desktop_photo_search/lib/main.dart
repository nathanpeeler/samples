// Copyright 2019 The Flutter team. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_simple_treeview/flutter_simple_treeview.dart';
import 'package:logging/logging.dart';
import 'package:menubar/menubar.dart' as menubar;
import 'package:provider/provider.dart';

import 'src/model/photo_search_model.dart';
import 'src/unsplash/photo.dart';
import 'src/unsplash/unsplash.dart';
import 'src/widgets/about_dialog.dart';
import 'src/widgets/photo_details.dart';
import 'src/widgets/photo_search_dialog.dart';
import 'src/widgets/split.dart';
import 'unsplash_access_key.dart';

void main() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((rec) {
    // ignore: avoid_print
    print('${rec.loggerName} ${rec.level.name}: ${rec.time}: ${rec.message}');
  });

  if (unsplashAccessKey.isEmpty) {
    Logger('main').severe('Unsplash Access Key is required. '
        'Please add to `lib/unsplash_access_key.dart`.');
    exit(1);
  }

  runApp(
    ChangeNotifierProvider<PhotoSearchModel>(
      create: (context) => PhotoSearchModel(
        Unsplash(accessKey: unsplashAccessKey),
      ),
      child: const UnsplashSearchApp(),
    ),
  );
}

class UnsplashSearchApp extends StatelessWidget {
  const UnsplashSearchApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Photo Search',
      theme: ThemeData(
        primarySwatch: Colors.orange,
      ),
      home: const UnsplashHomePage(title: 'Photo Search'),
    );
  }
}

class UnsplashHomePage extends StatelessWidget {
  const UnsplashHomePage({required this.title, Key? key}) : super(key: key);
  final String title;

  @override
  Widget build(BuildContext context) {
    final photoSearchModel = Provider.of<PhotoSearchModel>(context);
    menubar.setApplicationMenu([
      menubar.Submenu(label: 'Search', children: [
        menubar.MenuItem(
          label: 'Search ...',
          onClicked: () {
            showDialog<void>(
              context: context,
              builder: (context) =>
                  PhotoSearchDialog(callback: photoSearchModel.addSearch),
            );
          },
        ),
      ]),
      menubar.Submenu(label: 'About', children: [
        menubar.MenuItem(
          label: 'About ...',
          onClicked: () {
            showDialog<void>(
              context: context,
              builder: (context) => const PolicyDialog(),
            );
          },
        ),
      ])
    ]);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: photoSearchModel.entries.isNotEmpty
          ? Split(
              axis: Axis.horizontal,
              initialFirstFraction: 0.4,
              firstChild: Scrollbar(
                child: SingleChildScrollView(
                  child: TreeView(
                    nodes: photoSearchModel.entries
                        .map(_buildSearchEntry)
                        .toList(),
                    indent: 0,
                  ),
                ),
              ),
              secondChild: Center(
                child: photoSearchModel.selectedPhoto != null
                    ? PhotoDetails(
                        photo: photoSearchModel.selectedPhoto!,
                        onPhotoSave: (photo) async {
                          final path = await getSavePath(
                            suggestedName: '${photo.id}.jpg',
                            acceptedTypeGroups: [
                              XTypeGroup(
                                label: 'JPG',
                                extensions: ['jpg'],
                                mimeTypes: ['image/jpeg'],
                              ),
                            ],
                          );
                          if (path != null) {
                            final fileData =
                                await photoSearchModel.download(photo: photo);
                            final photoFile = XFile.fromData(fileData,
                                mimeType: 'image/jpeg');
                            await photoFile.saveTo(path);
                          }
                        },
                      )
                    : Container(),
              ),
            )
          : const Center(
              child: Text('Search for Photos using the Fab button'),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (context) =>
              PhotoSearchDialog(callback: photoSearchModel.addSearch),
        ),
        tooltip: 'Search for a photo',
        child: const Icon(Icons.search),
      ),
    );
  }

  TreeNode _buildSearchEntry(SearchEntry searchEntry) {
    void selectPhoto(Photo photo) {
      searchEntry.model.selectedPhoto = photo;
    }

    String labelForPhoto(Photo photo) => 'Photo by ${photo.user!.name}';

    return TreeNode(
      content: Expanded(
        child: Text(searchEntry.query),
      ),
      children: searchEntry.photos
          .map<TreeNode>(
            (photo) => TreeNode(
              content: Expanded(
                child: Semantics(
                  button: true,
                  onTap: () => selectPhoto(photo),
                  label: labelForPhoto(photo),
                  excludeSemantics: true,
                  child: InkWell(
                    onTap: () => selectPhoto(photo),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(labelForPhoto(photo)),
                    ),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
