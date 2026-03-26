#include <stdint.h>
#include <stdlib.h>

#if _WIN32
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT
#endif

typedef struct RustNetBinaryResult {
  uint8_t is_success;
  uint16_t status_code;
  char *headers_json;
  char *final_url;
  uint8_t *body_ptr;
  uintptr_t body_len;
  char *error_json;
} RustNetBinaryResult;

typedef void (*RustNetExecuteCallback)(uint64_t request_id, RustNetBinaryResult *result);

FFI_PLUGIN_EXPORT uint64_t rust_net_client_create(const char *config_json);
FFI_PLUGIN_EXPORT uint8_t rust_net_client_execute_async(
    uint64_t client_id,
    uint64_t request_id,
    const char *request_json,
    const uint8_t *body_ptr,
    uintptr_t body_len,
    RustNetExecuteCallback callback);
FFI_PLUGIN_EXPORT RustNetBinaryResult *rust_net_client_execute_binary(
    uint64_t client_id,
    const char *request_json,
    const uint8_t *body_ptr,
    uintptr_t body_len);
FFI_PLUGIN_EXPORT void rust_net_client_close(uint64_t client_id);
FFI_PLUGIN_EXPORT void rust_net_binary_result_free(RustNetBinaryResult *value);
