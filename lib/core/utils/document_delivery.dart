// Platform-neutral document delivery.
//
// `dart:io` and browser APIs cannot live in the same library, so the correct
// implementation is selected at compile time.
export 'document_delivery_contract.dart';
export 'document_delivery_stub.dart'
    if (dart.library.io) 'document_delivery_io.dart'
    if (dart.library.js_interop) 'document_delivery_web.dart';
