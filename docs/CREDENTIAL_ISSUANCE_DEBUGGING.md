# Credential Issuance Debugging Guide

## Problem
During the EUDI credential issuance flow, the app:
1. Opens browser for authorization
2. User fills details and authorizes
3. Returns to app
4. **ADB/logcat disconnects**
5. No visibility into what happened
6. No credential appears

## Solution

### 1. Persistent File Logging
All credential issuance events are now logged to a persistent file at:
- **Android**: `/data/data/com.example.ssi/files/credential_issuance.log`

This log survives even when adb disconnects, and includes:
- Authorization callback events
- Token exchange status
- Credential issuance events
- Any errors with full stack traces

### 2. UI Feedback
Enhanced user feedback throughout the flow:

#### During Authorization Callback
- Shows "Processing Credential" dialog with progress message
- Automatically refreshes credentials after authorization
- Compares credential count before/after to detect success
- Shows clear success/failure messages

#### Status Messages
- ✓ Success: "Credential received successfully!"
- ⚠️ Warning: "Authorization completed, but no credential was received yet"
- ❌ Error: "The credential issuance process was interrupted"

### 3. Debug Logs Screen
A new debug screen accessible from the home view:
- **Bug icon** in the app bar
- Shows all logs from `credential_issuance.log`
- Refresh button to reload logs
- Copy button to copy logs to clipboard
- Scrollable, selectable text for easy reading

## How to Debug Credential Issuance Issues

### Step 1: Start Fresh
1. Open the app
2. Go to home screen
3. Tap the **bug icon** (🐛) in the app bar
4. Note the current log size

### Step 2: Perform Credential Flow
1. Go back to home
2. Scan QR code for credential offer
3. App shows "Retrieving credentials..." loader
4. Browser opens
5. Fill in details and authorize
6. Return to app

### Step 3: Check Results
The app will automatically:
- Show a "Processing Credential" dialog
- Wait 3 seconds for token exchange
- Refresh credentials
- Compare before/after counts
- Show success or failure dialog

### Step 4: View Debug Logs
1. Tap the **bug icon** (🐛) again
2. View detailed logs showing:
   - `========== AUTHORIZATION CALLBACK START ==========`
   - Authorization URI details
   - Whether `activeOpenId4VciManager` was found
   - Result of `resumeWithAuthorization()` call
   - `========== ISSUE EVENT: ... ==========` entries
   - Success/failure of credential issuance

### Step 5: Share Logs (if needed)
1. In debug screen, tap **Copy** icon
2. Logs are copied to clipboard
3. Paste into email/slack/issue tracker

## Log File Details

### Key Log Entries to Look For

#### 1. Authorization Callback
```
I/EudiSsiApiImpl: ========== AUTHORIZATION CALLBACK START ==========
I/EudiSsiApiImpl: Handling authorization callback (from Flutter): eudi-openid4ci://authorize?...
I/EudiSsiApiImpl: Parsed URI - Code present: true, State: <state-value>
I/EudiSsiApiImpl: Calling resumeWithAuthorization...
I/EudiSsiApiImpl: resumeWithAuthorization completed - waiting for IssueEvent callbacks
```

#### 2. Successful Credential Issuance
```
I/EudiSsiApiImpl: ========== ISSUE EVENT: DocumentIssued ==========
I/EudiSsiApiImpl: SUCCESS: Credential issued - ID: <credential-id>, Name: <name>
I/EudiSsiApiImpl: ========== ISSUE EVENT: Finished ==========
I/EudiSsiApiImpl: SUCCESS: Finished issuing documents: 1 issued
I/EudiSsiApiImpl:   Document 0: ID=<id>, Name=<name>
```

#### 3. Common Errors

**SDK Lost State (app restarted during auth):**
```
E/EudiSsiApiImpl: CRITICAL: No active OpenId4VciManager - SDK lost state due to app restart
E/EudiSsiApiImpl: Authorization flow cannot be recovered. User must restart credential offer.
```

**Duplicate Processing:**
```
W/EudiSsiApiImpl: Authorization URI already processed, ignoring duplicate
```

**Issuance Failure:**
```
E/EudiSsiApiImpl: ========== ISSUE EVENT: Failure ==========
E/EudiSsiApiImpl: FAILURE: Issuance failed
E/EudiSsiApiImpl: <stack trace>
```

## Accessing Log File Directly

### Via ADB
```bash
# Pull the log file
adb pull /data/data/com.example.ssi/files/credential_issuance.log

# View in terminal
adb shell cat /data/data/com.example.ssi/files/credential_issuance.log

# Monitor in real-time
adb shell "tail -f /data/data/com.example.ssi/files/credential_issuance.log"
```

### Via Android Device File Manager
1. Enable Developer Options
2. Enable USB Debugging
3. Connect via USB
4. Use Android Studio Device File Explorer:
   - View → Tool Windows → Device File Explorer
   - Navigate to: `/data/data/com.example.ssi/files/`
   - Right-click `credential_issuance.log` → Save As

## Known Issues & Workarounds

### Issue 1: App Restart During Authorization
**Symptom**: After authorizing in browser, credential is not issued
**Cause**: Android killed the app to free memory, SDK lost internal state
**Workaround**: Scan QR code again to restart the flow

**Log Signature**:
```
E/EudiSsiApiImpl: CRITICAL: No active OpenId4VciManager - SDK lost state
```

**Long-term Solution**: Implement a foreground service during credential issuance

### Issue 2: ADB Disconnects
**Symptom**: Can't see logs after returning from browser
**Solution**: Use the built-in debug logs screen (bug icon 🐛)

### Issue 3: Duplicate Authorization Processing (FIXED)
**Symptom**: Logs show "Authorization URI already processed by active manager, ignoring duplicate"
**Cause**: Both MainActivity.onNewIntent() and Flutter were handling the same deep link
**Fix**: MainActivity no longer calls `handleAuthorizationResponse()` - Flutter handles all authorization callbacks

**Log Signature**:
```
W/EudiSsiApiImpl: Authorization URI already processed by active manager, ignoring duplicate
```

**Resolution**: Commented out MainActivity's call to `handleAuthorizationResponse()` so Flutter is the sole handler

### Issue 4: Missing DocumentRequiresCreateSettings Handler (FIXED)
**Symptom**: Logs show "Unhandled issue event: DocumentRequiresCreateSettings", credential never issued
**Cause**: SDK was asking for document creation settings but app wasn't responding
**Fix**: Added handler for `DocumentRequiresCreateSettings` that calls `event.resume()` with default settings

**Log Signature**:
```
I/EudiSsiApiImpl: ========== ISSUE EVENT: DocumentRequiresCreateSettings ==========
D/EudiSsiApiImpl: Unhandled issue event: DocumentRequiresCreateSettings
```

**Resolution**: Added `is IssueEvent.DocumentRequiresCreateSettings` case that automatically resumes with defaults

## Testing Tips

1. **Always check debug logs** after each credential attempt
2. **Look for event sequence**: Authorization → DocumentIssued → Finished
3. **Verify credential count** changes in the UI
4. **If logs show success but no credential**, check `getCredentials()` call
5. **Clear app data** between tests to ensure clean state

## File Maintenance

The log file automatically:
- Rotates when it exceeds 500KB
- Keeps last 1000 lines
- Appends new logs with timestamps
- Persists across app restarts

To manually clear:
```bash
adb shell "rm /data/data/com.example.ssi/files/credential_issuance.log"
```

## Next Steps

If credential issuance still fails after reviewing logs:

1. Check the specific error in logs
2. Verify issuer URL is correct
3. Ensure network connectivity
4. Test with different credential offers
5. Contact EUDI Wallet SDK support with logs
