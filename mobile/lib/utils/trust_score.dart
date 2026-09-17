const int publicTrustScoreCeiling = 200;

String formatPublicTrustScore(int score) {
  return score > publicTrustScoreCeiling
      ? '$publicTrustScoreCeiling+'
      : score.toString();
}
