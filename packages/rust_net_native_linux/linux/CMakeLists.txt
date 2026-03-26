cmake_minimum_required(VERSION 3.14)

set(PROJECT_NAME "rust_net_native_linux")
project(${PROJECT_NAME} LANGUAGES CXX)

set(rust_net_native_linux_bundled_libraries
  "${CMAKE_CURRENT_SOURCE_DIR}/Libraries/librust_net_native.so"
)

set(rust_net_native_linux_bundled_libraries
  ${rust_net_native_linux_bundled_libraries}
  PARENT_SCOPE
)
