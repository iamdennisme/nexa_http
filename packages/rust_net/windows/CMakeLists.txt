cmake_minimum_required(VERSION 3.14)

set(PROJECT_NAME "rust_net")
project(${PROJECT_NAME} LANGUAGES CXX)

add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/../src" "${CMAKE_CURRENT_BINARY_DIR}/shared")

set(rust_net_bundled_libraries
  $<TARGET_FILE:rust_net>
)

set(rust_net_native_library "${CMAKE_CURRENT_SOURCE_DIR}/Libraries/rust_net_native.dll")
if(EXISTS "${rust_net_native_library}")
  list(APPEND rust_net_bundled_libraries "${rust_net_native_library}")
endif()

set(rust_net_bundled_libraries ${rust_net_bundled_libraries} PARENT_SCOPE)
