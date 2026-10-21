/// Escapes `%`, `_` and `\` for use in `LIKE ? ESCAPE '\'`.
String escapeLike(String s) =>
    s.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');
