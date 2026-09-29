import 'dart:io';

import 'package:farol_cli/src/cli.dart';

Future<void> main(List<String> args) async {
  exitCode = await const FarolCli().run(args);
}
