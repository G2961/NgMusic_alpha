class NgUser {
  final String username;
  final String profileUrl;
  final String? avatarUrl;
  final String? age;
  final String? gender;
  final String? country;
  final String? joinDate;
  final String? level;
  final String? exp;
  final String? fans;
  final String? audioCount;
  /// Подписан ли текущий пользователь на этого автора — по классу `active`
  /// на `.favefollow-buttons`.
  ///
  /// `null` — определить нельзя: кнопки на странице нет (гость) либо разметка
  /// не совпала. Именно поэтому тип nullable: раньше здесь был `bool` с
  /// дефолтом `false`, и UI не мог отличить «не подписан» от «не знаю».
  final bool? isFollowing;

  const NgUser({
    required this.username,
    required this.profileUrl,
    this.avatarUrl,
    this.age,
    this.gender,
    this.country,
    this.joinDate,
    this.level,
    this.exp,
    this.fans,
    this.audioCount,
    this.isFollowing,
  });
}
