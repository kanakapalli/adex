/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod_client/serverpod_client.dart' as _i1;
import 'dart:async' as _i2;
import 'package:adex_client/src/protocol/adex_service/adex_model.dart' as _i3;
import 'dart:typed_data' as _i4;
import 'package:serverpod_auth_idp_client/serverpod_auth_idp_client.dart'
    as _i5;
import 'package:serverpod_auth_core_client/serverpod_auth_core_client.dart'
    as _i6;
import 'package:adex_client/src/protocol/greetings/greeting.dart' as _i7;
import 'protocol.dart' as _i8;

/// AdexService Endpoint for processing videos and extracting frames using RAG
///
/// This endpoint provides:
/// 1. Video upload and AdexModel creation
/// 2. Frame extraction at 2 FPS using FFmpeg
/// 3. Embedding generation using Vertex AI multimodalembedding@001 (1408 dimensions)
/// 4. RAG-based frame type detection and extraction using Gemini
/// 5. Text extraction from frames when extractToText is true
/// {@category Endpoint}
class EndpointAdexService extends _i1.EndpointRef {
  EndpointAdexService(_i1.EndpointCaller caller) : super(caller);

  @override
  String get name => 'adexService';

  /// Process a video from URL and extract relevant frames based on user prompts
  _i2.Future<_i3.AdexModel> processVideoFromUrl(
    String videoUrl,
    String userPrompt, {
    String? whatDoesThisVideoContain,
    List<String>? suggestFramesToExtract,
    required bool extractToText,
    String? extractedDataInformationPrompt,
    int? concurrency,
    int? delayBetweenBatchesMs,
    int? maxRetries,
  }) => caller.callServerEndpoint<_i3.AdexModel>(
    'adexService',
    'processVideoFromUrl',
    {
      'videoUrl': videoUrl,
      'userPrompt': userPrompt,
      'whatDoesThisVideoContain': whatDoesThisVideoContain,
      'suggestFramesToExtract': suggestFramesToExtract,
      'extractToText': extractToText,
      'extractedDataInformationPrompt': extractedDataInformationPrompt,
      'concurrency': concurrency,
      'delayBetweenBatchesMs': delayBetweenBatchesMs,
      'maxRetries': maxRetries,
    },
  );

  /// Process a video and extract relevant frames based on user prompts.
  ///
  /// Receives video bytes directly — saves locally for fast processing,
  /// uploads to S3 in the background. No S3 round-trip.
  _i2.Future<_i3.AdexModel> processVideo(
    _i4.ByteData video,
    String userPrompt, {
    String? whatDoesThisVideoContain,
    List<String>? suggestFramesToExtract,
    required bool extractToText,
    String? extractedDataInformationPrompt,
    int? concurrency,
    int? delayBetweenBatchesMs,
    int? maxRetries,
  }) => caller.callServerEndpoint<_i3.AdexModel>(
    'adexService',
    'processVideo',
    {
      'video': video,
      'userPrompt': userPrompt,
      'whatDoesThisVideoContain': whatDoesThisVideoContain,
      'suggestFramesToExtract': suggestFramesToExtract,
      'extractToText': extractToText,
      'extractedDataInformationPrompt': extractedDataInformationPrompt,
      'concurrency': concurrency,
      'delayBetweenBatchesMs': delayBetweenBatchesMs,
      'maxRetries': maxRetries,
    },
  );

  /// Get the status of a processing job
  _i2.Future<_i3.AdexModel?> getProcessingStatus(int adexModelId) =>
      caller.callServerEndpoint<_i3.AdexModel?>(
        'adexService',
        'getProcessingStatus',
        {'adexModelId': adexModelId},
      );

  /// Get the status of a processing job by processingId
  _i2.Future<_i3.AdexModel?> getProcessingStatusByProcessingId(
    String processingId,
  ) => caller.callServerEndpoint<_i3.AdexModel?>(
    'adexService',
    'getProcessingStatusByProcessingId',
    {'processingId': processingId},
  );

  /// Get all AdexModels, ordered by createdAt descending
  _i2.Future<List<_i3.AdexModel>> getAllAdexModels() =>
      caller.callServerEndpoint<List<_i3.AdexModel>>(
        'adexService',
        'getAllAdexModels',
        {},
      );
}

/// By extending [EmailIdpBaseEndpoint], the email identity provider endpoints
/// are made available on the server and enable the corresponding sign-in widget
/// on the client.
/// {@category Endpoint}
class EndpointEmailIdp extends _i5.EndpointEmailIdpBase {
  EndpointEmailIdp(_i1.EndpointCaller caller) : super(caller);

  @override
  String get name => 'emailIdp';

  /// Logs in the user and returns a new session.
  ///
  /// Throws an [EmailAccountLoginException] in case of errors, with reason:
  /// - [EmailAccountLoginExceptionReason.invalidCredentials] if the email or
  ///   password is incorrect.
  /// - [EmailAccountLoginExceptionReason.tooManyAttempts] if there have been
  ///   too many failed login attempts.
  ///
  /// Throws an [AuthUserBlockedException] if the auth user is blocked.
  @override
  _i2.Future<_i6.AuthSuccess> login({
    required String email,
    required String password,
  }) => caller.callServerEndpoint<_i6.AuthSuccess>(
    'emailIdp',
    'login',
    {
      'email': email,
      'password': password,
    },
  );

  /// Starts the registration for a new user account with an email-based login
  /// associated to it.
  ///
  /// Upon successful completion of this method, an email will have been
  /// sent to [email] with a verification link, which the user must open to
  /// complete the registration.
  ///
  /// Always returns a account request ID, which can be used to complete the
  /// registration. If the email is already registered, the returned ID will not
  /// be valid.
  @override
  _i2.Future<_i1.UuidValue> startRegistration({required String email}) =>
      caller.callServerEndpoint<_i1.UuidValue>(
        'emailIdp',
        'startRegistration',
        {'email': email},
      );

  /// Verifies an account request code and returns a token
  /// that can be used to complete the account creation.
  ///
  /// Throws an [EmailAccountRequestException] in case of errors, with reason:
  /// - [EmailAccountRequestExceptionReason.expired] if the account request has
  ///   already expired.
  /// - [EmailAccountRequestExceptionReason.policyViolation] if the password
  ///   does not comply with the password policy.
  /// - [EmailAccountRequestExceptionReason.invalid] if no request exists
  ///   for the given [accountRequestId] or [verificationCode] is invalid.
  @override
  _i2.Future<String> verifyRegistrationCode({
    required _i1.UuidValue accountRequestId,
    required String verificationCode,
  }) => caller.callServerEndpoint<String>(
    'emailIdp',
    'verifyRegistrationCode',
    {
      'accountRequestId': accountRequestId,
      'verificationCode': verificationCode,
    },
  );

  /// Completes a new account registration, creating a new auth user with a
  /// profile and attaching the given email account to it.
  ///
  /// Throws an [EmailAccountRequestException] in case of errors, with reason:
  /// - [EmailAccountRequestExceptionReason.expired] if the account request has
  ///   already expired.
  /// - [EmailAccountRequestExceptionReason.policyViolation] if the password
  ///   does not comply with the password policy.
  /// - [EmailAccountRequestExceptionReason.invalid] if the [registrationToken]
  ///   is invalid.
  ///
  /// Throws an [AuthUserBlockedException] if the auth user is blocked.
  ///
  /// Returns a session for the newly created user.
  @override
  _i2.Future<_i6.AuthSuccess> finishRegistration({
    required String registrationToken,
    required String password,
  }) => caller.callServerEndpoint<_i6.AuthSuccess>(
    'emailIdp',
    'finishRegistration',
    {
      'registrationToken': registrationToken,
      'password': password,
    },
  );

  /// Requests a password reset for [email].
  ///
  /// If the email address is registered, an email with reset instructions will
  /// be send out. If the email is unknown, this method will have no effect.
  ///
  /// Always returns a password reset request ID, which can be used to complete
  /// the reset. If the email is not registered, the returned ID will not be
  /// valid.
  ///
  /// Throws an [EmailAccountPasswordResetException] in case of errors, with reason:
  /// - [EmailAccountPasswordResetExceptionReason.tooManyAttempts] if the user has
  ///   made too many attempts trying to request a password reset.
  ///
  @override
  _i2.Future<_i1.UuidValue> startPasswordReset({required String email}) =>
      caller.callServerEndpoint<_i1.UuidValue>(
        'emailIdp',
        'startPasswordReset',
        {'email': email},
      );

  /// Verifies a password reset code and returns a finishPasswordResetToken
  /// that can be used to finish the password reset.
  ///
  /// Throws an [EmailAccountPasswordResetException] in case of errors, with reason:
  /// - [EmailAccountPasswordResetExceptionReason.expired] if the password reset
  ///   request has already expired.
  /// - [EmailAccountPasswordResetExceptionReason.tooManyAttempts] if the user has
  ///   made too many attempts trying to verify the password reset.
  /// - [EmailAccountPasswordResetExceptionReason.invalid] if no request exists
  ///   for the given [passwordResetRequestId] or [verificationCode] is invalid.
  ///
  /// If multiple steps are required to complete the password reset, this endpoint
  /// should be overridden to return credentials for the next step instead
  /// of the credentials for setting the password.
  @override
  _i2.Future<String> verifyPasswordResetCode({
    required _i1.UuidValue passwordResetRequestId,
    required String verificationCode,
  }) => caller.callServerEndpoint<String>(
    'emailIdp',
    'verifyPasswordResetCode',
    {
      'passwordResetRequestId': passwordResetRequestId,
      'verificationCode': verificationCode,
    },
  );

  /// Completes a password reset request by setting a new password.
  ///
  /// The [verificationCode] returned from [verifyPasswordResetCode] is used to
  /// validate the password reset request.
  ///
  /// Throws an [EmailAccountPasswordResetException] in case of errors, with reason:
  /// - [EmailAccountPasswordResetExceptionReason.expired] if the password reset
  ///   request has already expired.
  /// - [EmailAccountPasswordResetExceptionReason.policyViolation] if the new
  ///   password does not comply with the password policy.
  /// - [EmailAccountPasswordResetExceptionReason.invalid] if no request exists
  ///   for the given [passwordResetRequestId] or [verificationCode] is invalid.
  ///
  /// Throws an [AuthUserBlockedException] if the auth user is blocked.
  @override
  _i2.Future<void> finishPasswordReset({
    required String finishPasswordResetToken,
    required String newPassword,
  }) => caller.callServerEndpoint<void>(
    'emailIdp',
    'finishPasswordReset',
    {
      'finishPasswordResetToken': finishPasswordResetToken,
      'newPassword': newPassword,
    },
  );
}

/// By extending [RefreshJwtTokensEndpoint], the JWT token refresh endpoint
/// is made available on the server and enables automatic token refresh on the client.
/// {@category Endpoint}
class EndpointJwtRefresh extends _i6.EndpointRefreshJwtTokens {
  EndpointJwtRefresh(_i1.EndpointCaller caller) : super(caller);

  @override
  String get name => 'jwtRefresh';

  /// Creates a new token pair for the given [refreshToken].
  ///
  /// Can throw the following exceptions:
  /// -[RefreshTokenMalformedException]: refresh token is malformed and could
  ///   not be parsed. Not expected to happen for tokens issued by the server.
  /// -[RefreshTokenNotFoundException]: refresh token is unknown to the server.
  ///   Either the token was deleted or generated by a different server.
  /// -[RefreshTokenExpiredException]: refresh token has expired. Will happen
  ///   only if it has not been used within configured `refreshTokenLifetime`.
  /// -[RefreshTokenInvalidSecretException]: refresh token is incorrect, meaning
  ///   it does not refer to the current secret refresh token. This indicates
  ///   either a malfunctioning client or a malicious attempt by someone who has
  ///   obtained the refresh token. In this case the underlying refresh token
  ///   will be deleted, and access to it will expire fully when the last access
  ///   token is elapsed.
  ///
  /// This endpoint is unauthenticated, meaning the client won't include any
  /// authentication information with the call.
  @override
  _i2.Future<_i6.AuthSuccess> refreshAccessToken({
    required String refreshToken,
  }) => caller.callServerEndpoint<_i6.AuthSuccess>(
    'jwtRefresh',
    'refreshAccessToken',
    {'refreshToken': refreshToken},
    authenticated: false,
  );
}

/// This is an example endpoint that returns a greeting message through
/// its [hello] method.
/// {@category Endpoint}
class EndpointGreeting extends _i1.EndpointRef {
  EndpointGreeting(_i1.EndpointCaller caller) : super(caller);

  @override
  String get name => 'greeting';

  /// Returns a personalized greeting message: "Hello {name}".
  _i2.Future<_i7.Greeting> hello(String name) =>
      caller.callServerEndpoint<_i7.Greeting>(
        'greeting',
        'hello',
        {'name': name},
      );
}

/// Endpoint for handling file uploads to S3.
///
/// Primary flow (direct upload — best for large files like videos):
///   1. Client calls [getUploadDescription] to get a presigned S3 URL
///   2. Client uploads directly to S3 using FileUploader
///   3. Client calls [verifyUpload] to confirm
///
/// Fallback flow (server-side upload — no CORS needed):
///   1. Client calls [storeFile] with bytes — server stores to S3
/// {@category Endpoint}
class EndpointUpload extends _i1.EndpointRef {
  EndpointUpload(_i1.EndpointCaller caller) : super(caller);

  @override
  String get name => 'upload';

  /// Step 1: Get a presigned upload description for direct client-to-S3 upload.
  ///
  /// Uses patched S3UploadHelper with correct URL format (s3.region, not s3-region).
  _i2.Future<String?> getUploadDescription(String storagePath) =>
      caller.callServerEndpoint<String?>(
        'upload',
        'getUploadDescription',
        {'storagePath': storagePath},
      );

  /// Step 3: Verify the direct upload completed.
  /// Uses session.storage which correctly uses AwsS3Client (dot format).
  _i2.Future<bool> verifyUpload(String storagePath) =>
      caller.callServerEndpoint<bool>(
        'upload',
        'verifyUpload',
        {'storagePath': storagePath},
      );

  /// Uploads file bytes through the server to S3. No CORS needed.
  /// Uses patched S3UploadHelper to avoid the URL format bug.
  /// Returns the public URL on success.
  _i2.Future<String?> storeFile(
    String storagePath,
    _i4.ByteData fileData,
  ) => caller.callServerEndpoint<String?>(
    'upload',
    'storeFile',
    {
      'storagePath': storagePath,
      'fileData': fileData,
    },
  );

  /// Gets the public URL for a stored file.
  _i2.Future<String?> getPublicUrl(String storagePath) =>
      caller.callServerEndpoint<String?>(
        'upload',
        'getPublicUrl',
        {'storagePath': storagePath},
      );

  /// Lists uploaded files. S3 doesn't support listing via Serverpod.
  _i2.Future<List<String>> listFiles() =>
      caller.callServerEndpoint<List<String>>(
        'upload',
        'listFiles',
        {},
      );

  /// Deletes a file from S3.
  _i2.Future<bool> deleteFile(String storagePath) =>
      caller.callServerEndpoint<bool>(
        'upload',
        'deleteFile',
        {'storagePath': storagePath},
      );
}

/// {@category Endpoint}
class EndpointVideoExtraction extends _i1.EndpointRef {
  EndpointVideoExtraction(_i1.EndpointCaller caller) : super(caller);

  @override
  String get name => 'videoExtraction';

  /// Complete workflow: Extract frames, generate embeddings, classify, and save product images
  ///
  /// This is the main entry point for video processing. It performs:
  /// 1. Extract 2 frames per second from video
  /// 2. Generate embeddings using Vertex AI multimodalembedding@002
  /// 3. Save embeddings to database with vector indexing
  /// 4. Use RAG to find product, nutrition facts, ingredients, and back images
  /// 5. Save classified images to organized output directory
  /// 6. Optionally extract text using Gemini 2.0 Flash (if textExtraction is true)
  /// 7. Cleanup temporary frames and database entries
  ///
  /// Parameters:
  /// - videoUrl: URL of the video to process
  /// - outputDir: Directory to save classified images
  /// - textExtraction: If true, extract text from images using Gemini 2.0 (default: false)
  ///
  /// Note: Vertex AI credentials are automatically loaded from config/passwords.yaml
  ///
  /// Returns: Map with paths to saved images and extracted text (if enabled):
  ///   {
  ///     'images': {
  ///       'product': 'path',
  ///       'nutrifact': ['path1', 'path2'],
  ///       'ingredients': ['path1', 'path2'],
  ///       'back': 'path'
  ///     },
  ///     'extractedText': {  // Only if textExtraction=true
  ///       'nutritionFacts': { ... },
  ///       'ingredients': { ... },
  ///       'productInfo': { ... },
  ///       'claimsAndAllergens': { ... }
  ///     }
  ///   }
  _i2.Future<Map<String, dynamic>> processVideoComplete(
    String videoUrl,
    String outputDir, {
    required bool textExtraction,
  }) => caller.callServerEndpoint<Map<String, dynamic>>(
    'videoExtraction',
    'processVideoComplete',
    {
      'videoUrl': videoUrl,
      'outputDir': outputDir,
      'textExtraction': textExtraction,
    },
  );

  /// Legacy method: Extract 1 frame per second (deprecated)
  ///
  /// Use processVideoComplete() instead for the full workflow.
  @Deprecated('Use processVideoComplete() for the complete workflow')
  _i2.Future<int> extractVideoFrames(String videoUrl) =>
      caller.callServerEndpoint<int>(
        'videoExtraction',
        'extractVideoFrames',
        {'videoUrl': videoUrl},
      );
}

class Modules {
  Modules(Client client) {
    serverpod_auth_idp = _i5.Caller(client);
    serverpod_auth_core = _i6.Caller(client);
  }

  late final _i5.Caller serverpod_auth_idp;

  late final _i6.Caller serverpod_auth_core;
}

class Client extends _i1.ServerpodClientShared {
  Client(
    String host, {
    dynamic securityContext,
    @Deprecated(
      'Use authKeyProvider instead. This will be removed in future releases.',
    )
    super.authenticationKeyManager,
    Duration? streamingConnectionTimeout,
    Duration? connectionTimeout,
    Function(
      _i1.MethodCallContext,
      Object,
      StackTrace,
    )?
    onFailedCall,
    Function(_i1.MethodCallContext)? onSucceededCall,
    bool? disconnectStreamsOnLostInternetConnection,
  }) : super(
         host,
         _i8.Protocol(),
         securityContext: securityContext,
         streamingConnectionTimeout: streamingConnectionTimeout,
         connectionTimeout: connectionTimeout,
         onFailedCall: onFailedCall,
         onSucceededCall: onSucceededCall,
         disconnectStreamsOnLostInternetConnection:
             disconnectStreamsOnLostInternetConnection,
       ) {
    adexService = EndpointAdexService(this);
    emailIdp = EndpointEmailIdp(this);
    jwtRefresh = EndpointJwtRefresh(this);
    greeting = EndpointGreeting(this);
    upload = EndpointUpload(this);
    videoExtraction = EndpointVideoExtraction(this);
    modules = Modules(this);
  }

  late final EndpointAdexService adexService;

  late final EndpointEmailIdp emailIdp;

  late final EndpointJwtRefresh jwtRefresh;

  late final EndpointGreeting greeting;

  late final EndpointUpload upload;

  late final EndpointVideoExtraction videoExtraction;

  late final Modules modules;

  @override
  Map<String, _i1.EndpointRef> get endpointRefLookup => {
    'adexService': adexService,
    'emailIdp': emailIdp,
    'jwtRefresh': jwtRefresh,
    'greeting': greeting,
    'upload': upload,
    'videoExtraction': videoExtraction,
  };

  @override
  Map<String, _i1.ModuleEndpointCaller> get moduleLookup => {
    'serverpod_auth_idp': modules.serverpod_auth_idp,
    'serverpod_auth_core': modules.serverpod_auth_core,
  };
}
