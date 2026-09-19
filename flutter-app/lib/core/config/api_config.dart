class ApiConfig {
  ApiConfig._();

  /// Android emulator
  static const androidEmulatorBaseUrl = 'http://10.0.2.2:8080';

  /// Physical Android phone on the same LAN
  static const matchingBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.83.160.240:8080',
  );

  static const headOfficialEmail = String.fromEnvironment(
    'HEAD_OFFICIAL_EMAIL',
    defaultValue: 'ashmitsingh061@gmail.com',
  );
}
