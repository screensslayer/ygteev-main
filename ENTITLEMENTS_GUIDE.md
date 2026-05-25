# Entitlements & Heartbeat System

## Overview

The YGTeeV app uses a server-side entitlements system powered by Supabase. **All entitlement decisions happen on the server** — the client never computes whether a user is Pro, Pastor, etc.

## Key Concepts

### 1. Server-Side Entitlements

Two Supabase RPC functions provide the core functionality:

- **`heartbeat()`**: Updates `profiles.last_opened_at = now()` for the authenticated user
- **`get_my_entitlements()`**: Returns current user's entitlements based on:
  - Active Apple subscription
  - Youth group membership (active = opened app within 90 days)
  - Role assignments (pastor, parent, etc.)

### 2. Why Heartbeat Matters

**Pro status for youth group members requires activity.** The server logic:
```sql
-- A user is Pro if they:
--   1. Have an active Apple subscription, OR
--   2. Are an active member of a non-default youth group
--
-- "Active member" = last_opened_at within 90 days
```

**If you forget to call `heartbeat()`, youth group members will lose Pro after 90 days of inactivity.**

### 3. Entitlements Schema

```swift
struct Entitlements {
    var isPro: Bool              // Active subscription OR active youth group member
    var isSiteAdmin: Bool         // Full admin access
    var isPastor: Bool            // Youth group leader
    var isParent: Bool            // Parent managing kids
    var canCreateEvents: Bool     // Can create events
    var canCreatePlans: Bool      // Can create Bible plans
    var canRunYouthGroup: Bool    // Can manage youth groups
}
```

## Implementation

### EntitlementsService

`EntitlementsService.swift` is an `@Observable` singleton that:
- Fetches entitlements via `get_my_entitlements()` RPC
- Sends heartbeats via `heartbeat()` RPC (debounced to 5-minute intervals)
- Exposes `@Published var entitlements: Entitlements`
- Automatically resets on sign-out

### Lifecycle Integration

Entitlements are refreshed in the following scenarios:

1. **Cold start with existing session**
   - `SupabaseManager.checkSession()` → heartbeat → refresh

2. **After sign-in/sign-up**
   - `SupabaseManager.signIn()` → heartbeat → refresh
   - `SupabaseManager.signUp()` → heartbeat → refresh

3. **App becomes active (foreground)**
   - `RootView.onChange(of: scenePhase)` → heartbeat → refresh
   - Debounced: heartbeat only fires once every 5 minutes

4. **After subscription changes**
   - Call `EntitlementsService.shared.refreshAfterSubscriptionChange()`

5. **After youth group changes**
   - Call `EntitlementsService.shared.refreshAfterYouthGroupChange()`

6. **On sign-out**
   - Entitlements reset to all-false

### Heartbeat Debouncing

To prevent hammering the server:
- Heartbeats are debounced to **once per 5 minutes**
- Rapid app foreground/background cycles won't trigger multiple heartbeats
- Use `forceHeartbeat()` only for testing

## Usage Examples

### Example 1: Gate Pro Feature

```swift
struct SomeView: View {
    @Environment(EntitlementsService.self) private var entitlementsService

    var body: some View {
        if entitlementsService.entitlements.isPro {
            ProFeatureView()
        } else {
            UpgradePromptView()
        }
    }
}
```

### Example 2: Show Pastor-Only UI

```swift
struct GroupManagementView: View {
    @Environment(EntitlementsService.self) private var entitlementsService

    var body: some View {
        if entitlementsService.entitlements.isPastor {
            NavigationLink("Manage Youth Group") {
                PastorDashboard()
            }
        }
    }
}
```

### Example 3: Refresh After Joining a Group

```swift
func joinYouthGroup(groupId: String) async throws {
    // Join the group via API
    try await api.joinGroup(groupId)

    // Immediately refresh entitlements (Pro status may have changed)
    await EntitlementsService.shared.refreshAfterYouthGroupChange()
}
```

### Example 4: Refresh After Subscription Purchase

```swift
func handlePurchaseSuccess(transaction: Transaction) async {
    // Process the transaction
    await processTransaction(transaction)

    // Immediately refresh entitlements
    await EntitlementsService.shared.refreshAfterSubscriptionChange()
}
```

## Critical Rules

### ❌ DO NOT

1. **Never cache `isPro` to UserDefaults/Keychain**
   - Subscriptions expire
   - Group memberships change
   - Always trust the latest server response

2. **Never compute entitlements client-side**
   ```swift
   // ❌ BAD
   let isPro = hasActiveSubscription || isInYouthGroup

   // ✅ GOOD
   let isPro = entitlementsService.entitlements.isPro
   ```

3. **Never read `profiles.is_pro` from the database**
   - This column has been **removed**
   - Any code referencing it will fail
   - Use `get_my_entitlements()` instead

4. **Never skip heartbeat calls**
   - Youth group members lose Pro after 90 days without heartbeat
   - Always call heartbeat on app launch and foreground

### ✅ DO

1. **Always use `entitlementsService.entitlements` to gate features**
   ```swift
   @Environment(EntitlementsService.self) private var entitlementsService

   if entitlementsService.entitlements.isPro {
       // Show Pro feature
   }
   ```

2. **Call refresh after subscription or group changes**
   ```swift
   await EntitlementsService.shared.refreshAfterSubscriptionChange()
   await EntitlementsService.shared.refreshAfterYouthGroupChange()
   ```

3. **Trust the server**
   - Entitlements can change at any time
   - Don't cache or compute them locally
   - The server is the single source of truth

## Testing

### Check Current Entitlements

1. Use the example view: `EntitlementsExampleView`
2. Check console logs for refresh confirmations:
   ```
   ✅ Entitlements refreshed: isPro=true, isPastor=false
   ```

### Test Heartbeat Debouncing

1. Open the app
2. Background it immediately
3. Foreground it again within 5 minutes
4. Check console: you should see "Heartbeat skipped"

### Test Pro Status

**As a youth group member:**
1. Join a non-default youth group
2. Open the app → heartbeat fires → check `isPro` (should be true)
3. Wait 91 days without opening the app
4. Open the app → `isPro` should be false (inactive member)

**As a subscriber:**
1. Complete Apple subscription purchase
2. Call `refreshAfterSubscriptionChange()`
3. Check `isPro` (should be true regardless of youth group)

## Troubleshooting

### "User has isPro=false but they have an active subscription"
- Subscription validation may not have completed server-side
- Call `refreshAfterSubscriptionChange()` after purchase
- Check Supabase logs for validation errors

### "Youth group member lost Pro status"
- Check `profiles.last_opened_at` in database
- Ensure heartbeat is firing on app launch/foreground
- Heartbeat must run within 90 days to maintain Pro

### "Entitlements not updating"
- Check authentication state (`SupabaseManager.shared.isAuthenticated`)
- Look for errors in console logs
- Verify `get_my_entitlements` RPC exists in Supabase

## Server Setup (Reference)

The two RPCs must exist in your Supabase project:

```sql
-- heartbeat() - updates last_opened_at
CREATE OR REPLACE FUNCTION public.heartbeat()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.profiles
  SET last_opened_at = now()
  WHERE id = auth.uid();
END;
$$;

-- get_my_entitlements() - returns current user's entitlements
-- (Implementation details depend on your schema and business logic)
CREATE OR REPLACE FUNCTION public.get_my_entitlements()
RETURNS TABLE (
  is_pro boolean,
  is_site_admin boolean,
  is_pastor boolean,
  is_parent boolean,
  can_create_events boolean,
  can_create_plans boolean,
  can_run_youth_group boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
-- Your implementation here
$$;
```

## Migration Notes

If you previously stored `is_pro` in `UserDefaults` or read from `profiles.is_pro`:

1. **Remove all local caching of Pro status**
2. **Remove all database reads of `profiles.is_pro`**
3. **Replace with**: `@Environment(EntitlementsService.self)` and `entitlementsService.entitlements.isPro`

## Future: Subscription Validation

The subscription validation flow (coming soon):
1. User completes StoreKit purchase
2. Client sends receipt to server validation endpoint
3. Server validates with Apple, updates subscription status
4. Client calls `refreshAfterSubscriptionChange()`
5. Entitlements reflect new Pro status

Until then, ensure your server's `get_my_entitlements()` correctly identifies Pro users based on current subscription state.
