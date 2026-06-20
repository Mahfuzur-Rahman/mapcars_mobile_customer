/// Formats an integer amount in **pence** as a GBP string, e.g. 890 -> "£8.90".
///
/// Money is carried as integer pence end-to-end (never a double) to avoid
/// floating-point rounding errors on fares — only formatted at the edge.
String formatGbp(int pence) => '£${(pence / 100).toStringAsFixed(2)}';
