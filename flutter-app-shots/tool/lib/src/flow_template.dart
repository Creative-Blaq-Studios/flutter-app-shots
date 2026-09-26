/// Replaces `{{key}}` tokens in [template] with [vars] values.
/// Throws [FormatException] if any `{{...}}` token remains afterward.
String renderFlow(String template, Map<String, String> vars) {
  var out = template;
  vars.forEach((key, value) {
    out = out.replaceAll('{{$key}}', value);
  });
  final leftover = RegExp(r'\{\{[^}]+\}\}').firstMatch(out);
  if (leftover != null) {
    throw FormatException('Unsubstituted token: ${leftover.group(0)}');
  }
  return out;
}
