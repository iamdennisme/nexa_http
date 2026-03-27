#ifndef NEXA_HTTP_NATIVE_H_
#define NEXA_HTTP_NATIVE_H_

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct NexaHttpBinaryResult {
  uint8_t is_success;
  uint16_t status_code;
  char* headers_json;
  char* final_url;
  uint8_t* body_ptr;
  uintptr_t body_len;
  char* error_json;
} NexaHttpBinaryResult;

typedef void (*NexaHttpExecuteCallback)(uint64_t request_id, NexaHttpBinaryResult* result);

uint64_t nexa_http_client_create(const char* config_json);
uint8_t nexa_http_client_execute_async(
    uint64_t client_id,
    uint64_t request_id,
    const char* request_json,
    const uint8_t* body_ptr,
    uintptr_t body_len,
    NexaHttpExecuteCallback callback);
NexaHttpBinaryResult* nexa_http_client_execute_binary(
    uint64_t client_id,
    const char* request_json,
    const uint8_t* body_ptr,
    uintptr_t body_len);
void nexa_http_client_close(uint64_t client_id);
void nexa_http_binary_result_free(NexaHttpBinaryResult* result);

#ifdef __cplusplus
}  // extern "C"
#endif

#endif  // NEXA_HTTP_NATIVE_H_
