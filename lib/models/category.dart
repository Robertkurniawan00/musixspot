import 'package:flutter/material.dart';
import 'playlist.dart';

class BrowseCategory {
  final String id;
  final String title;
  final Color backgroundColor;
  final String imageUrl;

  BrowseCategory({
    required this.id,
    required this.title,
    required this.backgroundColor,
    required this.imageUrl,
  });
}

class CategorySection {
  final String title;
  final List<Playlist> playlists;

  CategorySection({
    required this.title,
    required this.playlists,
  });
}

class CategoryData {
  final BrowseCategory category;
  final Playlist? heroPlaylist;
  final List<CategorySection> sections;

  CategoryData({
    required this.category,
    this.heroPlaylist,
    required this.sections,
  });
}
