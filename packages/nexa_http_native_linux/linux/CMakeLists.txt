cmake_minimum_required(VERSION 3.14)

set(PROJECT_NAME "nexa_http_native_linux")
project(${PROJECT_NAME} LANGUAGES CXX)

set(nexa_http_native_linux_bundled_libraries
  "${CMAKE_CURRENT_SOURCE_DIR}/Libraries/libnexa_http_native.so"
)

set(nexa_http_native_linux_bundled_libraries
  ${nexa_http_native_linux_bundled_libraries}
  PARENT_SCOPE
)
