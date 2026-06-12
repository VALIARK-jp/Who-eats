/// Post / profile default visibility: friends | near | public
abstract final class PostVisibility {
  static const friends = 'friends';
  static const near = 'near';
  static const public_ = 'public';

  static const values = [friends, near, public_];

  static String normalize(String raw) {
    return switch (raw.trim()) {
      public_ => public_,
      near => near,
      'private' => friends, // legacy
      friends => friends,
      _ => friends,
    };
  }

  static String label(String value) {
    return switch (normalize(value)) {
      friends => '友達',
      near => '友達の友達',
      public_ => '公開',
      _ => '友達',
    };
  }

  static String defaultForNewPostDescription(String value) {
    return switch (normalize(value)) {
      friends => '新しい投稿は友達タブから見られる範囲で作成されます。',
      near => '新しい投稿は友達の友達タブから見られる範囲で作成されます。',
      public_ => '新しい投稿は全体タブから見られる範囲で作成されます。',
      _ => '',
    };
  }

  static String postEditorDescription(String value) {
    return switch (normalize(value)) {
      friends => '相互フォローの友達が、友達タブで見られます。',
      near => '友達の友達まで、友達の友達タブで見られます。',
      public_ => '誰でも、全体タブで見られます。',
      _ => '',
    };
  }

  /// Whether [postVisibility] from [authorUserId] should appear on [scope].
  static bool matchesFeedScope({
    required String scope,
    required String postVisibility,
    required String authorUserId,
    required String? viewerUserId,
    required Set<String> friendIds,
    required Set<String> nearIds,
  }) {
    if (viewerUserId == null) {
      return normalize(postVisibility) == public_;
    }
    if (authorUserId == viewerUserId) return true;
    if (friendIds.contains(authorUserId)) return true;

    final vis = normalize(postVisibility);
    return switch (scope) {
      'friends' => false,
      'near' => nearIds.contains(authorUserId) && vis == near,
      'all' => vis == public_,
      _ => false,
    };
  }
}
