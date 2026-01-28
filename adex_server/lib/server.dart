import 'dart:io';

import 'package:serverpod/serverpod.dart';
import 'package:serverpod_auth_idp_server/core.dart';
import 'package:serverpod_auth_idp_server/providers/email.dart';
import 'package:serverpod_cloud_storage_s3/serverpod_cloud_storage_s3.dart' as s3;

import 'src/generated/endpoints.dart';
import 'src/generated/protocol.dart';
import 'src/upload/s3_upload_helper.dart';
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

  // Register S3 cloud storage for file uploads
  print('[S3_INIT] Registering S3 cloud storage...');
  print('[S3_INIT]   storageId: public');
  print('[S3_INIT]   region: eu-north-1');
  print('[S3_INIT]   bucket: anuragstorage');
  print('[S3_INIT]   publicHost: anuragstorage.s3.eu-north-1.amazonaws.com');
  print('[S3_INIT]   public: true');

  // Check if AWS credentials are present in passwords
  final awsKeyId = pod.getPassword('AWSAccessKeyId');
  final awsSecret = pod.getPassword('AWSSecretKey');
  print('[S3_INIT]   AWSAccessKeyId present: ${awsKeyId != null && awsKeyId.isNotEmpty} (length: ${awsKeyId?.length ?? 0})');
  print('[S3_INIT]   AWSSecretKey present: ${awsSecret != null && awsSecret.isNotEmpty} (length: ${awsSecret?.length ?? 0})');

  if (awsKeyId == null || awsKeyId.isEmpty || awsKeyId == 'PLACEHOLDER') {
    print('[S3_INIT]   WARNING: AWSAccessKeyId is missing or placeholder!');
  }
  if (awsSecret == null || awsSecret.isEmpty || awsSecret == 'PLACEHOLDER') {
    print('[S3_INIT]   WARNING: AWSSecretKey is missing or placeholder!');
  }

  // Initialize patched S3 upload helper (fixes s3-region -> s3.region URL format)
  if (awsKeyId != null && awsKeyId.isNotEmpty && awsSecret != null && awsSecret.isNotEmpty) {
    S3UploadHelper.initialize(
      accessKey: awsKeyId,
      secretKey: awsSecret,
      bucket: 'anuragstorage',
      region: 'eu-north-1',
    );
    print('[S3_INIT] S3UploadHelper initialized (patched URL format)');
  }

  pod.addCloudStorage(s3.S3CloudStorage(
    serverpod: pod,
    storageId: 'public',
    public: true,
    region: 'eu-north-1',
    bucket: 'anuragstorage',
    publicHost: 'anuragstorage.s3.eu-north-1.amazonaws.com',
  ));
  print('[S3_INIT] S3 cloud storage registered successfully.');

  // Setup a default page at the web root.
  // These are used by the default page.
  pod.webServer.addRoute(RootRoute(), '/');
  pod.webServer.addRoute(RootRoute(), '/index.html');

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
