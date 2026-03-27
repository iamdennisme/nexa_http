cmake_minimum_required(VERSION 3.14)

set(PROJECT_NAME "nexa_http")
project(${PROJECT_NAME} LANGUAGES CXX)

add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/../src" "${CMAKE_CURRENT_BINARY_DIR}/shared")

set(nexa_http_bundled_libraries
  $<TARGET_FILE:nexa_http>
)

set(nexa_http_native_library "${CMAKE_CURRENT_SOURCE_DIR}/Libraries/nexa_http_native.dll")
if(EXISTS "${nexa_http_native_library}")
  list(APPEND nexa_http_bundled_libraries "${nexa_http_native_library}")
endif()

set(nexa_http_bundled_libraries ${nexa_http_bundled_libraries} PARENT_SCOPE)
