/// Отзыв (review) на сабмишен Newgrounds.
///
/// Отзывы приходят с `GET /reviews/portal/{trackId}/3/{date|score}/{page}`
/// карточками `<div class="pod-body review" data-review-id="…">`.
class NgReview {
  final String id;
  final String author; // отображаемое имя
  final String authorSlug; // поддомен профиля (`{slug}.newgrounds.com`)
  final String avatarUrl;
  final String date; // «May 2, 2026»
  final double score; // 0..5, 0 — автор скрыл оценку
  final String body;

  /// Ссылка «Report Abuse» (жёлтый флажок) из карточки.
  final String flagUrl;

  /// Сколько реакций у отзыва (null — счётчик пустой на NG).
  final int? reactions;

  const NgReview({
    required this.id,
    required this.author,
    required this.authorSlug,
    required this.avatarUrl,
    required this.date,
    this.score = 0,
    required this.body,
    this.flagUrl = '',
    this.reactions,
  });

  bool get hasScore => score > 0;
}

/// Страница отзывов: список + пагинация («Page 1 of 56»).
class ReviewsPage {
  final List<NgReview> items;
  final int page;
  final int pages;

  const ReviewsPage({required this.items, this.page = 1, this.pages = 1});
}

/// Ответ на голосование: обновлённые score/votes после оценки.
class VoteResult {
  /// Новый средний балл (0..5) или null, если NG его не прислал
  /// (например, «Waiting for N more votes»).
  final double? score;
  final int? votes;
  final bool waiting;

  const VoteResult({this.score, this.votes, this.waiting = false});
}
