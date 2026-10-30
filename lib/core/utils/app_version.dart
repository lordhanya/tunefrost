/// A version like `1.10.0`, compared a segment at a time.
///
/// Comparing the text is not enough: read as strings `1.10.0` sorts *before*
/// `1.2.0`, which would make a newer release look like an older one. Only the
/// leading `major.minor.patch` is taken — a build suffix (`1.4.0+5`) and a
/// pre-release tag (`1.4.0-beta.1`) are ignored, so they compare as their
/// release. Anything that does not begin with three whole numbers does not
/// parse, and callers treat that as "unknown" rather than guess.
class AppVersion implements Comparable<AppVersion> {
  const AppVersion(this.major, this.minor, this.patch);

  final int major;
  final int minor;
  final int patch;

  /// Parses [raw], or returns null when it does not start with `X.Y.Z`.
  static AppVersion? tryParse(String raw) {
    final core = raw.trim().split(RegExp(r'[+-]')).first.split('.');
    if (core.length != 3) return null;

    final segments = <int>[];
    for (final segment in core) {
      final value = int.tryParse(segment);
      if (value == null) return null;
      segments.add(value);
    }
    return AppVersion(segments[0], segments[1], segments[2]);
  }

  @override
  int compareTo(AppVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }

  bool operator <(AppVersion other) => compareTo(other) < 0;

  bool operator <=(AppVersion other) => compareTo(other) <= 0;

  bool operator >(AppVersion other) => compareTo(other) > 0;

  bool operator >=(AppVersion other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) =>
      other is AppVersion && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(major, minor, patch);

  @override
  String toString() => '$major.$minor.$patch';
}
