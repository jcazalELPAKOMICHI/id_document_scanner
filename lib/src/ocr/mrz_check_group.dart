import '../mrz/mrz_data.dart';
import '../mrz/mrz_parser.dart';

/// MRZ positions (line, index) protected by one check digit.
class MrzCheckGroup {
  const MrzCheckGroup({required this.positions, required this.check});

  /// Consecutive positions [start, end) of [line].
  factory MrzCheckGroup.of(int line, int start, int end, bool Function(MrzData mrz) check) =>
      MrzCheckGroup(positions: [for (var p = start; p < end; p++) (line, p)], check: check);

  final List<(int, int)> positions;
  final bool Function(MrzData mrz) check;

  bool isValid(List<String> lines) {
    final mrz = MrzParser.parse(lines);
    return mrz != null && check(mrz);
  }
}
