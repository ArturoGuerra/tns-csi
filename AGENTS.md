# Agent Instructions for CSI Driver Development

## Critical Rules for Working on This Codebase

### 1. **DO NOT MODIFY WORKING WEBSOCKET CONNECTION LOGIC**

The WebSocket client in `pkg/tnsapi/client.go` has a **working ping/pong loop** and connection health monitoring system. This includes:

- ✅ `pingLoop()` (line 356-393) - Sends WebSocket pings every 30 seconds
- ✅ `readLoop()` (line 227-294) - Reads responses and handles reconnection
- ✅ `reconnect()` (line 297-353) - Automatic reconnection with exponential backoff
- ✅ Read deadline of 120 seconds (4x ping interval) to detect dead connections

**NEVER** suggest changes to:
- Ping/pong interval timing
- Connection endpoint URLs (they are fixed at initialization)
- The reconnection logic flow
- The read/write deadline management

### 2. **TrueNAS API Specifics**

The TrueNAS WebSocket API has specific behaviors:
- Uses JSON-RPC 2.0 format
- WebSocket endpoint: `wss://<host>/websocket`
- Authentication method: `auth.login_with_api_key`
- TrueNAS server **does not send pings** - we must send them (see comment on line 136)
- Server responds with pongs to our pings
- Connection stays at the **same endpoint** after authentication

### 3. **When to Suggest Changes**

Only suggest changes to WebSocket code if:
1. There is a **proven bug** with reproduction steps
2. User explicitly requests modification with specific requirements
3. Adding new API method wrappers (dataset, NFS, NVMe-oF operations)

### 4. **What to Focus On Instead**

When helping with this project, focus on:
- CSI driver functionality (controller.go, node.go, identity.go)
- Storage provisioning logic
- Kubernetes integration
- Error handling in API calls
- Adding new TrueNAS API method wrappers
- Deployment and testing improvements
- Documentation

### 5. **Debugging Approach**

If connection issues are reported:
1. First check if authentication is failing (API key validation)
2. Check if network/TLS configuration is the issue
3. Review logs for specific error messages
4. **DO NOT immediately suggest changing ping intervals or reconnection logic**
5. Consider if the issue is in the calling code, not the client itself

### 6. **Code Review Checklist**

Before suggesting any changes to `pkg/tnsapi/client.go`:
- [ ] Is there a specific error or bug report?
- [ ] Have you identified the root cause?
- [ ] Will this change affect the working ping/pong system?
- [ ] Is this change necessary or just "improvement for the sake of it"?
- [ ] Have you tested the change or verified it won't break existing functionality?

## Summary

**The WebSocket client works. Don't fix what isn't broken.**

Focus efforts on:
- Building out CSI driver features
- Improving error handling
- Adding API coverage
- Testing and deployment

Avoid:
- Randomly tweaking timing parameters
- Changing connection flow "to make it better"
- Suggesting architectural rewrites without proven need
- Second-guessing design decisions that are working
