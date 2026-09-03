/// A single vocabulary entry: an English word plus its Vietnamese meaning,
/// shown to the player once they find it in the grid.
class VocabWord {
  final String word;
  final String meaningVi;

  const VocabWord(this.word, this.meaningVi) : assert(word.length > 0);

  String get upper => word.toUpperCase();
}
