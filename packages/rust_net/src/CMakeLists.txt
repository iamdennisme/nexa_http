# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

project(rust_net_library VERSION 0.0.1 LANGUAGES C)

add_library(rust_net SHARED
  "rust_net.c"
)

set_target_properties(rust_net PROPERTIES
  PUBLIC_HEADER rust_net.h
  OUTPUT_NAME "rust_net"
)

target_compile_definitions(rust_net PUBLIC DART_SHARED_LIB)

if (ANDROID)
  # Support Android 15 16k page size
  target_link_options(rust_net PRIVATE "-Wl,-z,max-page-size=16384")
endif()
