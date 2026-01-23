import 'dart:io';

import 'package:serverpod/serverpod.dart';
import 'package:serverpod_auth_idp_server/core.dart';
import 'package:serverpod_auth_idp_server/providers/email.dart';

import 'src/generated/endpoints.dart';
import 'src/generated/protocol.dart';
import 'src/web/routes/app_config_route.dart';
import 'src/web/routes/root.dart';

/// The starting point of the Serverpod server.
void run(List<String> args) async {
  // Initialize Serverpod and connect it with your generated code.
  final pod = Serverpod(args, Protocol(), Endpoints(),httpResponseHeaders: Headers.fromMap({
      'Access-Control-Allow-Origin': ['*'],
      'Access-Control-Allow-Methods': ['GET, POST, PUT, DELETE, OPTIONS'],
      'Access-Control-Allow-Headers': [
        'Content-Type',
        'Authorization',
        'X-Requested-With',
        'serverpod-session-id',
      ],
    }),
    httpOptionsResponseHeaders: Headers.fromMap({
      'Access-Control-Allow-Origin': ['*'],
      'Access-Control-Allow-Methods': ['GET, POST, PUT, DELETE, OPTIONS'],
      'Access-Control-Allow-Headers': [
        'Content-Type',
        'Authorization',
        'X-Requested-With',
        'serverpod-session-id',
      ],
      'Access-Control-Max-Age': ['86400'],
    }),);

  // Initialize authentication services for the server.
  // Token managers will be used to validate and issue authentication keys,
  // and the identity providers will be the authentication options available for users.
  pod.initializeAuthServices(
    tokenManagerBuilders: [
      // Use JWT for authentication keys towards the server.
      JwtConfigFromPasswords(),
    ],
    identityProviderBuilders: [
      // Configure the email identity provider for email/password authentication.
      EmailIdpConfigFromPasswords(
        sendRegistrationVerificationCode: _sendRegistrationCode,
        sendPasswordResetVerificationCode: _sendPasswordResetCode,
      ),
    ],
  );

  // Setup a default page at the web root.
  // These are used by the default page.
  pod.webServer.addRoute(RootRoute(), '/');
  pod.webServer.addRoute(RootRoute(), '/index.html');

  // Serve uploaded files publicly at /uploads/
  final uploadsDir = Directory('uploads');
  if (!uploadsDir.existsSync()) {
    uploadsDir.createSync(recursive: true);
  }
  // Add CORS middleware to ensure browser clients can load images/files from
  // the uploads route. This allows cross-origin requests from web apps.
  pod.webServer.addMiddleware(CorsMiddleware(), '/uploads');
  pod.webServer.addMiddleware(CorsMiddleware(), '/uploads/*');
  pod.webServer.addRoute(StaticRoute.directory(uploadsDir), '/uploads');

  // Serve all files in the web/static relative directory under /.
  // These are used by the default web page.
  final root = Directory(Uri(path: 'web/static').toFilePath());
  pod.webServer.addRoute(StaticRoute.directory(root));

  // Setup the app config route.
  // We build this configuration based on the servers api url and serve it to
  // the flutter app.
  pod.webServer.addRoute(
    AppConfigRoute(apiConfig: pod.config.apiServer),
    '/app/assets/assets/config.json',
  );

  // Checks if the flutter web app has been built and serves it if it has.
  final appDir = Directory(Uri(path: 'web/app').toFilePath());
  if (appDir.existsSync()) {
    // Serve the flutter web app under the /app path.
    pod.webServer.addRoute(
      FlutterRoute(
        Directory(
          Uri(path: 'web/app').toFilePath(),
        ),
      ),
      '/app',
    );
  } else {
    // If the flutter web app has not been built, serve the build app page.
    pod.webServer.addRoute(
      StaticRoute.file(
        File(
          Uri(path: 'web/pages/build_flutter_app.html').toFilePath(),
        ),
      ),
      '/app/**',
    );
  }

  // Start the server.
  await pod.start();
}

class CorsMiddleware extends MiddlewareObject {
  const CorsMiddleware();

  @override
  Handler call(Handler next) {
    return (req) async {
      // Handle preflight OPTIONS requests
      if (req.method == Method.options) {
        return Response.ok(
          body: Body.fromString(''),
          headers: Headers.build((h) {
            h['Access-Control-Allow-Origin'] = ['*'];
            h['Access-Control-Allow-Methods'] = ['GET', 'POST', 'OPTIONS'];
            h['Access-Control-Allow-Headers'] = ['*'];
          }),
        );
      }

      // Forward request and ensure CORS header is present in the response
      final res = await next(req);
      if (res is Response) {
        final headers = res.headers.transform((h) {
          h['Access-Control-Allow-Origin'] = ['*'];
        });
        return res.copyWith(headers: headers);
      }

      return res;
    };
  }
}

void _sendRegistrationCode(
  Session session, {
  required String email,
  required UuidValue accountRequestId,
  required String verificationCode,
  required Transaction? transaction,
}) {
  // NOTE: Here you call your mail service to send the verification code to
  // the user. For testing, we will just log the verification code.
  session.log('[EmailIdp] Registration code ($email): $verificationCode');
}

void _sendPasswordResetCode(
  Session session, {
  required String email,
  required UuidValue passwordResetRequestId,
  required String verificationCode,
  required Transaction? transaction,
}) {
  // NOTE: Here you call your mail service to send the verification code to
  // the user. For testing, we will just log the verification code.
  session.log('[EmailIdp] Password reset code ($email): $verificationCode');
}
