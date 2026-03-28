#ifndef NEXA_HTTP_NATIVE_H_
#define NEXA_HTTP_NATIVE_H_

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct NexaHttpHeaderEntry {
  const char* name_ptr;
  uintptr_t name_len;
  const char* value_ptr;
  uintptr_t value_len;
} NexaHttpHeaderEntry;

typedef struct NexaHttpRequestArgs {
  const char* method_ptr;
  uintptr_t method_len;
  const char* url_ptr;
  uintptr_t url_len;
  const NexaHttpHeaderEntry* headers_ptr;
  uintptr_t headers_len;
  const uint8_t* body_ptr;
  uintptr_t body_len;
  uint64_t timeout_ms;
  uint8_t has_timeout;
} NexaHttpRequestArgs;

typedef struct NexaHttpBinaryResult {
  uint8_t is_success;
  uint16_t status_code;
  NexaHttpHeaderEntry* headers_ptr;
  uintptr_t headers_len;
  char* final_url_ptr;
  uintptr_t final_url_len;
  uint8_t* body_ptr;
  uintptr_t body_len;
  char* error_json;
} NexaHttpBinaryResult;

typedef void (*NexaHttpExecuteCallback)(uint64_t request_id, NexaHttpBinaryResult* result);

uint64_t nexa_http_client_create(const char* config_json);
uint8_t nexa_http_client_execute_async(
    uint64_t client_id,
    uint64_t request_id,
    const NexaHttpRequestArgs* request_args,
    NexaHttpExecuteCallback callback);
NexaHttpBinaryResult* nexa_http_client_execute_binary(
    uint64_t client_id,
    const NexaHttpRequestArgs* request_args);
void nexa_http_client_close(uint64_t client_id);
void nexa_http_binary_result_free(NexaHttpBinaryResult* result);

#ifdef __cplusplus
}  // extern "C"
#endif

#endif  // NEXA_HTTP_NATIVE_H_
