import 'package:mailer/mailer.dart' as mailer;
import 'package:mailer/smtp_server.dart';
import 'package:serverpod/serverpod.dart';

/// Service for sending branded emails via Gmail SMTP.
class EmailService {
  final String _gmailUsername;
  final String _gmailPassword;

  EmailService({
    required String gmailUsername,
    required String gmailPassword,
  })  : _gmailUsername = gmailUsername,
        _gmailPassword = gmailPassword;

  /// Creates an [EmailService] from Serverpod passwords config.
  /// Returns `null` if credentials are missing.
  static EmailService? fromPasswords(Serverpod pod) {
    final username = pod.getPassword('gmailUsername');
    final password = pod.getPassword('gmailPassword');

    if (username == null ||
        username.isEmpty ||
        password == null ||
        password.isEmpty) {
      return null;
    }

    return EmailService(
      gmailUsername: username,
      gmailPassword: password,
    );
  }

  /// Sends a registration verification code email.
  Future<void> sendRegistrationCode({
    required Session session,
    required String recipientEmail,
    required String verificationCode,
  }) async {
    final html = _buildEmailHtml(
      heading: 'Verify Your Account',
      preheader: 'Your ADEX verification code is $verificationCode',
      bodyContent: '''
        <p style="margin: 0 0 16px; color: #374151; font-size: 16px; line-height: 1.6;">
          Welcome to <strong>ADEX</strong>! To complete your registration, use the verification code below:
        </p>
        ${_codeBlock(verificationCode)}
        <p style="margin: 24px 0 0; color: #6b7280; font-size: 14px; line-height: 1.5;">
          This code expires in 10 minutes. If you didn't create an account with ADEX, you can safely ignore this email.
        </p>
      ''',
    );

    await _send(
      session: session,
      to: recipientEmail,
      subject: 'ADEX - Verify Your Account',
      html: html,
    );
  }

  /// Sends a password reset verification code email.
  Future<void> sendPasswordResetCode({
    required Session session,
    required String recipientEmail,
    required String verificationCode,
  }) async {
    final html = _buildEmailHtml(
      heading: 'Reset Your Password',
      preheader: 'Your ADEX password reset code is $verificationCode',
      bodyContent: '''
        <p style="margin: 0 0 16px; color: #374151; font-size: 16px; line-height: 1.6;">
          We received a request to reset the password for your <strong>ADEX</strong> account. Use the code below to proceed:
        </p>
        ${_codeBlock(verificationCode)}
        <p style="margin: 24px 0 0; color: #6b7280; font-size: 14px; line-height: 1.5;">
          This code expires in 10 minutes. If you didn't request a password reset, you can safely ignore this email &mdash; your account is secure.
        </p>
      ''',
    );

    await _send(
      session: session,
      to: recipientEmail,
      subject: 'ADEX - Password Reset Code',
      html: html,
    );
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Future<void> _send({
    required Session session,
    required String to,
    required String subject,
    required String html,
  }) async {
    final smtpServer = gmail(_gmailUsername, _gmailPassword);

    final message = mailer.Message()
      ..from = mailer.Address(_gmailUsername, 'ADEX')
      ..recipients.add(to)
      ..subject = subject
      ..html = html;

    try {
      await mailer.send(message, smtpServer);
      session.log('[EmailService] Email sent to $to ($subject)');
    } catch (e) {
      session.log('[EmailService] Failed to send email to $to: $e',
          level: LogLevel.error);
      rethrow;
    }
  }

  /// Renders the verification code once in a clean, easy-to-copy block.
  String _codeBlock(String code) {
    return '''
      <table role="presentation" cellpadding="0" cellspacing="0" width="100%" style="margin: 24px 0;">
        <tr>
          <td align="center">
            <table role="presentation" cellpadding="0" cellspacing="0">
              <tr>
                <td style="
                  background-color: #f3f4f6;
                  border: 2px solid #e5e7eb;
                  border-radius: 12px;
                  padding: 18px 32px;
                  text-align: center;
                ">
                  <span style="
                    font-family: 'SF Mono', 'Fira Code', 'Consolas', 'Courier New', monospace;
                    font-size: 32px;
                    font-weight: 700;
                    color: #7B1FA2;
                    letter-spacing: 10px;
                    user-select: all;
                    -webkit-user-select: all;
                    -moz-user-select: all;
                  ">$code</span>
                </td>
              </tr>
            </table>
          </td>
        </tr>
      </table>
    ''';
  }

  /// Builds the full HTML email with ADEX branding.
  String _buildEmailHtml({
    required String heading,
    required String preheader,
    required String bodyContent,
  }) {
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>$heading</title>
</head>
<body style="margin: 0; padding: 0; background-color: #f3f4f6; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;">
  <!-- Preheader (hidden preview text) -->
  <div style="display: none; max-height: 0; overflow: hidden;">
    $preheader
  </div>

  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color: #f3f4f6;">
    <tr>
      <td align="center" style="padding: 40px 16px;">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width: 480px;">

          <!-- Logo header -->
          <tr>
            <td align="center" style="padding-bottom: 32px;">
              <table role="presentation" cellpadding="0" cellspacing="0">
                <tr>
                  <td style="
                    background-color: #7B1FA2;
                    border-radius: 12px;
                    padding: 12px 24px;
                  ">
                    <span style="
                      font-size: 24px;
                      font-weight: 800;
                      color: #ffffff;
                      letter-spacing: 4px;
                    ">ADEX</span>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Main card -->
          <tr>
            <td style="
              background-color: #ffffff;
              border-radius: 16px;
              padding: 40px 32px;
              box-shadow: 0 1px 3px rgba(0,0,0,0.08);
            ">
              <!-- Heading -->
              <h1 style="margin: 0 0 24px; font-size: 22px; font-weight: 700; color: #111827; text-align: center;">
                $heading
              </h1>

              <!-- Body content -->
              $bodyContent
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="padding: 24px 0; text-align: center;">
              <p style="margin: 0 0 4px; color: #9ca3af; font-size: 12px;">
                Adaptive Data Extraction System
              </p>
              <p style="margin: 0; color: #d1d5db; font-size: 11px;">
                This is an automated message. Please do not reply.
              </p>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>
''';
  }
}
