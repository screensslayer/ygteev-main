# Supabase Authentication Setup

This guide will help you integrate Supabase authentication into your YGTeeV app.

## Step 1: Install Supabase Swift SDK

1. Open `YGTeeV.xcodeproj` in Xcode
2. Go to **File → Add Package Dependencies**
3. Enter the Supabase Swift package URL: `https://github.com/supabase/supabase-swift`
4. Click **Add Package**
5. Select **Supabase** from the package products list
6. Click **Add Package**

## Step 2: Configure Supabase Credentials

1. Go to your Supabase project dashboard at https://supabase.com
2. Navigate to **Settings → API**
3. Copy your **Project URL** and **anon/public key**
4. Open `YGTeeV/Services/SupabaseManager.swift`
5. Replace the placeholder values:

```swift
let supabaseURL = URL(string: "YOUR_SUPABASE_URL")!
let supabaseKey = "YOUR_SUPABASE_ANON_KEY"
```

## Step 3: Create Database Table

Run this SQL in your Supabase SQL Editor:

```sql
-- Create users table
CREATE TABLE IF NOT EXISTS public.users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    display_name TEXT,
    handle TEXT UNIQUE,
    role TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('member', 'parent', 'leader', 'pastor')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Users can view their own profile"
    ON public.users
    FOR SELECT
    USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile"
    ON public.users
    FOR UPDATE
    USING (auth.uid() = id);

CREATE POLICY "Pastors can view all users"
    ON public.users
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.users
            WHERE id = auth.uid() AND role = 'pastor'
        )
    );

CREATE POLICY "Pastors can update user roles"
    ON public.users
    FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.users
            WHERE id = auth.uid() AND role = 'pastor'
        )
    );

-- Create function to automatically create user profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.users (id, email, role, created_at, updated_at)
    VALUES (NEW.id, NEW.email, 'member', NOW(), NOW());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger
CREATE OR REPLACE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();

-- Create index for faster lookups
CREATE INDEX idx_users_handle ON public.users(handle);
CREATE INDEX idx_users_role ON public.users(role);
```

## Step 4: Configure Authentication Providers

### Email/Password Authentication
Email/password auth is enabled by default in Supabase.

### Google OAuth (Optional)

1. Go to **Authentication → Providers** in Supabase dashboard
2. Enable **Google** provider
3. Follow Supabase's guide to set up Google OAuth:
   - Create a project in Google Cloud Console
   - Configure OAuth consent screen
   - Create OAuth 2.0 credentials
   - Add authorized redirect URI from Supabase
   - Copy Client ID and Client Secret to Supabase

### Apple Sign In (Optional)

1. Go to **Authentication → Providers** in Supabase dashboard
2. Enable **Apple** provider
3. Follow Supabase's guide to set up Apple Sign In:
   - Register your App ID in Apple Developer
   - Enable Sign in with Apple capability
   - Configure Services ID
   - Add authorized redirect URI from Supabase
   - Copy credentials to Supabase

## Step 5: Test Authentication

1. Build and run the app
2. Go through onboarding to the account creation screen
3. Try creating an account with email/password
4. Check Supabase dashboard **Authentication → Users** to verify user was created
5. Check **Table Editor → users** to verify profile was created with role = 'member'

## User Roles

The app supports 4 user roles:

- **member**: Default role for all new users
- **parent**: For parents managing their children's accounts
- **leader**: For small group leaders
- **pastor**: For pastors with admin privileges

To change a user's role, update it directly in the Supabase dashboard or use the `updateUserRole` method (requires pastor role):

```swift
try await SupabaseManager.shared.updateUserRole(userId: "user-id", role: .pastor)
```

## Security Notes

1. **Never commit** your Supabase URL and anon key to version control if your repo is public
2. Consider using environment variables or a config file in `.gitignore`
3. Row Level Security (RLS) is enabled to ensure users can only access their own data
4. Pastors have elevated permissions to manage other users

## Troubleshooting

### "No session found" error
- Check that your Supabase credentials are correct
- Verify the user exists in Supabase dashboard

### OAuth not working
- Verify redirect URIs are configured correctly in both Supabase and the OAuth provider
- Check that the provider is enabled in Supabase dashboard

### User profile not created
- Check that the trigger is enabled in Supabase
- Verify the `handle_new_user()` function exists
- Look for errors in Supabase logs

## Current Implementation Status

✅ Email/password authentication
✅ User profile creation with default 'member' role
✅ Sign in functionality
✅ Sign out functionality
✅ Authentication state management
✅ Protected app access (must be authenticated to use app)
⏳ Google OAuth (requires additional setup)
⏳ Apple Sign In (requires additional setup)
⏳ Profile updates (display name, handle)
⏳ Role management UI

## Next Steps

1. Set up email templates in Supabase for:
   - Email verification
   - Password reset
   - Magic link sign in

2. Add profile editing functionality
3. Implement role-based UI changes
4. Add parent-child account linking
5. Implement group membership in database
