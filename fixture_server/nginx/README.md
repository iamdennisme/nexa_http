# Local Proxy Testing

This directory is optional. The primary local test target is the lightweight
fixture server in [`../http_fixture_server.dart`](../http_fixture_server.dart).

Use Nginx only when you need proxy-specific behavior such as:

- gzip or proxy buffering
- keep-alive and connection reuse observation
- reverse-proxy headers
- gateway-style failure modes

## Suggested local flow

1. Start the fixture server:

   ```bash
   dart run 'fixture_server/http_fixture_server.dart' --port 8080
   ```

2. Start Nginx through Docker Compose:

   ```bash
   docker compose -f 'fixture_server/docker-compose.yml' up -d nginx
   ```

3. Point the example app or SDK test target at `http://127.0.0.1:8081`.

   `zsh` users should quote URLs containing `?`, for example:

   ```bash
   curl 'http://127.0.0.1:8081/get?source=local'
   curl -I 'http://127.0.0.1:8081/head'
   curl -X DELETE 'http://127.0.0.1:8081/delete'
   curl 'http://127.0.0.1:8081/status/404'
   curl 'http://127.0.0.1:8081/redirect/302?location=/get?source=redirected'
   ```

4. Stop the proxy when done:

   ```bash
   docker compose -f 'fixture_server/docker-compose.yml' down
   ```

The bundled config proxies traffic to `host.docker.internal:8080`, so the
fixture server continues to run on your host machine.
