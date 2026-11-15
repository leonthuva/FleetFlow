class AppConfig {
  const AppConfig._();

  static const bool demoMode =
      bool.fromEnvironment('DEMO_MODE', defaultValue: false);
}
