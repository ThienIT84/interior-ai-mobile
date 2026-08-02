import 'image_export_contract.dart';
import 'image_export_service_stub.dart'
    if (dart.library.io) 'image_export_service_mobile.dart'
    if (dart.library.js_interop) 'image_export_service_web.dart'
    as platform;

export 'image_export_contract.dart';

ImageExportService createImageExportService() =>
    platform.createImageExportService();
