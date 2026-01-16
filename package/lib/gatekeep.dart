library;

/// Gatekeep Flutter SDK

// Core exports
export 'src/config/gatekeep_config.dart';
export 'src/config/gatekeep_initializer.dart';

// Models
export 'src/models/queue_status.dart';
export 'src/models/admission_token.dart';
export 'src/models/queue_state.dart';
export 'src/models/join_request.dart';
export 'src/models/heartbeat_request.dart';

// Client
export 'src/client/queue_client.dart';
export 'src/client/queue_client_interface.dart';
export 'src/client/queue_client_factory.dart';

// Network
export 'src/network/http_client_interface.dart';
export 'src/network/gatekeep_http_client.dart';
export 'src/network/request_interceptor.dart';
export 'src/network/response_interceptor.dart';

// Errors
export 'src/errors/gatekeep_exception.dart';
export 'src/errors/queue_exception.dart';
export 'src/errors/network_exception.dart';
export 'src/errors/token_exception.dart';

// Plugins
export 'src/plugins/plugin_interface.dart';
export 'src/plugins/plugin_registry.dart';
export 'src/plugins/analytics_plugin.dart';
export 'src/plugins/logging_plugin.dart';

// Storage
export 'src/storage/storage_interface.dart';
export 'src/storage/secure_storage.dart';

// Utils
export 'src/utils/retry_strategy.dart';
export 'src/utils/backoff_calculator.dart';

// UI - Themes
export 'src/ui/themes/gatekeep_theme.dart';
export 'src/ui/themes/theme_provider.dart';

// UI - Localization
export 'src/ui/localization/gatekeep_localizations.dart';

// UI - Components
export 'src/ui/components/queue_position_widget.dart';
export 'src/ui/components/progress_indicator.dart';
export 'src/ui/components/countdown_timer.dart';
export 'src/ui/components/status_badge.dart';
export 'src/ui/components/error_display.dart';

// UI - Screens
export 'src/ui/screens/waiting_room_screen.dart';

// UI - Customization
export 'src/ui/customization/waiting_room_config.dart';
export 'src/ui/customization/customization_config.dart';

// UI - Utils
export 'src/ui/utils/responsive_layout.dart';
export 'src/ui/utils/platform_check.dart';
