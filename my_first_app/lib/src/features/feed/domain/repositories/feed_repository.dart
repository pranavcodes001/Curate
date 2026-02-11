// Feed repository interface
// Responsibility: Declare the abstract repository interface that the Feed feature will rely on.

import '../models/feed_item.dart';

abstract class FeedRepository {
  Future<List<FeedItem>> fetchInterestFeed({int? limit});
  Future<List<FeedItem>> fetchTopStories({int? limit});
  Future<void> markSeen(List<String> hnIds);
  Future<void> dismissStory(String hnId);
}
