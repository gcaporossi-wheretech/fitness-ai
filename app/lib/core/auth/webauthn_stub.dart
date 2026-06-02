/// Non-web fallback: WebAuthn (Face ID via browser) is only available on web.

bool webauthnSupported() => false;

Future<Map<String, dynamic>> webauthnRegister(Map<String, dynamic> options) =>
    throw UnsupportedError('WebAuthn is only available on the web build');

Future<Map<String, dynamic>> webauthnAuthenticate(Map<String, dynamic> options) =>
    throw UnsupportedError('WebAuthn is only available on the web build');

void downloadFile(String filename, String text) {
  throw UnsupportedError('File download is only available on the web build');
}
