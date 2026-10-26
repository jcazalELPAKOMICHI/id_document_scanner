/// Sex as encoded in the MRZ ("M", "F" or "<").
enum MrzSex {
  male('M'),
  female('F'),
  unspecified('<');

  const MrzSex(this.code);

  final String code;

  static MrzSex fromCode(String code) => values.firstWhere((sex) => sex.code == code, orElse: () => .unspecified);
}
