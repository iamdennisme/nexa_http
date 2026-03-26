import '../data/sources/ffi_rust_net_native_data_source.dart';
import '../data/sources/rust_net_native_data_source.dart';
import '../ffi/rust_net_native_library_resolver.dart';

typedef RustNetLibraryPathResolver = String Function({String? explicitPath});
typedef RustNetNativeDataSourceCreator =
    RustNetNativeDataSource Function(String libraryPath);

final class RustNetNativeDataSourceFactory {
  const RustNetNativeDataSourceFactory({
    this.resolveLibraryPath = RustNetNativeLibraryResolver.resolve,
    this.createDataSource = _createFfiDataSource,
  });

  final RustNetLibraryPathResolver resolveLibraryPath;
  final RustNetNativeDataSourceCreator createDataSource;

  RustNetNativeDataSource create({String? libraryPath}) {
    final resolvedLibraryPath = libraryPath ?? resolveLibraryPath();
    return createDataSource(resolvedLibraryPath);
  }

  static RustNetNativeDataSource _createFfiDataSource(String libraryPath) {
    return FfiRustNetNativeDataSource(libraryPath: libraryPath);
  }
}
