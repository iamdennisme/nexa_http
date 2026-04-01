import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

String sha256OfString(String value) {
  return sha256.convert(utf8.encode(value)).toString();
}

Future<String> sha256OfFile(File file) async {
  final digest = sha256.convert(await file.readAsBytes());
  return digest.toString();
}
