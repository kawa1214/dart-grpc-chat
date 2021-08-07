import 'dart:io';

import 'package:grpc/grpc.dart';
import 'package:vm_service/utils.dart';
import 'dart:developer' as dev;
import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';
import 'package:server/src/generated/protos/helloworld.pbgrpc.dart';
import 'package:server/src/app/static.dart' as app_static;
import 'package:watcher/watcher.dart';

class GreeterService extends GreeterServiceBase {
  @override
  Future<HelloReply> sayHello(ServiceCall call, HelloRequest request) async {
    return HelloReply()..message = 'Hi! Hello, ${request.name}!';
  }
}

Future<void> main(List<String> args) async {
  await runServe();
  await autoReload();
}

Future<void> autoReload() async {
  final observatoryUri = (await dev.Service.getInfo()).serverUri;
  if (observatoryUri != null) {
    var serviceClient = await vmServiceConnectUri(
      convertToWebSocketUrl(serviceProtocolUrl: observatoryUri).toString(),
      log: StdOutLog(),
    );
    final vm = await serviceClient.getVM();
    final mainIsolate = vm.isolates!.first;

    Watcher(Directory.current.path).events.listen((_) async {
      await serviceClient.reloadSources(mainIsolate.id!);
      print('reload');
    });
  } else {
    throw Exception(
      'You need to pass `--enable-vm-service --disable-service-auth-codes` to enable hot reload',
    );
  }
}

Future<void> runServe() async {
  final server = Server(
    [GreeterService()],
    const <Interceptor>[],
    CodecRegistry(codecs: const [GzipCodec(), IdentityCodec()]),
  );
  await server.serve(port: app_static.port);
  print('Server listening on http://localhost://${server.port}');
  print('port : ${server.port}');
}

class StdOutLog implements Log {
  const StdOutLog();

  @override
  void severe(String message) {
    print('> SEVERE: $message');
  }

  @override
  void warning(String message) {
    print('> WARNING: $message');
  }
}
