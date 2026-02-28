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
import 'package:serverpod/serverpod.dart' as _i1;
import '../adex_service/adex_service_endpoint.dart' as _i2;
import '../auth/email_idp_endpoint.dart' as _i3;
import '../auth/jwt_refresh_endpoint.dart' as _i4;
import '../greetings/greeting_endpoint.dart' as _i5;
import '../upload/upload_endpoint.dart' as _i6;
import 'dart:typed_data' as _i7;
import 'package:serverpod_auth_idp_server/serverpod_auth_idp_server.dart'
    as _i8;
import 'package:serverpod_auth_core_server/serverpod_auth_core_server.dart'
    as _i9;

class Endpoints extends _i1.EndpointDispatch {
  @override
  void initializeEndpoints(_i1.Server server) {
    var endpoints = <String, _i1.Endpoint>{
      'adexService': _i2.AdexServiceEndpoint()
        ..initialize(
          server,
          'adexService',
          null,
        ),
      'emailIdp': _i3.EmailIdpEndpoint()
        ..initialize(
          server,
          'emailIdp',
          null,
        ),
      'jwtRefresh': _i4.JwtRefreshEndpoint()
        ..initialize(
          server,
          'jwtRefresh',
          null,
        ),
      'greeting': _i5.GreetingEndpoint()
        ..initialize(
          server,
          'greeting',
          null,
        ),
      'upload': _i6.UploadEndpoint()
        ..initialize(
          server,
          'upload',
          null,
        ),
    };
    connectors['adexService'] = _i1.EndpointConnector(
      name: 'adexService',
      endpoint: endpoints['adexService']!,
      methodConnectors: {
        'processVideoFromUrl': _i1.MethodConnector(
          name: 'processVideoFromUrl',
          params: {
            'videoUrl': _i1.ParameterDescription(
              name: 'videoUrl',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'userPrompt': _i1.ParameterDescription(
              name: 'userPrompt',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'whatDoesThisVideoContain': _i1.ParameterDescription(
              name: 'whatDoesThisVideoContain',
              type: _i1.getType<String?>(),
              nullable: true,
            ),
            'suggestFramesToExtract': _i1.ParameterDescription(
              name: 'suggestFramesToExtract',
              type: _i1.getType<List<String>?>(),
              nullable: true,
            ),
            'extractToText': _i1.ParameterDescription(
              name: 'extractToText',
              type: _i1.getType<bool>(),
              nullable: false,
            ),
            'extractedDataInformationPrompt': _i1.ParameterDescription(
              name: 'extractedDataInformationPrompt',
              type: _i1.getType<String?>(),
              nullable: true,
            ),
            'concurrency': _i1.ParameterDescription(
              name: 'concurrency',
              type: _i1.getType<int?>(),
              nullable: true,
            ),
            'delayBetweenBatchesMs': _i1.ParameterDescription(
              name: 'delayBetweenBatchesMs',
              type: _i1.getType<int?>(),
              nullable: true,
            ),
            'maxRetries': _i1.ParameterDescription(
              name: 'maxRetries',
              type: _i1.getType<int?>(),
              nullable: true,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['adexService'] as _i2.AdexServiceEndpoint)
                  .processVideoFromUrl(
                    session,
                    params['videoUrl'],
                    params['userPrompt'],
                    whatDoesThisVideoContain:
                        params['whatDoesThisVideoContain'],
                    suggestFramesToExtract: params['suggestFramesToExtract'],
                    extractToText: params['extractToText'],
                    extractedDataInformationPrompt:
                        params['extractedDataInformationPrompt'],
                    concurrency: params['concurrency'],
                    delayBetweenBatchesMs: params['delayBetweenBatchesMs'],
                    maxRetries: params['maxRetries'],
                  ),
        ),
        'processVideo': _i1.MethodConnector(
          name: 'processVideo',
          params: {
            'video': _i1.ParameterDescription(
              name: 'video',
              type: _i1.getType<_i7.ByteData>(),
              nullable: false,
            ),
            'userPrompt': _i1.ParameterDescription(
              name: 'userPrompt',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'whatDoesThisVideoContain': _i1.ParameterDescription(
              name: 'whatDoesThisVideoContain',
              type: _i1.getType<String?>(),
              nullable: true,
            ),
            'suggestFramesToExtract': _i1.ParameterDescription(
              name: 'suggestFramesToExtract',
              type: _i1.getType<List<String>?>(),
              nullable: true,
            ),
            'extractToText': _i1.ParameterDescription(
              name: 'extractToText',
              type: _i1.getType<bool>(),
              nullable: false,
            ),
            'extractedDataInformationPrompt': _i1.ParameterDescription(
              name: 'extractedDataInformationPrompt',
              type: _i1.getType<String?>(),
              nullable: true,
            ),
            'concurrency': _i1.ParameterDescription(
              name: 'concurrency',
              type: _i1.getType<int?>(),
              nullable: true,
            ),
            'delayBetweenBatchesMs': _i1.ParameterDescription(
              name: 'delayBetweenBatchesMs',
              type: _i1.getType<int?>(),
              nullable: true,
            ),
            'maxRetries': _i1.ParameterDescription(
              name: 'maxRetries',
              type: _i1.getType<int?>(),
              nullable: true,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['adexService'] as _i2.AdexServiceEndpoint)
                  .processVideo(
                    session,
                    params['video'],
                    params['userPrompt'],
                    whatDoesThisVideoContain:
                        params['whatDoesThisVideoContain'],
                    suggestFramesToExtract: params['suggestFramesToExtract'],
                    extractToText: params['extractToText'],
                    extractedDataInformationPrompt:
                        params['extractedDataInformationPrompt'],
                    concurrency: params['concurrency'],
                    delayBetweenBatchesMs: params['delayBetweenBatchesMs'],
                    maxRetries: params['maxRetries'],
                  ),
        ),
        'getProcessingStatus': _i1.MethodConnector(
          name: 'getProcessingStatus',
          params: {
            'adexModelId': _i1.ParameterDescription(
              name: 'adexModelId',
              type: _i1.getType<int>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['adexService'] as _i2.AdexServiceEndpoint)
                  .getProcessingStatus(
                    session,
                    params['adexModelId'],
                  ),
        ),
        'getProcessingStatusByProcessingId': _i1.MethodConnector(
          name: 'getProcessingStatusByProcessingId',
          params: {
            'processingId': _i1.ParameterDescription(
              name: 'processingId',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['adexService'] as _i2.AdexServiceEndpoint)
                  .getProcessingStatusByProcessingId(
                    session,
                    params['processingId'],
                  ),
        ),
        'getAllAdexModels': _i1.MethodConnector(
          name: 'getAllAdexModels',
          params: {},
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['adexService'] as _i2.AdexServiceEndpoint)
                  .getAllAdexModels(session),
        ),
      },
    );
    connectors['emailIdp'] = _i1.EndpointConnector(
      name: 'emailIdp',
      endpoint: endpoints['emailIdp']!,
      methodConnectors: {
        'login': _i1.MethodConnector(
          name: 'login',
          params: {
            'email': _i1.ParameterDescription(
              name: 'email',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'password': _i1.ParameterDescription(
              name: 'password',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['emailIdp'] as _i3.EmailIdpEndpoint).login(
                session,
                email: params['email'],
                password: params['password'],
              ),
        ),
        'startRegistration': _i1.MethodConnector(
          name: 'startRegistration',
          params: {
            'email': _i1.ParameterDescription(
              name: 'email',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['emailIdp'] as _i3.EmailIdpEndpoint)
                  .startRegistration(
                    session,
                    email: params['email'],
                  ),
        ),
        'verifyRegistrationCode': _i1.MethodConnector(
          name: 'verifyRegistrationCode',
          params: {
            'accountRequestId': _i1.ParameterDescription(
              name: 'accountRequestId',
              type: _i1.getType<_i1.UuidValue>(),
              nullable: false,
            ),
            'verificationCode': _i1.ParameterDescription(
              name: 'verificationCode',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['emailIdp'] as _i3.EmailIdpEndpoint)
                  .verifyRegistrationCode(
                    session,
                    accountRequestId: params['accountRequestId'],
                    verificationCode: params['verificationCode'],
                  ),
        ),
        'finishRegistration': _i1.MethodConnector(
          name: 'finishRegistration',
          params: {
            'registrationToken': _i1.ParameterDescription(
              name: 'registrationToken',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'password': _i1.ParameterDescription(
              name: 'password',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['emailIdp'] as _i3.EmailIdpEndpoint)
                  .finishRegistration(
                    session,
                    registrationToken: params['registrationToken'],
                    password: params['password'],
                  ),
        ),
        'startPasswordReset': _i1.MethodConnector(
          name: 'startPasswordReset',
          params: {
            'email': _i1.ParameterDescription(
              name: 'email',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['emailIdp'] as _i3.EmailIdpEndpoint)
                  .startPasswordReset(
                    session,
                    email: params['email'],
                  ),
        ),
        'verifyPasswordResetCode': _i1.MethodConnector(
          name: 'verifyPasswordResetCode',
          params: {
            'passwordResetRequestId': _i1.ParameterDescription(
              name: 'passwordResetRequestId',
              type: _i1.getType<_i1.UuidValue>(),
              nullable: false,
            ),
            'verificationCode': _i1.ParameterDescription(
              name: 'verificationCode',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['emailIdp'] as _i3.EmailIdpEndpoint)
                  .verifyPasswordResetCode(
                    session,
                    passwordResetRequestId: params['passwordResetRequestId'],
                    verificationCode: params['verificationCode'],
                  ),
        ),
        'finishPasswordReset': _i1.MethodConnector(
          name: 'finishPasswordReset',
          params: {
            'finishPasswordResetToken': _i1.ParameterDescription(
              name: 'finishPasswordResetToken',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'newPassword': _i1.ParameterDescription(
              name: 'newPassword',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['emailIdp'] as _i3.EmailIdpEndpoint)
                  .finishPasswordReset(
                    session,
                    finishPasswordResetToken:
                        params['finishPasswordResetToken'],
                    newPassword: params['newPassword'],
                  ),
        ),
      },
    );
    connectors['jwtRefresh'] = _i1.EndpointConnector(
      name: 'jwtRefresh',
      endpoint: endpoints['jwtRefresh']!,
      methodConnectors: {
        'refreshAccessToken': _i1.MethodConnector(
          name: 'refreshAccessToken',
          params: {
            'refreshToken': _i1.ParameterDescription(
              name: 'refreshToken',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['jwtRefresh'] as _i4.JwtRefreshEndpoint)
                  .refreshAccessToken(
                    session,
                    refreshToken: params['refreshToken'],
                  ),
        ),
      },
    );
    connectors['greeting'] = _i1.EndpointConnector(
      name: 'greeting',
      endpoint: endpoints['greeting']!,
      methodConnectors: {
        'hello': _i1.MethodConnector(
          name: 'hello',
          params: {
            'name': _i1.ParameterDescription(
              name: 'name',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['greeting'] as _i5.GreetingEndpoint).hello(
                session,
                params['name'],
              ),
        ),
      },
    );
    connectors['upload'] = _i1.EndpointConnector(
      name: 'upload',
      endpoint: endpoints['upload']!,
      methodConnectors: {
        'getUploadDescription': _i1.MethodConnector(
          name: 'getUploadDescription',
          params: {
            'storagePath': _i1.ParameterDescription(
              name: 'storagePath',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['upload'] as _i6.UploadEndpoint)
                  .getUploadDescription(
                    session,
                    params['storagePath'],
                  ),
        ),
        'verifyUpload': _i1.MethodConnector(
          name: 'verifyUpload',
          params: {
            'storagePath': _i1.ParameterDescription(
              name: 'storagePath',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['upload'] as _i6.UploadEndpoint).verifyUpload(
                    session,
                    params['storagePath'],
                  ),
        ),
        'storeFile': _i1.MethodConnector(
          name: 'storeFile',
          params: {
            'storagePath': _i1.ParameterDescription(
              name: 'storagePath',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'fileData': _i1.ParameterDescription(
              name: 'fileData',
              type: _i1.getType<_i7.ByteData>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['upload'] as _i6.UploadEndpoint).storeFile(
                session,
                params['storagePath'],
                params['fileData'],
              ),
        ),
        'getPublicUrl': _i1.MethodConnector(
          name: 'getPublicUrl',
          params: {
            'storagePath': _i1.ParameterDescription(
              name: 'storagePath',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['upload'] as _i6.UploadEndpoint).getPublicUrl(
                    session,
                    params['storagePath'],
                  ),
        ),
        'listFiles': _i1.MethodConnector(
          name: 'listFiles',
          params: {},
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['upload'] as _i6.UploadEndpoint).listFiles(
                session,
              ),
        ),
        'deleteFile': _i1.MethodConnector(
          name: 'deleteFile',
          params: {
            'storagePath': _i1.ParameterDescription(
              name: 'storagePath',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['upload'] as _i6.UploadEndpoint).deleteFile(
                session,
                params['storagePath'],
              ),
        ),
      },
    );
    modules['serverpod_auth_idp'] = _i8.Endpoints()
      ..initializeEndpoints(server);
    modules['serverpod_auth_core'] = _i9.Endpoints()
      ..initializeEndpoints(server);
  }
}
