# Manual E2E Test Verification
## Subtask 5-1: Complete Login Flow with Credentials

### Test Environment
- **Platform**: Windows Desktop
- **Device**: Local machine
- **Network**: Connected to internet
- **Test Account**: Valid NovelAI credentials required

### Prerequisites
1. Flutter environment is set up and verified
2. App is built and ready to launch
3. Have valid NovelAI test credentials (email/password)
4. Clear any existing authentication data (optional, for clean testing)

---

## Test Case 1: First-Time Login with Credentials

### Steps:
1. **Launch the application**
   - Run: `flutter run -d windows`
   - Expected: App launches successfully, splash screen appears

2. **Wait for auth check**
   - Expected: SplashScreen shows "加载中..." (Loading...)
   - Wait time: ~2-3 seconds
   - Expected: Auth check completes automatically

3. **Verify redirect to login screen**
   - Expected: LoginScreen is displayed
   - Expected: "登录" (Login) title is visible
   - Expected: Email and password fields are shown
   - Expected: No accounts are saved (first-time use)

4. **Enter email**
   - Action: Click email field
   - Action: Enter valid email (e.g., `test@example.com`)
   - Expected: Email is displayed in field
   - Expected: No validation errors for valid format

5. **Enter password**
   - Action: Click password field
   - Action: Enter valid password
   - Expected: Password is masked (dots/bullets)
   - Expected: Eye icon toggles visibility

6. **Verify auto-login checkbox**
   - Expected: "自动登录" (Auto-login) checkbox is checked by default
   - Optional: Uncheck to test manual login only

7. **Click login button**
   - Action: Click "登录" (Login) button
   - Expected: Button becomes disabled
   - Expected: Loading indicator appears (CircularProgressIndicator)
   - Expected: Loading overlay appears with "正在登录..." (Logging in...)

8. **Verify loading state**
   - Expected: Full-screen loading overlay is visible
   - Expected: "正在登录" text is shown
   - Expected: "请稍候..." (Please wait...) subtitle is shown
   - Expected: Loading spinner animates smoothly
   - Expected: Form inputs are disabled (can't interact)

9. **Wait for authentication**
   - Wait time: ~3-10 seconds (depends on network)
   - Expected: No crashes or errors
   - Expected: Loading overlay remains visible

10. **Verify successful redirect to home**
    - Expected: Loading overlay disappears smoothly
    - Expected: Transition animation plays (fade + slide)
    - Expected: HomeScreen is displayed
    - Expected: User is authenticated (check for username/account info)
    - Expected: No login screen is visible
    - Expected: No error messages are shown

### Success Criteria:
- [ ] App launches without errors
- [ ] Splash screen shows and auth check completes
- [ ] Login screen appears correctly
- [ ] Form accepts email and password input
- [ ] Login button triggers authentication
- [ ] Loading overlay appears with proper messaging
- [ ] Authentication completes successfully
- [ ] User is redirected to home screen
- [ ] Transition is smooth with animations
- [ ] No console errors or exceptions

---

## Test Case 2: Authentication Persistence Across Restart

### Steps:
1. **Complete Test Case 1** (login successfully)
2. **Verify home screen is displayed**
   - Expected: User account info is visible
   - Expected: App is fully functional

3. **Close the application**
   - Action: Close window (X button) or tray menu → 退出
   - Expected: App closes cleanly
   - Expected: No error messages on close

4. **Wait 5 seconds**
   - Ensure all processes terminate

5. **Relaunch the application**
   - Run: `flutter run -d windows`
   - Expected: App launches

6. **Wait for auth check**
   - Expected: SplashScreen appears briefly
   - Wait time: ~2-5 seconds (auto-login in progress)

7. **Verify auto-login worked**
   - Expected: HomeScreen is displayed automatically
   - Expected: No login screen is shown
   - Expected: User is already authenticated
   - Expected: Account info is visible
   - Expected: No need to re-enter credentials

8. **Verify stored credentials**
   - Check if access token is persisted (optional, via logs)
   - Expected: Auto-login setting is still enabled
   - Expected: Account is saved in AccountManager

### Success Criteria:
- [ ] Authentication persists across app restart
- [ ] Auto-login works automatically
- [ ] No need to re-enter credentials
- [ ] Home screen loads directly on restart
- [ ] No authentication errors on restart
- [ ] Stored credentials are secure

---

## Test Case 3: Loading State Verification

### Steps:
1. **Launch app and navigate to login**
2. **Start logging in**
   - Enter credentials
   - Click login button
3. **Observe loading states in sequence:**

   a) **Button-level loading**
      - Expected: Login button shows spinner
      - Expected: Button text changes to spinner
      - Expected: Button is disabled

   b) **Overlay loading**
      - Expected: Full-screen overlay appears
      - Expected: Semi-transparent background
      - Expected: Card with spinner appears in center
      - Expected: "正在登录" title
      - Expected: "请稍候..." subtitle

   c) **State transitions**
      - Monitor auth state via logs (if available)
      - Expected: AuthStatus.loading → AuthStatus.authenticated
      - Expected: No intermediate error states

   d) **Overlay dismissal**
      - Expected: Overlay fades out smoothly
      - Expected: Transition to home screen
      - Expected: No jarring cuts or flashes

### Success Criteria:
- [ ] Multiple loading indicators appear at appropriate times
- [ ] Loading states are visually clear
- [ ] User cannot interact with form during loading
- [ ] Overlay is dismissible (can tap outside to close)
- [ ] Loading animation is smooth
- [ ] No UI freezes or hangs

---

## Test Case 4: Error Handling (Negative Testing)

### Steps:
1. **Launch app and navigate to login**
2. **Enter invalid credentials**
   - Enter: `invalid@example.com` / `wrongpassword`
3. **Click login button**
4. **Verify error handling:**

   a) **Loading state**
      - Expected: Loading overlay appears briefly
      - Expected: API call is attempted

   b) **Error display**
      - Expected: Loading overlay disappears
      - Expected: Error Toast appears
      - Expected: Error message: "认证失败，请检查您的凭据" (Authentication failed)
      - Expected: Recovery hint: "💡 请检查邮箱和密码是否正确，或访问 NovelAI 重新设置密码"

   c) **Form state**
      - Expected: Form is still accessible
      - Expected: Credentials are preserved (not cleared)
      - Expected: Can retry immediately

   d) **Error container in form**
      - Expected: Red error container appears below form
      - Expected: Error icon is visible
      - Expected: Recovery hint is shown
      - Expected: No retry button (non-network error)

### Success Criteria:
- [ ] Error is caught and displayed properly
- [ ] Error message is clear and actionable
- [ ] Recovery hints are helpful
- [ ] User credentials are preserved
- [ ] App doesn't crash or freeze
- [ ] Can retry without re-entering credentials

---

## Test Case 5: Form Validation

### Steps:
1. **Launch app and navigate to login**
2. **Test email validation:**
   - Leave email empty, click login
   - Expected: "请输入邮箱" (Please enter email)
   - Enter `invalid` (no @), click login
   - Expected: "邮箱格式无效" (Invalid email format)

3. **Test password validation:**
   - Leave password empty, click login
   - Expected: "请输入密码" (Please enter password)
   - Enter `12345` (< 6 chars), click login
   - Expected: "密码至少6位" (Password must be at least 6 characters)

4. **Test valid inputs:**
   - Enter `test@example.com` and `123456`
   - Expected: No validation errors
   - Expected: Login button is enabled

### Success Criteria:
- [ ] All validators work correctly
- [ ] Validation messages are clear
- [ ] Form prevents submission with invalid data
- [ ] Valid inputs pass validation

---

## Test Case 6: Password Visibility Toggle

### Steps:
1. **Launch app and navigate to login**
2. **Enter password**
   - Expected: Password is masked (dots)
3. **Click eye icon**
   - Expected: Password becomes visible
   - Expected: Icon changes to "eye off" (slash through)
4. **Click eye icon again**
   - Expected: Password becomes masked again
   - Expected: Icon changes back to "eye"

### Success Criteria:
- [ ] Toggle works smoothly
- [ ] Icon changes correctly
- [ ] Password visibility switches properly
- [ ] No visual glitches

---

## Known Issues / Limitations

### Testing Constraints:
1. **No actual NovelAI credentials available in test environment**
   - Solution: Mock tests or use test account
   - Current: Integration test created but cannot run without valid API

2. **Cannot manually interact with GUI in CI environment**
   - Solution: Integration test uses widget tester
   - Current: Manual test checklist provided for human testers

3. **Network dependency**
   - Tests require active internet connection
   - NovelAI API must be accessible

---

## Verification Checklist

### Code Implementation:
- [x] CredentialsLoginForm accepts email/password
- [x] Form validation is implemented
- [x] AuthNotifier.loginWithCredentials() exists
- [x] Loading states are handled (isLoading)
- [x] Loading overlay is shown (LoginScreen)
- [x] Router redirects to home on success
- [x] Auto-login is enabled by default
- [x] Secure storage saves credentials
- [x] AccountManager saves account

### Expected Behavior (from code review):
1. ✅ Launch → SplashScreen → Auth check
2. ✅ Unauthenticated → Redirect to /login
3. ✅ Login form accepts input
4. ✅ Click login → AuthNotifier.loginWithCredentials()
5. ✅ Loading state → Overlay appears
6. ✅ Success → AuthState.authenticated
7. ✅ Router redirects → /home
8. ✅ Credentials saved to SecureStorage + AccountManager
9. ✅ Restart → Auto-login with saved credentials

### Integration Test:
- [x] Integration test file created: `test/integration/login_flow_test.dart`
- [x] Test cases cover all verification steps
- [ ] Tests can be run with: `flutter test test/integration/login_flow_test.dart`
- [ ] Tests pass (requires mocking or valid credentials)

---

---

## Test Case 7: Authentication Error Handling (Invalid Credentials)

### Steps:
1. **Launch app and navigate to login**
2. **Enter invalid credentials**
   - Email: `invalid@example.com`
   - Password: `wrongpassword123`
3. **Click login button**
4. **Verify error response:**

   a) **Loading state**
      - Expected: Loading overlay appears briefly
      - Expected: API call is attempted
      - Expected: Loading disappears after error

   b) **Error message display**
      - Expected: Red error container appears below form
      - Expected: Error icon (Icons.error_outline) is visible
      - Expected: Error message: "认证失败，请检查您的凭据"
      - Expected: Recovery hint: "💡 请检查邮箱和密码是否正确，或访问 NovelAI 重新设置密码"

   c) **Retry button**
      - Expected: No retry button shown (non-network error)
      - Expected: Only error message and recovery hint

   d) **Form state preservation**
      - Expected: Email field still contains `invalid@example.com`
      - Expected: Password field still contains `wrongpassword123`
      - Expected: Form is still editable
      - Expected: Can correct credentials without re-typing everything

   e) **Error state duration**
      - Expected: Error remains visible until user takes action
      - Expected: Error clears when user starts typing
      - Expected: Error clears on next login attempt

5. **Attempt recovery**
   - Correct email to: `valid@example.com`
   - Correct password to: `correctpassword`
   - Click login button
   - Expected: Error message disappears
   - Expected: New login attempt proceeds

### Success Criteria:
- [ ] Error message is clear and specific
- [ ] Recovery hint provides actionable guidance
- [ ] Form fields are preserved (not cleared)
- [ ] User can edit and retry without re-entering all data
- [ ] No retry button for auth errors (only network errors)
- [ ] Error state is visually distinct (red container)
- [ ] Error icon makes error immediately visible
- [ ] App doesn't crash or freeze on error

---

## Test Case 8: Network Error Handling with Retry

### Steps:
1. **Prepare network failure simulation**
   - Option A: Disconnect internet (WiFi/Ethernet)
   - Option B: Block NovelAI API via firewall
   - Option C: Use API proxy tool to return network errors

2. **Launch app and navigate to login**

3. **Enter valid credentials**
   - Use valid test credentials
   - Email: `test@example.com`
   - Password: `testpassword123`

4. **Click login button**

5. **Verify network error response:**

   a) **Loading state**
      - Expected: Loading overlay appears
      - Expected: Timeout after ~30 seconds (configurable)
      - Expected: Loading overlay disappears

   b) **Error message**
      - Expected: Red error container appears
      - Expected: Error message: "网络连接失败" OR "网络超时"
      - Expected: Recovery hint based on error type:
        - Timeout: "💡 请求超时，请检查网络连接后重试"
        - Network error: "💡 网络连接失败，请检查网络设置"

   c) **Retry button**
      - Expected: Retry button is shown (ElevatedButton.icon)
      - Expected: Icon: Icons.refresh
      - Expected: Label: "重试" (Retry)
      - Expected: Button is styled with error color scheme

   d) **Form state**
      - Expected: Email field preserved
      - Expected: Password field preserved
      - Expected: Form is still editable

6. **Verify retry functionality**
   - Re-enable network connection
   - Click retry button
   - Expected: Re-attempts login with preserved credentials
   - Expected: Loading state appears again
   - Expected: Successful login if credentials are valid

7. **Alternative: Manual retry**
   - Instead of clicking retry button
   - Correct credentials if needed
   - Click main login button
   - Expected: Works same as retry button

### Success Criteria:
- [ ] Network errors are detected and displayed
- [ ] Error message distinguishes between timeout and connection failure
- [ ] Recovery hints are network-specific
- [ ] Retry button appears (unlike auth errors)
- [ ] Retry button preserves form input
- [ ] Retry button re-triggers authentication
- [ ] Can retry without re-entering credentials
- [ ] Manual retry (via login button) also works
- [ ] Successful retry proceeds to home screen

---

## Test Case 9: Complete Error Recovery Flow

### Steps:
1. **Launch app and navigate to login**

2. **First attempt: Invalid credentials**
   - Enter: `wrong@example.com` / `wrongpass`
   - Click login
   - Verify error: "认证失败，请检查您的凭据"
   - Verify form is preserved
   - Verify no retry button

3. **Second attempt: Correct credentials**
   - Edit email to: `valid@example.com`
   - Edit password to: `validpass123`
   - Click login
   - Expected: Error clears
   - Expected: Loading state appears
   - Expected: Authentication proceeds

4. **Third attempt (simulate): Network failure then success**
   - Disconnect network
   - Click login
   - Verify network error appears
   - Verify retry button is shown
   - Reconnect network
   - Click retry button
   - Expected: Login succeeds

5. **Verify error state cleanup**
   - After successful login
   - Expected: No error messages remain
   - Expected: No error containers visible
   - Expected: Home screen loads cleanly

### Success Criteria:
- [ ] Can recover from authentication errors
- [ ] Can recover from network errors
- [ ] Can attempt multiple times without issues
- [ ] Form state persists across attempts
- [ ] Error messages clear appropriately
- [ ] Retry functionality works reliably
- [ ] No stuck error states
- [ ] No memory leaks from repeated attempts

---

## Test Case 10: Error Message Accessibility and UX

### Steps:
1. **Trigger different error types** (one at a time):

   a) **Authentication error (401)**
      - Enter invalid credentials
      - Click login
      - Check: Error message is readable
      - Check: Error icon is visible
      - Check: Recovery hint is helpful
      - Check: Error container has good contrast

   b) **Network timeout**
      - Simulate slow network (proxy tool)
      - Click login
      - Check: Timeout message is clear
      - Check: Retry button is prominent
      - Check: Recovery hint mentions timeout

   c) **Network error**
      - Disconnect network
      - Click login
      - Check: Connection error message
      - Check: Retry button is present
      - Check: Suggests checking network

2. **Evaluate UX aspects:**
   - Error messages are in user's language (Chinese)
   - Error icons are recognizable
   - Recovery hints are actionable
   - Retry buttons are easy to find (for network errors)
   - Form fields are easy to edit after error
   - No excessive jargon in error messages

3. **Test error dismissal:**
   - Errors should clear when:
     - User starts typing in form
     - User clicks retry (network errors)
     - User submits new credentials
   - Verify no stuck error messages

### Success Criteria:
- [ ] Error messages are clear and understandable
- [ ] Error icons are visually distinct
- [ ] Recovery hints provide specific guidance
- [ ] Retry buttons are clearly visible (network errors)
- [ ] Error state doesn't block user actions
- [ ] Can easily recover from any error type
- [ ] Error messages follow accessibility best practices
- [ ] Good color contrast for error containers
- [ ] Appropriate use of emojis/icons for visual clarity

---

## Test Case 11: Error Handling Edge Cases

### Steps:
1. **Rapid error triggering**
   - Click login button multiple times rapidly
   - Expected: Only one authentication attempt
   - Expected: No multiple error messages
   - Expected: No crashes

2. **Error during loading state**
   - Start login (loading appears)
   - Trigger network failure during loading
   - Expected: Loading overlay disappears
   - Expected: Error message appears
   - Expected: No stuck loading state

3. **Form validation + auth error**
   - Leave email empty
   - Enter invalid password
   - Click login
   - Expected: Validation error appears first
   - Expected: No auth API call (validation blocks it)
   - Expected: Clear error messages

4. **Switch login modes with error**
   - Trigger error in credentials mode
   - Switch to token login mode
   - Expected: Error state clears
   - Expected: Token form is clean
   - Expected: No residual error messages

5. **Error then background/foreground**
   - Trigger auth error
   - Minimize app (background)
   - Restore app (foreground)
   - Expected: Error state persists correctly
   - Expected: Form is still accessible
   - Expected: No state corruption

### Success Criteria:
- [ ] No crashes on rapid button clicks
- [ ] Error handling works during loading
- [ ] Validation takes precedence over auth errors
- [ ] Error state clears on mode switch
- [ ] Error state survives app lifecycle events
- [ ] No memory leaks from error states
- [ ] No duplicate error messages
- [ ] Error handling is robust and reliable

---

## Test Case 12: Network Error Simulation (Connection Failure)

### Purpose:
Verify network error handling and retry functionality when network connection fails

### Prerequisites:
- Ability to disable/enable network connection
- Valid NovelAI test credentials

### Steps:
1. **Launch app and navigate to login screen**
   - Run: `flutter run -d windows`
   - Expected: Login screen appears

2. **Disable network connection**
   - Option A: Disable WiFi/Ethernet adapter
   - Option B: Enable airplane mode
   - Option C: Block NovelAI API via firewall
   - Verify: Network is truly disconnected (try opening a website)

3. **Enter valid credentials**
   - Email: `your-test@example.com`
   - Password: `your-valid-password`
   - Expected: Credentials are accepted by form validation

4. **Click login button**
   - Action: Click "登录" (Login) button
   - Expected: Loading overlay appears briefly
   - Expected: After timeout (~30 seconds), loading disappears

5. **Verify network error response**
   - Expected: Red error container appears below form
   - Expected: Error icon (Icons.error_outline) is visible
   - Expected: Error message: "网络连接失败" (Network connection failed)
   - Expected: Recovery hint: "💡 网络连接失败，请检查网络设置"
   - Expected: Retry button is shown (ElevatedButton.icon with Icons.refresh)
   - Expected: Retry button text: "重试"

6. **Verify form state preservation**
   - Expected: Email field still contains entered credentials
   - Expected: Password field still contains entered password
   - Expected: Form is still editable
   - Expected: Can modify fields without re-typing everything

7. **Test retry button (network still disabled)**
   - Action: Click retry button
   - Expected: Loading state appears again
   - Expected: After timeout, same network error appears
   - Expected: Retry button remains visible
   - Expected: Form is still preserved

8. **Re-enable network connection**
   - Action: Re-enable WiFi/Ethernet or disable airplane mode
   - Verify: Network is connected (try opening a website)
   - Wait: 2-3 seconds for network to stabilize

9. **Click retry button with restored network**
   - Action: Click "重试" button
   - Expected: Loading overlay appears
   - Expected: Authentication proceeds
   - Expected: If credentials are valid, login succeeds
   - Expected: Redirect to home screen

10. **Verify successful login**
    - Expected: Home screen is displayed
    - Expected: User is authenticated
    - Expected: No error messages remain
    - Expected: Account info is visible

### Success Criteria:
- [ ] Network error is detected correctly
- [ ] Error message is clear and specific to network failure
- [ ] Retry button appears (unlike auth errors)
- [ ] Form credentials are preserved across error
- [ ] Retry button re-attempts authentication
- [ ] Can retry multiple times if needed
- [ ] Successful retry works after network is restored
- [ ] No crashes or stuck states
- [ ] Error clears automatically on successful login

---

## Test Case 13: Network Timeout Error Handling

### Purpose:
Verify timeout error handling when network is slow or unresponsive

### Prerequisites:
- Ability to simulate network timeout
- Valid NovelAI test credentials

### Steps:
1. **Launch app and navigate to login screen**
   - Run: `flutter run -d windows`
   - Expected: Login screen appears

2. **Simulate network timeout**
   - Option A: Use proxy tool to add 60+ second delay
   - Option B: Throttle bandwidth to extremely slow (1 bytes/sec)
   - Option C: Block API responses while allowing requests

3. **Enter valid credentials**
   - Email: `your-test@example.com`
   - Password: `your-valid-password`
   - Expected: Credentials are accepted

4. **Click login button**
   - Action: Click "登录" button
   - Expected: Loading overlay appears

5. **Wait for timeout**
   - Wait: ~30 seconds (default timeout)
   - Expected: Loading overlay disappears

6. **Verify timeout error response**
   - Expected: Red error container appears
   - Expected: Error message: "网络超时" (Network timeout)
   - Expected: Recovery hint: "💡 请求超时，请检查网络连接后重试"
   - Expected: Retry button with Icons.refresh
   - Expected: Form fields are preserved

7. **Restore normal network**
   - Action: Remove proxy/throttling
   - Verify: Network is responding normally

8. **Click retry button**
   - Action: Click "重试" button
   - Expected: Loading state appears
   - Expected: Authentication completes within reasonable time
   - Expected: Successful login proceeds to home screen

### Success Criteria:
- [ ] Timeout is detected and reported correctly
- [ ] Timeout error message is distinct from connection error
- [ ] Retry button appears
- [ ] Form is preserved
- [ ] Retry works after network is restored
- [ ] No indefinite loading states
- [ ] User can cancel retry by navigating away

---

## Test Case 14: Multiple Network Errors and Recovery

### Purpose:
Verify robustness when multiple network errors occur in sequence

### Prerequisites:
- Ability to toggle network connection
- Valid NovelAI test credentials

### Steps:
1. **Launch app and navigate to login screen**

2. **Enter valid credentials**
   - Email: `your-test@example.com`
   - Password: `your-valid-password`

3. **First network error attempt**
   - Disable network
   - Click login
   - Verify: Network error appears with retry button
   - Verify: Credentials are preserved

4. **Second network error attempt (retry while network still down)**
   - Click retry button
   - Verify: Loading appears briefly
   - Verify: Network error appears again
   - Verify: Retry button still visible
   - Verify: No duplicate error messages
   - Verify: No memory leaks or performance degradation

5. **Third attempt (manual retry via login button)**
   - Instead of clicking retry button
   - Click main login button
   - Verify: Works same as retry button
   - Verify: Error updates correctly
   - Verify: Form remains accessible

6. **Fourth attempt (successful recovery)**
   - Re-enable network connection
   - Click retry button
   - Verify: Login succeeds
   - Verify: Redirect to home screen
   - Verify: No residual error messages
   - Verify: Clean state transition

7. **Verify state cleanup**
   - Check: No error containers visible
   - Check: Home screen renders correctly
   - Check: User is authenticated
   - Check: Account info is accurate

### Success Criteria:
- [ ] Can handle multiple network errors without crashing
- [ ] Each retry attempt works correctly
- [ ] No duplicate or stuck error messages
- [ ] Form state persists across all attempts
- [ ] Both retry button and login button work
- [ ] Successful recovery works after multiple failures
- [ ] No memory leaks or performance issues
- [ ] State is clean after successful login

---

## Test Case 15: Network Error During Auto-Login

### Purpose:
Verify network error handling during app startup with saved credentials

### Prerequisites:
- Previously logged in account (saved credentials)
- Ability to disable network
- NovelAI test account

### Setup:
1. **Ensure saved credentials exist**
   - Login successfully with valid credentials
   - Verify account is saved
   - Close app

2. **Disable network connection**
   - Disconnect WiFi/Ethernet
   - Or enable airplane mode

### Steps:
1. **Launch app with no network**
   - Run: `flutter run -d windows`
   - Expected: Splash screen appears

2. **Wait for auto-login attempt**
   - Wait: ~5-10 seconds (timeout period)
   - Expected: Splash screen disappears

3. **Verify error handling**
   - Expected: Redirected to login screen
   - Expected: Error state is handled gracefully
   - Expected: No indefinite loading
   - Expected: User can manually login

4. **Re-enable network**
   - Restore network connection

5. **Login manually**
   - Enter credentials
   - Click login
   - Expected: Successful login
   - Expected: Auto-login will work next time

### Success Criteria:
- [ ] Auto-login failure is handled gracefully
- [ ] No infinite loading on splash screen
- [ ] User can fall back to manual login
- [ ] Network is restored, login works
- [ ] No crashes or stuck states
- [ ] Error messages are appropriate

---

## Test Case 16: Network Error Recovery Flow (Complete End-to-End)

### Purpose:
Verify complete network error recovery flow from failure to success

### Prerequisites:
- Ability to control network connection
- Valid NovelAI credentials

### Steps:
1. **Launch app and navigate to login**

2. **Initial state: Network connected**
   - Verify: App loads normally
   - Verify: Login screen appears

3. **Enter credentials and trigger network error**
   - Enter: `valid@example.com` / `validpassword`
   - Disable network
   - Click login
   - Verify: Network error message appears
   - Verify: Retry button is shown
   - Screenshot: Error state with retry button

4. **Verify error state details**
   - Check: Error icon is visible
   - Check: Error message is clear
   - Check: Recovery hint is actionable
   - Check: Retry button is prominent
   - Check: Form fields show entered values

5. **Attempt retry with network still down**
   - Click retry button
   - Verify: Loading state appears
   - Verify: Error reappears after timeout
   - Verify: Retry button remains

6. **Modify credentials while in error state**
   - Edit email field
   - Edit password field
   - Verify: Changes are accepted
   - Verify: Error message persists (doesn't clear on edit)
   - Verify: Can still retry

7. **Restore network and retry**
   - Re-enable network
   - Wait: 2-3 seconds
   - Click retry button
   - Verify: Loading state appears
   - Verify: Authentication proceeds

8. **Verify successful login**
   - Expected: Redirect to home screen
   - Expected: User is authenticated
   - Expected: No error messages remain
   - Screenshot: Successful home screen

9. **Verify persistence**
   - Close app
   - Relaunch app
   - Expected: Auto-login works (network is connected)
   - Expected: No errors

### Success Criteria:
- [ ] Complete error recovery flow works
- [ ] Error state is informative and actionable
- [ ] Retry functionality is reliable
- [ ] Can modify credentials during error state
- [ ] Successful recovery leads to clean state
- [ ] Persistence works after recovery
- [ ] No residual errors or UI artifacts
- [ ] User experience is smooth despite errors

---

## Network Error Testing Tools and Techniques

### How to Simulate Network Errors:

#### 1. **Disable Network Adapter (Windows)**
   ```powershell
   # Disable WiFi
   netsh interface set interface "Wi-Fi" admin=disable

   # Re-enable WiFi
   netsh interface set interface "Wi-Fi" admin=enable
   ```

#### 2. **Use Proxy Tool (Fiddler/Charles)**
   - Configure proxy to intercept NovelAI API requests
   - Add rules to:
     - Block specific endpoints (503 error)
     - Add delays (timeout simulation)
     - Return malformed responses

#### 3. **Windows Firewall**
   - Block outbound connections to `api.novelai.app`
   - Temporary rule for testing only

#### 4. **Network Throttling**
   - Use Chrome DevTools (if testing web version)
   - Set to "Offline" or "Slow 3G"

#### 5. **Hosts File Modification**
   ```
   # Add to C:\Windows\System32\drivers\etc\hosts
   127.0.0.1 api.novelai.app
   ```
   Remember to remove after testing!

### Testing Best Practices:

1. **Always restore network after testing**
   - Don't leave system in disconnected state
   - Verify network is working before moving on

2. **Test both timeout and connection errors**
   - Timeout: Network is connected but slow
   - Connection error: Network is completely unavailable

3. **Test with valid and invalid credentials**
   - Network errors should show retry button
   - Auth errors should NOT show retry button

4. **Document actual timeout duration**
   - Measure how long timeout takes
   - Verify it's reasonable (not too long, not too short)

5. **Screenshot key states**
   - Network error with retry button
   - Timeout error
   - Successful recovery

6. **Test edge cases**
   - Rapid retry clicks
   - Network restored during timeout
   - Network fails during retry
   - Switch login modes during error state

---

## Known Issues / Limitations

### Testing Constraints:
1. **No actual NovelAI credentials available in test environment**
   - Solution: Mock tests or use test account
   - Current: Integration test created but cannot run without valid API

2. **Cannot manually interact with GUI in CI environment**
   - Solution: Integration test uses widget tester
   - Current: Manual test checklist provided for human testers

3. **Network dependency**
   - Tests require active internet connection
   - NovelAI API must be accessible

### Automation Challenges:
1. **Simulating network failures in automated tests**
   - Requires mocking DioException at low level
   - Complex to simulate all network error types
   - Manual testing recommended for full coverage

2. **Testing retry functionality end-to-end**
   - Requires stateful network simulation
   - Mock network going down, then up
   - Difficult to automate reliably

---

## Conclusion

**Status**: ✅ Implementation complete, ready for manual testing

**What was implemented:**
1. Complete login flow with email/password credentials
2. Loading states with overlay
3. Error handling with actionable messages
4. Auto-login with credential persistence
5. Smooth navigation transitions
6. Form validation
7. Password visibility toggle
8. Retry buttons for network errors
9. Error recovery hints
10. Form state preservation

**Testing Status:**
- Code review: ✅ All components implemented correctly
- Integration test: ✅ Created (requires mocking/credentials to run)
- Manual testing: ⏳ Ready for human tester with valid NovelAI account

**Next Steps:**
1. Human tester should run through manual test checklist
2. Document any issues found
3. Create automated mocks for CI/CD testing
4. Add screenshots/video of successful flow
