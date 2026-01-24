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

**Testing Status:**
- Code review: ✅ All components implemented correctly
- Integration test: ✅ Created (requires mocking/credentials to run)
- Manual testing: ⏳ Ready for human tester with valid NovelAI account

**Next Steps:**
1. Human tester should run through manual test checklist
2. Document any issues found
3. Create automated mocks for CI/CD testing
4. Add screenshots/video of successful flow
