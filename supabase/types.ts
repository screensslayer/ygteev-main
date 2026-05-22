export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.5"
  }
  public: {
    Tables: {
      _internal_secrets: {
        Row: {
          key: string
          updated_at: string
          value: string
        }
        Insert: {
          key: string
          updated_at?: string
          value: string
        }
        Update: {
          key?: string
          updated_at?: string
          value?: string
        }
        Relationships: []
      }
      apple_subscriptions: {
        Row: {
          created_at: string
          expires_at: string | null
          id: string
          original_transaction_id: string
          product_id: string
          raw_payload: Json | null
          status: string
          updated_at: string
          user_id: string
        }
        Insert: {
          created_at?: string
          expires_at?: string | null
          id?: string
          original_transaction_id: string
          product_id: string
          raw_payload?: Json | null
          status: string
          updated_at?: string
          user_id: string
        }
        Update: {
          created_at?: string
          expires_at?: string | null
          id?: string
          original_transaction_id?: string
          product_id?: string
          raw_payload?: Json | null
          status?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      attendance_events: {
        Row: {
          created_at: string
          created_by: string | null
          id: string
          notes: string | null
          occurred_at: string
          small_group_id: string
          title: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          id?: string
          notes?: string | null
          occurred_at?: string
          small_group_id: string
          title: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          created_by?: string | null
          id?: string
          notes?: string | null
          occurred_at?: string
          small_group_id?: string
          title?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "attendance_events_small_group_id_fkey"
            columns: ["small_group_id"]
            isOneToOne: false
            referencedRelation: "small_groups"
            referencedColumns: ["id"]
          },
        ]
      }
      attendance_records: {
        Row: {
          created_at: string
          event_id: string
          id: string
          notes: string | null
          present: boolean
          updated_at: string
          user_id: string
        }
        Insert: {
          created_at?: string
          event_id: string
          id?: string
          notes?: string | null
          present: boolean
          updated_at?: string
          user_id: string
        }
        Update: {
          created_at?: string
          event_id?: string
          id?: string
          notes?: string | null
          present?: boolean
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "attendance_records_event_id_fkey"
            columns: ["event_id"]
            isOneToOne: false
            referencedRelation: "attendance_event_summary"
            referencedColumns: ["event_id"]
          },
          {
            foreignKeyName: "attendance_records_event_id_fkey"
            columns: ["event_id"]
            isOneToOne: false
            referencedRelation: "attendance_events"
            referencedColumns: ["id"]
          },
        ]
      }
      bible_plan_completions: {
        Row: {
          completed_at: string
          id: string
          plan_id: string
          user_id: string
        }
        Insert: {
          completed_at?: string
          id?: string
          plan_id: string
          user_id: string
        }
        Update: {
          completed_at?: string
          id?: string
          plan_id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "bible_plan_completions_plan_id_fkey"
            columns: ["plan_id"]
            isOneToOne: false
            referencedRelation: "bible_plans"
            referencedColumns: ["id"]
          },
        ]
      }
      bible_plan_day_progress: {
        Row: {
          completed_at: string
          day_id: string
          id: string
          plan_id: string
          step_water_earned: number
          step_xp_earned: number
          user_id: string
        }
        Insert: {
          completed_at?: string
          day_id: string
          id?: string
          plan_id: string
          step_water_earned?: number
          step_xp_earned?: number
          user_id: string
        }
        Update: {
          completed_at?: string
          day_id?: string
          id?: string
          plan_id?: string
          step_water_earned?: number
          step_xp_earned?: number
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "bible_plan_day_progress_day_id_fkey"
            columns: ["day_id"]
            isOneToOne: false
            referencedRelation: "bible_plan_days"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bible_plan_day_progress_plan_id_fkey"
            columns: ["plan_id"]
            isOneToOne: false
            referencedRelation: "bible_plans"
            referencedColumns: ["id"]
          },
        ]
      }
      bible_plan_days: {
        Row: {
          created_at: string
          day_number: number
          id: string
          plan_id: string
          reflection: string | null
          scripture_reference: string
          sections: Json
          title: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          day_number: number
          id?: string
          plan_id: string
          reflection?: string | null
          scripture_reference: string
          sections?: Json
          title: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          day_number?: number
          id?: string
          plan_id?: string
          reflection?: string | null
          scripture_reference?: string
          sections?: Json
          title?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "bible_plan_days_plan_id_fkey"
            columns: ["plan_id"]
            isOneToOne: false
            referencedRelation: "bible_plans"
            referencedColumns: ["id"]
          },
        ]
      }
      bible_plan_step_progress: {
        Row: {
          completed_at: string
          day_id: string
          id: string
          payload: Json
          plan_id: string
          step: Database["public"]["Enums"]["bible_plan_step"]
          user_id: string
          water_earned: number
          xp_earned: number
        }
        Insert: {
          completed_at?: string
          day_id: string
          id?: string
          payload?: Json
          plan_id: string
          step: Database["public"]["Enums"]["bible_plan_step"]
          user_id: string
          water_earned?: number
          xp_earned?: number
        }
        Update: {
          completed_at?: string
          day_id?: string
          id?: string
          payload?: Json
          plan_id?: string
          step?: Database["public"]["Enums"]["bible_plan_step"]
          user_id?: string
          water_earned?: number
          xp_earned?: number
        }
        Relationships: [
          {
            foreignKeyName: "bible_plan_step_progress_day_id_fkey"
            columns: ["day_id"]
            isOneToOne: false
            referencedRelation: "bible_plan_days"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bible_plan_step_progress_plan_id_fkey"
            columns: ["plan_id"]
            isOneToOne: false
            referencedRelation: "bible_plans"
            referencedColumns: ["id"]
          },
        ]
      }
      bible_plans: {
        Row: {
          additional_group_ids: string[]
          category: Database["public"]["Enums"]["bible_plan_category"]
          created_at: string
          created_by: string | null
          days_total: number
          description: string | null
          gradient_from: string
          gradient_index: number
          gradient_to: string
          group_id: string | null
          header_image_url: string | null
          header_kind: string
          id: string
          is_free_entry: boolean
          published_at: string | null
          recommended_order: number | null
          scope: Database["public"]["Enums"]["bible_plan_scope"]
          slug: string
          status: Database["public"]["Enums"]["bible_plan_status"]
          title: string
          updated_at: string
          visibility: Database["public"]["Enums"]["bible_plan_visibility"]
          water_reward: number
          xp_reward: number
        }
        Insert: {
          additional_group_ids?: string[]
          category: Database["public"]["Enums"]["bible_plan_category"]
          created_at?: string
          created_by?: string | null
          days_total: number
          description?: string | null
          gradient_from?: string
          gradient_index?: number
          gradient_to?: string
          group_id?: string | null
          header_image_url?: string | null
          header_kind?: string
          id?: string
          is_free_entry?: boolean
          published_at?: string | null
          recommended_order?: number | null
          scope?: Database["public"]["Enums"]["bible_plan_scope"]
          slug: string
          status?: Database["public"]["Enums"]["bible_plan_status"]
          title: string
          updated_at?: string
          visibility?: Database["public"]["Enums"]["bible_plan_visibility"]
          water_reward?: number
          xp_reward?: number
        }
        Update: {
          additional_group_ids?: string[]
          category?: Database["public"]["Enums"]["bible_plan_category"]
          created_at?: string
          created_by?: string | null
          days_total?: number
          description?: string | null
          gradient_from?: string
          gradient_index?: number
          gradient_to?: string
          group_id?: string | null
          header_image_url?: string | null
          header_kind?: string
          id?: string
          is_free_entry?: boolean
          published_at?: string | null
          recommended_order?: number | null
          scope?: Database["public"]["Enums"]["bible_plan_scope"]
          slug?: string
          status?: Database["public"]["Enums"]["bible_plan_status"]
          title?: string
          updated_at?: string
          visibility?: Database["public"]["Enums"]["bible_plan_visibility"]
          water_reward?: number
          xp_reward?: number
        }
        Relationships: [
          {
            foreignKeyName: "bible_plans_group_id_fkey"
            columns: ["group_id"]
            isOneToOne: false
            referencedRelation: "youth_groups"
            referencedColumns: ["id"]
          },
        ]
      }
      chat_threads: {
        Row: {
          created_at: string
          dm_user_a: string | null
          dm_user_b: string | null
          group_id: string
          id: string
          kind: Database["public"]["Enums"]["thread_kind"]
          last_message_at: string | null
          moderation_policy: Database["public"]["Enums"]["thread_moderation_policy"]
          small_group_id: string | null
        }
        Insert: {
          created_at?: string
          dm_user_a?: string | null
          dm_user_b?: string | null
          group_id: string
          id?: string
          kind: Database["public"]["Enums"]["thread_kind"]
          last_message_at?: string | null
          moderation_policy?: Database["public"]["Enums"]["thread_moderation_policy"]
          small_group_id?: string | null
        }
        Update: {
          created_at?: string
          dm_user_a?: string | null
          dm_user_b?: string | null
          group_id?: string
          id?: string
          kind?: Database["public"]["Enums"]["thread_kind"]
          last_message_at?: string | null
          moderation_policy?: Database["public"]["Enums"]["thread_moderation_policy"]
          small_group_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "chat_threads_group_id_fkey"
            columns: ["group_id"]
            isOneToOne: false
            referencedRelation: "youth_groups"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "chat_threads_small_group_id_fkey"
            columns: ["small_group_id"]
            isOneToOne: false
            referencedRelation: "small_groups"
            referencedColumns: ["id"]
          },
        ]
      }
      child_pairing_tokens: {
        Row: {
          child_user_id: string
          created_at: string
          created_by: string
          expires_at: string
          id: string
          numeric_code: string
          redeemed_at: string | null
          redeemed_from_user_agent: string | null
          token: string
        }
        Insert: {
          child_user_id: string
          created_at?: string
          created_by: string
          expires_at?: string
          id?: string
          numeric_code: string
          redeemed_at?: string | null
          redeemed_from_user_agent?: string | null
          token: string
        }
        Update: {
          child_user_id?: string
          created_at?: string
          created_by?: string
          expires_at?: string
          id?: string
          numeric_code?: string
          redeemed_at?: string | null
          redeemed_from_user_agent?: string | null
          token?: string
        }
        Relationships: [
          {
            foreignKeyName: "child_pairing_tokens_child_user_id_fkey"
            columns: ["child_user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "child_pairing_tokens_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      event_external_rsvps: {
        Row: {
          converted_at: string | null
          converted_to_user_id: string | null
          created_at: string
          display_name: string | null
          email: string
          event_id: string
          grade_year: number | null
          id: string
          inviter_user_id: string | null
          source: string
          status: string
          updated_at: string
        }
        Insert: {
          converted_at?: string | null
          converted_to_user_id?: string | null
          created_at?: string
          display_name?: string | null
          email: string
          event_id: string
          grade_year?: number | null
          id?: string
          inviter_user_id?: string | null
          source?: string
          status?: string
          updated_at?: string
        }
        Update: {
          converted_at?: string | null
          converted_to_user_id?: string | null
          created_at?: string
          display_name?: string | null
          email?: string
          event_id?: string
          grade_year?: number | null
          id?: string
          inviter_user_id?: string | null
          source?: string
          status?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "event_external_rsvps_converted_to_user_id_fkey"
            columns: ["converted_to_user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "event_external_rsvps_event_id_fkey"
            columns: ["event_id"]
            isOneToOne: false
            referencedRelation: "events"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "event_external_rsvps_inviter_user_id_fkey"
            columns: ["inviter_user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      event_media: {
        Row: {
          caption: string | null
          created_at: string
          event_id: string
          id: string
          kind: Database["public"]["Enums"]["event_media_kind"]
          storage_path: string | null
          uploaded_by: string | null
          video_id: string | null
        }
        Insert: {
          caption?: string | null
          created_at?: string
          event_id: string
          id?: string
          kind: Database["public"]["Enums"]["event_media_kind"]
          storage_path?: string | null
          uploaded_by?: string | null
          video_id?: string | null
        }
        Update: {
          caption?: string | null
          created_at?: string
          event_id?: string
          id?: string
          kind?: Database["public"]["Enums"]["event_media_kind"]
          storage_path?: string | null
          uploaded_by?: string | null
          video_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "event_media_event_id_fkey"
            columns: ["event_id"]
            isOneToOne: false
            referencedRelation: "events"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "event_media_video_id_fkey"
            columns: ["video_id"]
            isOneToOne: false
            referencedRelation: "videos"
            referencedColumns: ["id"]
          },
        ]
      }
      event_rsvps: {
        Row: {
          created_at: string
          event_id: string
          id: string
          status: Database["public"]["Enums"]["rsvp_status"]
          user_id: string
        }
        Insert: {
          created_at?: string
          event_id: string
          id?: string
          status?: Database["public"]["Enums"]["rsvp_status"]
          user_id: string
        }
        Update: {
          created_at?: string
          event_id?: string
          id?: string
          status?: Database["public"]["Enums"]["rsvp_status"]
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "event_rsvps_event_id_fkey"
            columns: ["event_id"]
            isOneToOne: false
            referencedRelation: "events"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "event_rsvps_user_profiles_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      events: {
        Row: {
          capacity: number | null
          cover_url: string | null
          created_at: string
          created_by: string | null
          description: string | null
          group_id: string
          id: string
          latitude: number | null
          location: string
          longitude: number | null
          rsvp_audience: Database["public"]["Enums"]["event_rsvp_audience"]
          starts_at: string
          title: string
          visibility: Database["public"]["Enums"]["event_visibility"]
        }
        Insert: {
          capacity?: number | null
          cover_url?: string | null
          created_at?: string
          created_by?: string | null
          description?: string | null
          group_id: string
          id?: string
          latitude?: number | null
          location: string
          longitude?: number | null
          rsvp_audience?: Database["public"]["Enums"]["event_rsvp_audience"]
          starts_at: string
          title: string
          visibility?: Database["public"]["Enums"]["event_visibility"]
        }
        Update: {
          capacity?: number | null
          cover_url?: string | null
          created_at?: string
          created_by?: string | null
          description?: string | null
          group_id?: string
          id?: string
          latitude?: number | null
          location?: string
          longitude?: number | null
          rsvp_audience?: Database["public"]["Enums"]["event_rsvp_audience"]
          starts_at?: string
          title?: string
          visibility?: Database["public"]["Enums"]["event_visibility"]
        }
        Relationships: [
          {
            foreignKeyName: "events_group_id_fkey"
            columns: ["group_id"]
            isOneToOne: false
            referencedRelation: "youth_groups"
            referencedColumns: ["id"]
          },
        ]
      }
      families: {
        Row: {
          created_at: string
          created_by: string
          deleted_at: string | null
          id: string
          name: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          created_by: string
          deleted_at?: string | null
          id?: string
          name?: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          created_by?: string
          deleted_at?: string | null
          id?: string
          name?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "families_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      family_invites: {
        Row: {
          accepted_at: string | null
          accepted_by: string | null
          created_at: string
          created_by: string
          expires_at: string
          family_id: string
          id: string
          invited_email: string | null
          invited_user_id: string | null
          pairing_code: string
          status: string
        }
        Insert: {
          accepted_at?: string | null
          accepted_by?: string | null
          created_at?: string
          created_by: string
          expires_at?: string
          family_id: string
          id?: string
          invited_email?: string | null
          invited_user_id?: string | null
          pairing_code: string
          status?: string
        }
        Update: {
          accepted_at?: string | null
          accepted_by?: string | null
          created_at?: string
          created_by?: string
          expires_at?: string
          family_id?: string
          id?: string
          invited_email?: string | null
          invited_user_id?: string | null
          pairing_code?: string
          status?: string
        }
        Relationships: [
          {
            foreignKeyName: "family_invites_accepted_by_fkey"
            columns: ["accepted_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "family_invites_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "family_invites_family_id_fkey"
            columns: ["family_id"]
            isOneToOne: false
            referencedRelation: "families"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "family_invites_invited_user_id_fkey"
            columns: ["invited_user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      family_members: {
        Row: {
          family_id: string
          id: string
          joined_at: string
          role: string
          user_id: string
        }
        Insert: {
          family_id: string
          id?: string
          joined_at?: string
          role: string
          user_id: string
        }
        Update: {
          family_id?: string
          id?: string
          joined_at?: string
          role?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "family_members_family_id_fkey"
            columns: ["family_id"]
            isOneToOne: false
            referencedRelation: "families"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "family_members_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      feed_post_engagement: {
        Row: {
          first_viewed_at: string | null
          id: string
          liked_at: string | null
          post_id: string
          user_id: string
          watch_completed_at: string | null
        }
        Insert: {
          first_viewed_at?: string | null
          id?: string
          liked_at?: string | null
          post_id: string
          user_id: string
          watch_completed_at?: string | null
        }
        Update: {
          first_viewed_at?: string | null
          id?: string
          liked_at?: string | null
          post_id?: string
          user_id?: string
          watch_completed_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "feed_post_engagement_post_id_fkey"
            columns: ["post_id"]
            isOneToOne: false
            referencedRelation: "feed_posts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "feed_post_engagement_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      feed_post_photos: {
        Row: {
          alt_text: string | null
          created_at: string
          display_order: number
          id: string
          post_id: string
          storage_path: string
        }
        Insert: {
          alt_text?: string | null
          created_at?: string
          display_order?: number
          id?: string
          post_id: string
          storage_path: string
        }
        Update: {
          alt_text?: string | null
          created_at?: string
          display_order?: number
          id?: string
          post_id?: string
          storage_path?: string
        }
        Relationships: [
          {
            foreignKeyName: "feed_post_photos_post_id_fkey"
            columns: ["post_id"]
            isOneToOne: false
            referencedRelation: "feed_posts"
            referencedColumns: ["id"]
          },
        ]
      }
      feed_posts: {
        Row: {
          caption: string | null
          created_at: string
          created_by: string | null
          group_id: string | null
          id: string
          likes_count: number
          post_type: string
          published_at: string | null
          scope: string
          slideshow_seconds_per_photo: number | null
          source_handle: string | null
          source_kind: string
          source_post_id: string | null
          source_url: string | null
          status: string
          title: string | null
          updated_at: string
          video_id: string | null
          views_count: number
        }
        Insert: {
          caption?: string | null
          created_at?: string
          created_by?: string | null
          group_id?: string | null
          id?: string
          likes_count?: number
          post_type: string
          published_at?: string | null
          scope: string
          slideshow_seconds_per_photo?: number | null
          source_handle?: string | null
          source_kind: string
          source_post_id?: string | null
          source_url?: string | null
          status?: string
          title?: string | null
          updated_at?: string
          video_id?: string | null
          views_count?: number
        }
        Update: {
          caption?: string | null
          created_at?: string
          created_by?: string | null
          group_id?: string | null
          id?: string
          likes_count?: number
          post_type?: string
          published_at?: string | null
          scope?: string
          slideshow_seconds_per_photo?: number | null
          source_handle?: string | null
          source_kind?: string
          source_post_id?: string | null
          source_url?: string | null
          status?: string
          title?: string | null
          updated_at?: string
          video_id?: string | null
          views_count?: number
        }
        Relationships: [
          {
            foreignKeyName: "feed_posts_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "feed_posts_group_id_fkey"
            columns: ["group_id"]
            isOneToOne: false
            referencedRelation: "youth_groups"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "feed_posts_video_id_fkey"
            columns: ["video_id"]
            isOneToOne: false
            referencedRelation: "videos"
            referencedColumns: ["id"]
          },
        ]
      }
      instagram_scrape_jobs: {
        Row: {
          apify_dataset_id: string | null
          apify_run_id: string | null
          error_message: string | null
          finished_at: string | null
          id: string
          new_posts_count: number | null
          source_id: string | null
          started_at: string
          status: string
        }
        Insert: {
          apify_dataset_id?: string | null
          apify_run_id?: string | null
          error_message?: string | null
          finished_at?: string | null
          id?: string
          new_posts_count?: number | null
          source_id?: string | null
          started_at?: string
          status?: string
        }
        Update: {
          apify_dataset_id?: string | null
          apify_run_id?: string | null
          error_message?: string | null
          finished_at?: string | null
          id?: string
          new_posts_count?: number | null
          source_id?: string | null
          started_at?: string
          status?: string
        }
        Relationships: [
          {
            foreignKeyName: "instagram_scrape_jobs_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: false
            referencedRelation: "instagram_sources"
            referencedColumns: ["id"]
          },
        ]
      }
      instagram_sources: {
        Row: {
          added_at: string
          added_by: string | null
          group_id: string
          handle: string
          id: string
          is_active: boolean
          last_scraped_at: string | null
          results_limit: number
        }
        Insert: {
          added_at?: string
          added_by?: string | null
          group_id: string
          handle: string
          id?: string
          is_active?: boolean
          last_scraped_at?: string | null
          results_limit?: number
        }
        Update: {
          added_at?: string
          added_by?: string | null
          group_id?: string
          handle?: string
          id?: string
          is_active?: boolean
          last_scraped_at?: string | null
          results_limit?: number
        }
        Relationships: [
          {
            foreignKeyName: "instagram_sources_added_by_fkey"
            columns: ["added_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "instagram_sources_group_id_fkey"
            columns: ["group_id"]
            isOneToOne: false
            referencedRelation: "youth_groups"
            referencedColumns: ["id"]
          },
        ]
      }
      messages: {
        Row: {
          body: string
          created_at: string
          id: string
          moderation_categories: Json | null
          moderation_status: Database["public"]["Enums"]["moderation_status"]
          sender_id: string
          thread_id: string
        }
        Insert: {
          body: string
          created_at?: string
          id?: string
          moderation_categories?: Json | null
          moderation_status?: Database["public"]["Enums"]["moderation_status"]
          sender_id: string
          thread_id: string
        }
        Update: {
          body?: string
          created_at?: string
          id?: string
          moderation_categories?: Json | null
          moderation_status?: Database["public"]["Enums"]["moderation_status"]
          sender_id?: string
          thread_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "messages_sender_id_profiles_fkey"
            columns: ["sender_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "messages_thread_id_fkey"
            columns: ["thread_id"]
            isOneToOne: false
            referencedRelation: "chat_threads"
            referencedColumns: ["id"]
          },
        ]
      }
      moderation_alerts: {
        Row: {
          acknowledged_at: string | null
          acknowledged_by: string | null
          categories: Json | null
          concern_category: string | null
          concern_confidence: number | null
          concern_reason: string | null
          created_at: string
          group_id: string
          id: string
          message_id: string | null
          preview: string | null
          sender_id: string | null
          status: Database["public"]["Enums"]["moderation_status"]
          thread_id: string
        }
        Insert: {
          acknowledged_at?: string | null
          acknowledged_by?: string | null
          categories?: Json | null
          concern_category?: string | null
          concern_confidence?: number | null
          concern_reason?: string | null
          created_at?: string
          group_id: string
          id?: string
          message_id?: string | null
          preview?: string | null
          sender_id?: string | null
          status: Database["public"]["Enums"]["moderation_status"]
          thread_id: string
        }
        Update: {
          acknowledged_at?: string | null
          acknowledged_by?: string | null
          categories?: Json | null
          concern_category?: string | null
          concern_confidence?: number | null
          concern_reason?: string | null
          created_at?: string
          group_id?: string
          id?: string
          message_id?: string | null
          preview?: string | null
          sender_id?: string | null
          status?: Database["public"]["Enums"]["moderation_status"]
          thread_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "moderation_alerts_ack_profiles_fkey"
            columns: ["acknowledged_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "moderation_alerts_group_id_fkey"
            columns: ["group_id"]
            isOneToOne: false
            referencedRelation: "youth_groups"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "moderation_alerts_message_id_fkey"
            columns: ["message_id"]
            isOneToOne: false
            referencedRelation: "messages"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "moderation_alerts_sender_profiles_fkey"
            columns: ["sender_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "moderation_alerts_thread_id_fkey"
            columns: ["thread_id"]
            isOneToOne: false
            referencedRelation: "chat_threads"
            referencedColumns: ["id"]
          },
        ]
      }
      moderation_flags: {
        Row: {
          category: string | null
          excerpt: string | null
          flagged_at: string
          group_id: string | null
          id: string
          pastor_notified: boolean
          score: number | null
          severity: Database["public"]["Enums"]["flag_severity"]
          status: Database["public"]["Enums"]["flag_status"]
          thread: string | null
          user_id: string | null
        }
        Insert: {
          category?: string | null
          excerpt?: string | null
          flagged_at?: string
          group_id?: string | null
          id?: string
          pastor_notified?: boolean
          score?: number | null
          severity?: Database["public"]["Enums"]["flag_severity"]
          status?: Database["public"]["Enums"]["flag_status"]
          thread?: string | null
          user_id?: string | null
        }
        Update: {
          category?: string | null
          excerpt?: string | null
          flagged_at?: string
          group_id?: string | null
          id?: string
          pastor_notified?: boolean
          score?: number | null
          severity?: Database["public"]["Enums"]["flag_severity"]
          status?: Database["public"]["Enums"]["flag_status"]
          thread?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "moderation_flags_group_id_fkey"
            columns: ["group_id"]
            isOneToOne: false
            referencedRelation: "youth_groups"
            referencedColumns: ["id"]
          },
        ]
      }
      pastor_signup_drafts: {
        Row: {
          address_city: string | null
          address_line: string | null
          church_name: string | null
          created_at: string
          description: string | null
          email: string | null
          finalized_youth_group_id: string | null
          first_name: string | null
          gradient_idx: number | null
          group_name: string | null
          id: string
          last_name: string | null
          latitude: number | null
          logo_url: string | null
          longitude: number | null
          meeting_day: string | null
          meeting_time: string | null
          promo_code: string | null
          public_on_map: boolean | null
          reminder_sent_at: string | null
          resumed_at: string | null
          stage: Database["public"]["Enums"]["pastor_signup_stage"]
          tier_id: string | null
          updated_at: string
          user_id: string | null
        }
        Insert: {
          address_city?: string | null
          address_line?: string | null
          church_name?: string | null
          created_at?: string
          description?: string | null
          email?: string | null
          finalized_youth_group_id?: string | null
          first_name?: string | null
          gradient_idx?: number | null
          group_name?: string | null
          id?: string
          last_name?: string | null
          latitude?: number | null
          logo_url?: string | null
          longitude?: number | null
          meeting_day?: string | null
          meeting_time?: string | null
          promo_code?: string | null
          public_on_map?: boolean | null
          reminder_sent_at?: string | null
          resumed_at?: string | null
          stage?: Database["public"]["Enums"]["pastor_signup_stage"]
          tier_id?: string | null
          updated_at?: string
          user_id?: string | null
        }
        Update: {
          address_city?: string | null
          address_line?: string | null
          church_name?: string | null
          created_at?: string
          description?: string | null
          email?: string | null
          finalized_youth_group_id?: string | null
          first_name?: string | null
          gradient_idx?: number | null
          group_name?: string | null
          id?: string
          last_name?: string | null
          latitude?: number | null
          logo_url?: string | null
          longitude?: number | null
          meeting_day?: string | null
          meeting_time?: string | null
          promo_code?: string | null
          public_on_map?: boolean | null
          reminder_sent_at?: string | null
          resumed_at?: string | null
          stage?: Database["public"]["Enums"]["pastor_signup_stage"]
          tier_id?: string | null
          updated_at?: string
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "pastor_signup_drafts_finalized_youth_group_id_fkey"
            columns: ["finalized_youth_group_id"]
            isOneToOne: false
            referencedRelation: "youth_groups"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "pastor_signup_drafts_tier_id_fkey"
            columns: ["tier_id"]
            isOneToOne: false
            referencedRelation: "subscription_tiers"
            referencedColumns: ["id"]
          },
        ]
      }
      pastor_signup_promos: {
        Row: {
          active: boolean
          code: string
          created_at: string
          description: string | null
          expires_at: string | null
          id: string
          label: string | null
          max_uses: number | null
          trial_days: number
          updated_at: string
          uses_count: number
        }
        Insert: {
          active?: boolean
          code: string
          created_at?: string
          description?: string | null
          expires_at?: string | null
          id?: string
          label?: string | null
          max_uses?: number | null
          trial_days: number
          updated_at?: string
          uses_count?: number
        }
        Update: {
          active?: boolean
          code?: string
          created_at?: string
          description?: string | null
          expires_at?: string | null
          id?: string
          label?: string | null
          max_uses?: number | null
          trial_days?: number
          updated_at?: string
          uses_count?: number
        }
        Relationships: []
      }
      profiles: {
        Row: {
          age_band: string | null
          age_verified_at: string | null
          avatar_url: string | null
          bio: string | null
          created_at: string
          current_streak_run_id: string | null
          date_of_birth: string | null
          deleted_at: string | null
          display_name: string | null
          email: string | null
          grade_year: number | null
          handle: string
          id: string
          is_managed_child: boolean
          is_visible_on_map: boolean
          last_opened_at: string
          last_streak_date: string | null
          lifetime_xp: number
          parent_account_id: string | null
          streak: number
          updated_at: string
          water: number
          xp: number
        }
        Insert: {
          age_band?: string | null
          age_verified_at?: string | null
          avatar_url?: string | null
          bio?: string | null
          created_at?: string
          current_streak_run_id?: string | null
          date_of_birth?: string | null
          deleted_at?: string | null
          display_name?: string | null
          email?: string | null
          grade_year?: number | null
          handle: string
          id: string
          is_managed_child?: boolean
          is_visible_on_map?: boolean
          last_opened_at?: string
          last_streak_date?: string | null
          lifetime_xp?: number
          parent_account_id?: string | null
          streak?: number
          updated_at?: string
          water?: number
          xp?: number
        }
        Update: {
          age_band?: string | null
          age_verified_at?: string | null
          avatar_url?: string | null
          bio?: string | null
          created_at?: string
          current_streak_run_id?: string | null
          date_of_birth?: string | null
          deleted_at?: string | null
          display_name?: string | null
          email?: string | null
          grade_year?: number | null
          handle?: string
          id?: string
          is_managed_child?: boolean
          is_visible_on_map?: boolean
          last_opened_at?: string
          last_streak_date?: string | null
          lifetime_xp?: number
          parent_account_id?: string | null
          streak?: number
          updated_at?: string
          water?: number
          xp?: number
        }
        Relationships: [
          {
            foreignKeyName: "profiles_parent_account_id_fkey"
            columns: ["parent_account_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      small_group_members: {
        Row: {
          id: string
          joined_at: string
          role: Database["public"]["Enums"]["small_group_role"]
          small_group_id: string
          user_id: string
        }
        Insert: {
          id?: string
          joined_at?: string
          role?: Database["public"]["Enums"]["small_group_role"]
          small_group_id: string
          user_id: string
        }
        Update: {
          id?: string
          joined_at?: string
          role?: Database["public"]["Enums"]["small_group_role"]
          small_group_id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "small_group_members_small_group_id_fkey"
            columns: ["small_group_id"]
            isOneToOne: false
            referencedRelation: "small_groups"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "small_group_members_user_profiles_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      small_groups: {
        Row: {
          created_at: string
          description: string | null
          id: string
          meeting_day: string | null
          meeting_time: string | null
          name: string
          updated_at: string
          youth_group_id: string
        }
        Insert: {
          created_at?: string
          description?: string | null
          id?: string
          meeting_day?: string | null
          meeting_time?: string | null
          name: string
          updated_at?: string
          youth_group_id: string
        }
        Update: {
          created_at?: string
          description?: string | null
          id?: string
          meeting_day?: string | null
          meeting_time?: string | null
          name?: string
          updated_at?: string
          youth_group_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "small_groups_youth_group_id_fkey"
            columns: ["youth_group_id"]
            isOneToOne: false
            referencedRelation: "youth_groups"
            referencedColumns: ["id"]
          },
        ]
      }
      spatial_ref_sys: {
        Row: {
          auth_name: string | null
          auth_srid: number | null
          proj4text: string | null
          srid: number
          srtext: string | null
        }
        Insert: {
          auth_name?: string | null
          auth_srid?: number | null
          proj4text?: string | null
          srid: number
          srtext?: string | null
        }
        Update: {
          auth_name?: string | null
          auth_srid?: number | null
          proj4text?: string | null
          srid?: number
          srtext?: string | null
        }
        Relationships: []
      }
      store_item_levels: {
        Row: {
          id: string
          item_id: string
          label: string
          level: number
          size_px: number
          sprite_url: string | null
          water_to_next: number
        }
        Insert: {
          id?: string
          item_id: string
          label: string
          level: number
          size_px?: number
          sprite_url?: string | null
          water_to_next?: number
        }
        Update: {
          id?: string
          item_id?: string
          label?: string
          level?: number
          size_px?: number
          sprite_url?: string | null
          water_to_next?: number
        }
        Relationships: [
          {
            foreignKeyName: "store_item_levels_item_id_fkey"
            columns: ["item_id"]
            isOneToOne: false
            referencedRelation: "store_items"
            referencedColumns: ["id"]
          },
        ]
      }
      store_items: {
        Row: {
          active: boolean
          cost_xp: number
          created_at: string
          default_water_per_level: number
          id: string
          name: string
          rarity: Database["public"]["Enums"]["item_rarity"]
          type: Database["public"]["Enums"]["item_type"]
        }
        Insert: {
          active?: boolean
          cost_xp?: number
          created_at?: string
          default_water_per_level?: number
          id?: string
          name: string
          rarity?: Database["public"]["Enums"]["item_rarity"]
          type: Database["public"]["Enums"]["item_type"]
        }
        Update: {
          active?: boolean
          cost_xp?: number
          created_at?: string
          default_water_per_level?: number
          id?: string
          name?: string
          rarity?: Database["public"]["Enums"]["item_rarity"]
          type?: Database["public"]["Enums"]["item_type"]
        }
        Relationships: []
      }
      stripe_events: {
        Row: {
          error_message: string | null
          id: string
          payload: Json
          processed_at: string | null
          received_at: string
          type: string
        }
        Insert: {
          error_message?: string | null
          id: string
          payload: Json
          processed_at?: string | null
          received_at?: string
          type: string
        }
        Update: {
          error_message?: string | null
          id?: string
          payload?: Json
          processed_at?: string | null
          received_at?: string
          type?: string
        }
        Relationships: []
      }
      stripe_subscriptions: {
        Row: {
          cancel_at_period_end: boolean
          canceled_at: string | null
          created_at: string
          current_period_end: string | null
          current_period_start: string | null
          draft_id: string | null
          group_id: string | null
          id: string
          last_synced_at: string | null
          pastor_user_id: string | null
          pending_effective_at: string | null
          pending_tier_id: string | null
          raw_payload: Json | null
          status: Database["public"]["Enums"]["stripe_subscription_status"]
          stripe_customer_id: string
          stripe_price_id: string
          stripe_subscription_id: string
          tier_id: string | null
          trial_end: string | null
          updated_at: string
        }
        Insert: {
          cancel_at_period_end?: boolean
          canceled_at?: string | null
          created_at?: string
          current_period_end?: string | null
          current_period_start?: string | null
          draft_id?: string | null
          group_id?: string | null
          id?: string
          last_synced_at?: string | null
          pastor_user_id?: string | null
          pending_effective_at?: string | null
          pending_tier_id?: string | null
          raw_payload?: Json | null
          status: Database["public"]["Enums"]["stripe_subscription_status"]
          stripe_customer_id: string
          stripe_price_id: string
          stripe_subscription_id: string
          tier_id?: string | null
          trial_end?: string | null
          updated_at?: string
        }
        Update: {
          cancel_at_period_end?: boolean
          canceled_at?: string | null
          created_at?: string
          current_period_end?: string | null
          current_period_start?: string | null
          draft_id?: string | null
          group_id?: string | null
          id?: string
          last_synced_at?: string | null
          pastor_user_id?: string | null
          pending_effective_at?: string | null
          pending_tier_id?: string | null
          raw_payload?: Json | null
          status?: Database["public"]["Enums"]["stripe_subscription_status"]
          stripe_customer_id?: string
          stripe_price_id?: string
          stripe_subscription_id?: string
          tier_id?: string | null
          trial_end?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "stripe_subscriptions_draft_id_fkey"
            columns: ["draft_id"]
            isOneToOne: false
            referencedRelation: "pastor_signup_drafts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "stripe_subscriptions_group_id_fkey"
            columns: ["group_id"]
            isOneToOne: false
            referencedRelation: "youth_groups"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "stripe_subscriptions_pending_tier_id_fkey"
            columns: ["pending_tier_id"]
            isOneToOne: false
            referencedRelation: "subscription_tiers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "stripe_subscriptions_tier_id_fkey"
            columns: ["tier_id"]
            isOneToOne: false
            referencedRelation: "subscription_tiers"
            referencedColumns: ["id"]
          },
        ]
      }
      subscription_tiers: {
        Row: {
          active: boolean
          created_at: string
          currency: string
          display_order: number
          id: string
          is_contact_only: boolean
          max_active: number
          name: string
          price_cents: number
          range_label: string
          stripe_price_id: string | null
          updated_at: string
        }
        Insert: {
          active?: boolean
          created_at?: string
          currency?: string
          display_order: number
          id: string
          is_contact_only?: boolean
          max_active: number
          name: string
          price_cents: number
          range_label: string
          stripe_price_id?: string | null
          updated_at?: string
        }
        Update: {
          active?: boolean
          created_at?: string
          currency?: string
          display_order?: number
          id?: string
          is_contact_only?: boolean
          max_active?: number
          name?: string
          price_cents?: number
          range_label?: string
          stripe_price_id?: string | null
          updated_at?: string
        }
        Relationships: []
      }
      thread_subscribers: {
        Row: {
          id: string
          joined_at: string
          last_read_at: string | null
          thread_id: string
          user_id: string
        }
        Insert: {
          id?: string
          joined_at?: string
          last_read_at?: string | null
          thread_id: string
          user_id: string
        }
        Update: {
          id?: string
          joined_at?: string
          last_read_at?: string | null
          thread_id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "thread_subscribers_thread_id_fkey"
            columns: ["thread_id"]
            isOneToOne: false
            referencedRelation: "chat_threads"
            referencedColumns: ["id"]
          },
        ]
      }
      user_roles: {
        Row: {
          id: string
          role: Database["public"]["Enums"]["app_role"]
          user_id: string
        }
        Insert: {
          id?: string
          role: Database["public"]["Enums"]["app_role"]
          user_id: string
        }
        Update: {
          id?: string
          role?: Database["public"]["Enums"]["app_role"]
          user_id?: string
        }
        Relationships: []
      }
      user_streak_milestone_grants: {
        Row: {
          awarded_at: string
          id: string
          milestone: number
          run_id: string
          user_id: string
          water_awarded: number
          xp_awarded: number
        }
        Insert: {
          awarded_at?: string
          id?: string
          milestone: number
          run_id: string
          user_id: string
          water_awarded: number
          xp_awarded: number
        }
        Update: {
          awarded_at?: string
          id?: string
          milestone?: number
          run_id?: string
          user_id?: string
          water_awarded?: number
          xp_awarded?: number
        }
        Relationships: []
      }
      user_xp_grants: {
        Row: {
          amount: number
          awarded_at: string
          id: string
          source: string
          user_id: string
        }
        Insert: {
          amount: number
          awarded_at?: string
          id?: string
          source: string
          user_id: string
        }
        Update: {
          amount?: number
          awarded_at?: string
          id?: string
          source?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "user_xp_grants_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      videos: {
        Row: {
          aspect_ratio: string | null
          created_at: string
          created_by: string | null
          duration_sec: number | null
          group_id: string | null
          id: string
          mux_asset_id: string | null
          mux_playback_id: string | null
          mux_upload_id: string | null
          plan_block_id: string | null
          plan_day_id: string | null
          policy: Database["public"]["Enums"]["video_policy"]
          published_at: string | null
          scope: Database["public"]["Enums"]["video_scope"]
          status: Database["public"]["Enums"]["video_status"]
          title: string
          views: number
        }
        Insert: {
          aspect_ratio?: string | null
          created_at?: string
          created_by?: string | null
          duration_sec?: number | null
          group_id?: string | null
          id?: string
          mux_asset_id?: string | null
          mux_playback_id?: string | null
          mux_upload_id?: string | null
          plan_block_id?: string | null
          plan_day_id?: string | null
          policy?: Database["public"]["Enums"]["video_policy"]
          published_at?: string | null
          scope?: Database["public"]["Enums"]["video_scope"]
          status?: Database["public"]["Enums"]["video_status"]
          title: string
          views?: number
        }
        Update: {
          aspect_ratio?: string | null
          created_at?: string
          created_by?: string | null
          duration_sec?: number | null
          group_id?: string | null
          id?: string
          mux_asset_id?: string | null
          mux_playback_id?: string | null
          mux_upload_id?: string | null
          plan_block_id?: string | null
          plan_day_id?: string | null
          policy?: Database["public"]["Enums"]["video_policy"]
          published_at?: string | null
          scope?: Database["public"]["Enums"]["video_scope"]
          status?: Database["public"]["Enums"]["video_status"]
          title?: string
          views?: number
        }
        Relationships: [
          {
            foreignKeyName: "videos_group_id_fkey"
            columns: ["group_id"]
            isOneToOne: false
            referencedRelation: "youth_groups"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "videos_plan_day_id_fkey"
            columns: ["plan_day_id"]
            isOneToOne: false
            referencedRelation: "bible_plan_days"
            referencedColumns: ["id"]
          },
        ]
      }
      weekly_ranking_snapshots: {
        Row: {
          active_count: number
          adjusted_xp: number
          class: string
          created_at: string
          group_id: string
          id: string
          multiplier: number
          rank_in_class: number
          total_groups_in_class: number
          week_start: string
          week_xp: number
        }
        Insert: {
          active_count: number
          adjusted_xp: number
          class: string
          created_at?: string
          group_id: string
          id?: string
          multiplier: number
          rank_in_class: number
          total_groups_in_class: number
          week_start: string
          week_xp: number
        }
        Update: {
          active_count?: number
          adjusted_xp?: number
          class?: string
          created_at?: string
          group_id?: string
          id?: string
          multiplier?: number
          rank_in_class?: number
          total_groups_in_class?: number
          week_start?: string
          week_xp?: number
        }
        Relationships: [
          {
            foreignKeyName: "weekly_ranking_snapshots_group_id_fkey"
            columns: ["group_id"]
            isOneToOne: false
            referencedRelation: "youth_groups"
            referencedColumns: ["id"]
          },
        ]
      }
      weekly_user_ranking_snapshots: {
        Row: {
          created_at: string
          group_id: string
          id: string
          rank_in_group: number
          user_id: string
          week_start: string
          week_xp: number
        }
        Insert: {
          created_at?: string
          group_id: string
          id?: string
          rank_in_group: number
          user_id: string
          week_start: string
          week_xp: number
        }
        Update: {
          created_at?: string
          group_id?: string
          id?: string
          rank_in_group?: number
          user_id?: string
          week_start?: string
          week_xp?: number
        }
        Relationships: [
          {
            foreignKeyName: "weekly_user_ranking_snapshots_group_id_fkey"
            columns: ["group_id"]
            isOneToOne: false
            referencedRelation: "youth_groups"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "weekly_user_ranking_snapshots_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      youth_group_join_requests: {
        Row: {
          decided_at: string | null
          decided_by: string | null
          group_id: string
          id: string
          message: string | null
          requested_at: string
          status: Database["public"]["Enums"]["join_request_status"]
          user_id: string
        }
        Insert: {
          decided_at?: string | null
          decided_by?: string | null
          group_id: string
          id?: string
          message?: string | null
          requested_at?: string
          status?: Database["public"]["Enums"]["join_request_status"]
          user_id: string
        }
        Update: {
          decided_at?: string | null
          decided_by?: string | null
          group_id?: string
          id?: string
          message?: string | null
          requested_at?: string
          status?: Database["public"]["Enums"]["join_request_status"]
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "youth_group_join_requests_group_id_fkey"
            columns: ["group_id"]
            isOneToOne: false
            referencedRelation: "youth_groups"
            referencedColumns: ["id"]
          },
        ]
      }
      youth_group_members: {
        Row: {
          group_id: string
          id: string
          joined_at: string
          role: Database["public"]["Enums"]["group_role"]
          user_id: string
        }
        Insert: {
          group_id: string
          id?: string
          joined_at?: string
          role?: Database["public"]["Enums"]["group_role"]
          user_id: string
        }
        Update: {
          group_id?: string
          id?: string
          joined_at?: string
          role?: Database["public"]["Enums"]["group_role"]
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "youth_group_members_group_id_fkey"
            columns: ["group_id"]
            isOneToOne: false
            referencedRelation: "youth_groups"
            referencedColumns: ["id"]
          },
        ]
      }
      youth_group_submissions: {
        Row: {
          church_name: string
          converted_at: string | null
          created_at: string
          decided_at: string | null
          decided_by: string | null
          email_provider_id: string | null
          emailed_at: string | null
          followup_count: number
          id: string
          last_followup_at: string | null
          lead_stage: string
          lost_at: string | null
          lost_reason: string | null
          notes: string | null
          pastor_email: string
          pastor_name: string
          pastor_phone: string | null
          referral_channel: string | null
          status: Database["public"]["Enums"]["group_submission_status"]
          submitter_email: string | null
          submitter_id: string | null
        }
        Insert: {
          church_name: string
          converted_at?: string | null
          created_at?: string
          decided_at?: string | null
          decided_by?: string | null
          email_provider_id?: string | null
          emailed_at?: string | null
          followup_count?: number
          id?: string
          last_followup_at?: string | null
          lead_stage?: string
          lost_at?: string | null
          lost_reason?: string | null
          notes?: string | null
          pastor_email: string
          pastor_name: string
          pastor_phone?: string | null
          referral_channel?: string | null
          status?: Database["public"]["Enums"]["group_submission_status"]
          submitter_email?: string | null
          submitter_id?: string | null
        }
        Update: {
          church_name?: string
          converted_at?: string | null
          created_at?: string
          decided_at?: string | null
          decided_by?: string | null
          email_provider_id?: string | null
          emailed_at?: string | null
          followup_count?: number
          id?: string
          last_followup_at?: string | null
          lead_stage?: string
          lost_at?: string | null
          lost_reason?: string | null
          notes?: string | null
          pastor_email?: string
          pastor_name?: string
          pastor_phone?: string | null
          referral_channel?: string | null
          status?: Database["public"]["Enums"]["group_submission_status"]
          submitter_email?: string | null
          submitter_id?: string | null
        }
        Relationships: []
      }
      youth_groups: {
        Row: {
          address: string | null
          church_name: string
          created_at: string
          created_by: string | null
          description: string | null
          grades: number[] | null
          gradient_from: string | null
          gradient_to: string | null
          group_type: string | null
          id: string
          is_default_ygteev: boolean
          is_public: boolean
          latitude: number | null
          location: unknown
          logo_url: string | null
          longitude: number | null
          meeting_time: string | null
          name: string
          stripe_customer_id: string | null
          updated_at: string
        }
        Insert: {
          address?: string | null
          church_name: string
          created_at?: string
          created_by?: string | null
          description?: string | null
          grades?: number[] | null
          gradient_from?: string | null
          gradient_to?: string | null
          group_type?: string | null
          id?: string
          is_default_ygteev?: boolean
          is_public?: boolean
          latitude?: number | null
          location?: unknown
          logo_url?: string | null
          longitude?: number | null
          meeting_time?: string | null
          name: string
          stripe_customer_id?: string | null
          updated_at?: string
        }
        Update: {
          address?: string | null
          church_name?: string
          created_at?: string
          created_by?: string | null
          description?: string | null
          grades?: number[] | null
          gradient_from?: string | null
          gradient_to?: string | null
          group_type?: string | null
          id?: string
          is_default_ygteev?: boolean
          is_public?: boolean
          latitude?: number | null
          location?: unknown
          logo_url?: string | null
          longitude?: number | null
          meeting_time?: string | null
          name?: string
          stripe_customer_id?: string | null
          updated_at?: string
        }
        Relationships: []
      }
    }
    Views: {
      attendance_event_summary: {
        Row: {
          absent_count: number | null
          created_at: string | null
          created_by: string | null
          event_id: string | null
          occurred_at: string | null
          present_count: number | null
          roster_total: number | null
          small_group_id: string | null
          small_group_name: string | null
          title: string | null
          updated_at: string | null
          youth_group_id: string | null
        }
        Relationships: [
          {
            foreignKeyName: "attendance_events_small_group_id_fkey"
            columns: ["small_group_id"]
            isOneToOne: false
            referencedRelation: "small_groups"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "small_groups_youth_group_id_fkey"
            columns: ["youth_group_id"]
            isOneToOne: false
            referencedRelation: "youth_groups"
            referencedColumns: ["id"]
          },
        ]
      }
      geography_columns: {
        Row: {
          coord_dimension: number | null
          f_geography_column: unknown
          f_table_catalog: unknown
          f_table_name: unknown
          f_table_schema: unknown
          srid: number | null
          type: string | null
        }
        Relationships: []
      }
      geometry_columns: {
        Row: {
          coord_dimension: number | null
          f_geometry_column: unknown
          f_table_catalog: string | null
          f_table_name: unknown
          f_table_schema: unknown
          srid: number | null
          type: string | null
        }
        Insert: {
          coord_dimension?: number | null
          f_geometry_column?: unknown
          f_table_catalog?: string | null
          f_table_name?: unknown
          f_table_schema?: unknown
          srid?: number | null
          type?: string | null
        }
        Update: {
          coord_dimension?: number | null
          f_geometry_column?: unknown
          f_table_catalog?: string | null
          f_table_name?: unknown
          f_table_schema?: unknown
          srid?: number | null
          type?: string | null
        }
        Relationships: []
      }
      pastor_billing_summary: {
        Row: {
          active_count: number | null
          cancel_at_period_end: boolean | null
          current_max_active: number | null
          current_period_end: string | null
          current_range: string | null
          current_tier_id: string | null
          current_tier_name: string | null
          pastor_user_id: string | null
          pending_effective_at: string | null
          pending_tier_id: string | null
          status:
            | Database["public"]["Enums"]["stripe_subscription_status"]
            | null
          subscription_id: string | null
          target_tier_id: string | null
          trial_end: string | null
        }
        Relationships: [
          {
            foreignKeyName: "stripe_subscriptions_pending_tier_id_fkey"
            columns: ["pending_tier_id"]
            isOneToOne: false
            referencedRelation: "subscription_tiers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "stripe_subscriptions_tier_id_fkey"
            columns: ["current_tier_id"]
            isOneToOne: false
            referencedRelation: "subscription_tiers"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Functions: {
      _can_manage_feed_post: { Args: { _post_id: string }; Returns: boolean }
      _dev_grant_age_verification: { Args: never; Returns: string }
      _get_service_role_key: { Args: never; Returns: string }
      _pastor_can_edit_plan: { Args: { _plan_id: string }; Returns: boolean }
      _pastor_can_view_group: { Args: { _group_id: string }; Returns: boolean }
      _postgis_deprecate: {
        Args: { newname: string; oldname: string; version: string }
        Returns: undefined
      }
      _postgis_index_extent: {
        Args: { col: string; tbl: unknown }
        Returns: unknown
      }
      _postgis_pgsql_version: { Args: never; Returns: string }
      _postgis_scripts_pgsql_version: { Args: never; Returns: string }
      _postgis_selectivity: {
        Args: { att_name: string; geom: unknown; mode?: string; tbl: unknown }
        Returns: number
      }
      _postgis_stats: {
        Args: { ""?: string; att_name: string; tbl: unknown }
        Returns: string
      }
      _st_3dintersects: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      _st_contains: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      _st_containsproperly: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      _st_coveredby:
        | { Args: { geog1: unknown; geog2: unknown }; Returns: boolean }
        | { Args: { geom1: unknown; geom2: unknown }; Returns: boolean }
      _st_covers:
        | { Args: { geog1: unknown; geog2: unknown }; Returns: boolean }
        | { Args: { geom1: unknown; geom2: unknown }; Returns: boolean }
      _st_crosses: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      _st_dwithin: {
        Args: {
          geog1: unknown
          geog2: unknown
          tolerance: number
          use_spheroid?: boolean
        }
        Returns: boolean
      }
      _st_equals: { Args: { geom1: unknown; geom2: unknown }; Returns: boolean }
      _st_intersects: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      _st_linecrossingdirection: {
        Args: { line1: unknown; line2: unknown }
        Returns: number
      }
      _st_longestline: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: unknown
      }
      _st_maxdistance: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: number
      }
      _st_orderingequals: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      _st_overlaps: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      _st_sortablehash: { Args: { geom: unknown }; Returns: number }
      _st_touches: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      _st_voronoi: {
        Args: {
          clip?: unknown
          g1: unknown
          return_polygons?: boolean
          tolerance?: number
        }
        Returns: unknown
      }
      _st_within: { Args: { geom1: unknown; geom2: unknown }; Returns: boolean }
      accept_family_invite: { Args: { _code: string }; Returns: string }
      addauth: { Args: { "": string }; Returns: boolean }
      addgeometrycolumn:
        | {
            Args: {
              catalog_name: string
              column_name: string
              new_dim: number
              new_srid_in: number
              new_type: string
              schema_name: string
              table_name: string
              use_typmod?: boolean
            }
            Returns: string
          }
        | {
            Args: {
              column_name: string
              new_dim: number
              new_srid: number
              new_type: string
              schema_name: string
              table_name: string
              use_typmod?: boolean
            }
            Returns: string
          }
        | {
            Args: {
              column_name: string
              new_dim: number
              new_srid: number
              new_type: string
              table_name: string
              use_typmod?: boolean
            }
            Returns: string
          }
      admin_approve_to_official: {
        Args: { _source_post_id: string }
        Returns: string
      }
      admin_hard_delete_user: { Args: { _user_id: string }; Returns: undefined }
      admin_list_all_group_posts: {
        Args: { _limit?: number }
        Returns: {
          already_in_official: boolean
          caption: string
          duration_sec: number
          group_id: string
          group_name: string
          likes_count: number
          mux_playback_id: string
          photos: Json
          post_id: string
          post_type: string
          published_at: string
          source_handle: string
          source_kind: string
          title: string
          video_id: string
          views_count: number
        }[]
      }
      admin_weekly_ranking_report: {
        Args: { _week_start?: string }
        Returns: {
          active_count: number
          adjusted_xp: number
          church_name: string
          class: string
          class_label: string
          group_id: string
          group_name: string
          logo_url: string
          multiplier: number
          rank_in_class: number
          total_groups_in_class: number
          week_start: string
          week_xp: number
        }[]
      }
      am_i_in_any_youth_group: { Args: never; Returns: boolean }
      can_manage_small_groups: {
        Args: { _small_group_id: string; _user_id: string }
        Returns: boolean
      }
      can_manage_user_profile: {
        Args: { _caller_id: string; _target_user_id: string }
        Returns: boolean
      }
      can_take_attendance: {
        Args: { _small_group_id: string; _user_id: string }
        Returns: boolean
      }
      can_user_start_plan: {
        Args: { _plan_id: string; _user_id: string }
        Returns: boolean
      }
      complete_pastor_plan_day: {
        Args: { _answers?: Json; _day_number: number; _plan_id: string }
        Returns: Json
      }
      complete_plan_step: {
        Args: {
          _answers?: Json
          _day_id: string
          _plan_id: string
          _step: Database["public"]["Enums"]["bible_plan_step"]
        }
        Returns: Json
      }
      compute_bible_plan_rewards: {
        Args: { _plan_id: string }
        Returns: undefined
      }
      create_family_invite: {
        Args: {
          _family_id: string
          _invited_email?: string
          _invited_user_id?: string
        }
        Returns: Json
      }
      disablelongtransactions: { Args: never; Returns: string }
      dropgeometrycolumn:
        | {
            Args: {
              catalog_name: string
              column_name: string
              schema_name: string
              table_name: string
            }
            Returns: string
          }
        | {
            Args: {
              column_name: string
              schema_name: string
              table_name: string
            }
            Returns: string
          }
        | { Args: { column_name: string; table_name: string }; Returns: string }
      dropgeometrytable:
        | {
            Args: {
              catalog_name: string
              schema_name: string
              table_name: string
            }
            Returns: string
          }
        | { Args: { schema_name: string; table_name: string }; Returns: string }
        | { Args: { table_name: string }; Returns: string }
      enablelongtransactions: { Args: never; Returns: string }
      ensure_dm_thread: {
        Args: {
          _group_id: string
          _kind: Database["public"]["Enums"]["thread_kind"]
          _u1: string
          _u2: string
        }
        Returns: string
      }
      ensure_group_main_thread: { Args: { _group_id: string }; Returns: string }
      ensure_parent_chat_subscriptions: {
        Args: { _family_id: string; _parent_id: string }
        Returns: undefined
      }
      ensure_small_group_thread: {
        Args: { _small_group_id: string }
        Returns: string
      }
      equals: { Args: { geom1: unknown; geom2: unknown }; Returns: boolean }
      event_rsvp_summary: {
        Args: { _event_id: string }
        Returns: {
          declined: Json
          declined_count: number
          going: Json
          going_count: number
          maybe: Json
          maybe_count: number
          total_count: number
          viewer_status: string
        }[]
      }
      family_add_via_scan: {
        Args: { _family_id: string; _scanned_user_id: string }
        Returns: string
      }
      feed_post_record_view: { Args: { _post_id: string }; Returns: undefined }
      feed_post_record_watch_complete: {
        Args: { _post_id: string }
        Returns: undefined
      }
      feed_post_toggle_like: { Args: { _post_id: string }; Returns: boolean }
      finalize_pastor_signup: { Args: { _draft_id: string }; Returns: string }
      for_you_feed: {
        Args: { _group_id?: string; _limit?: number; _offset?: number }
        Returns: {
          aspect_ratio: string
          author_avatar: string
          author_id: string
          author_name: string
          caption: string
          duration_sec: number
          group_id: string
          group_name: string
          has_liked: boolean
          has_viewed: boolean
          likes_count: number
          mux_playback_id: string
          photos: Json
          post_id: string
          post_type: string
          published_at: string
          scope: string
          slideshow_seconds_per_photo: number
          source_handle: string
          source_kind: string
          source_url: string
          title: string
          video_id: string
          views_count: number
        }[]
      }
      generate_random_handle: { Args: never; Returns: string }
      geometry: { Args: { "": string }; Returns: unknown }
      geometry_above: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      geometry_below: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      geometry_cmp: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: number
      }
      geometry_contained_3d: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      geometry_contains: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      geometry_contains_3d: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      geometry_distance_box: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: number
      }
      geometry_distance_centroid: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: number
      }
      geometry_eq: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      geometry_ge: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      geometry_gt: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      geometry_le: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      geometry_left: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      geometry_lt: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      geometry_overabove: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      geometry_overbelow: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      geometry_overlaps: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      geometry_overlaps_3d: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      geometry_overleft: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      geometry_overright: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      geometry_right: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      geometry_same: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      geometry_same_3d: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      geometry_within: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      geomfromewkt: { Args: { "": string }; Returns: unknown }
      get_continue_card: {
        Args: never
        Returns: {
          day_id: string
          day_number: number
          day_title: string
          days_total: number
          is_resume: boolean
          plan_gradient_from: string
          plan_gradient_to: string
          plan_id: string
          plan_slug: string
          plan_title: string
          scripture_reference: string
          steps_completed: string[]
        }[]
      }
      get_group_header_stats: {
        Args: { _group_id: string }
        Returns: {
          active_count: number
          member_count: number
        }[]
      }
      get_my_entitlements: {
        Args: never
        Returns: {
          can_create_events: boolean
          can_create_plans: boolean
          can_run_youth_group: boolean
          is_parent: boolean
          is_pastor: boolean
          is_pro: boolean
          is_site_admin: boolean
        }[]
      }
      get_my_plan_day_progress: {
        Args: { _plan_id: string }
        Returns: {
          block_count: number
          completed_at: string
          day_id: string
          day_number: number
          is_completed: boolean
          scripture_reference: string
          step_water_earned: number
          step_xp_earned: number
          title: string
        }[]
      }
      get_my_youth_group_plans: {
        Args: { _filter?: string }
        Returns: {
          completed_at: string
          days_completed: number
          days_total: number
          gradient_index: number
          group_id: string
          group_name: string
          header_image_url: string
          header_kind: string
          is_completed: boolean
          plan_id: string
          published_at: string
          title: string
          visibility: Database["public"]["Enums"]["bible_plan_visibility"]
          water_reward: number
          xp_reward: number
        }[]
      }
      get_pastor_signup_promo: {
        Args: { _code: string }
        Returns: {
          code: string
          label: string
          trial_days: number
          valid: boolean
        }[]
      }
      get_user_plan_progress: {
        Args: { _plan_id: string }
        Returns: {
          day_complete: boolean
          day_completed_at: string
          day_id: string
          day_number: number
          day_xp_earned: number
          reflection: string
          scripture_reference: string
          steps_completed: string[]
          title: string
        }[]
      }
      gettransactionid: { Args: never; Returns: unknown }
      has_role: {
        Args: {
          _role: Database["public"]["Enums"]["app_role"]
          _user_id: string
        }
        Returns: boolean
      }
      heartbeat: { Args: never; Returns: undefined }
      increment_pastor_signup_promo_uses: {
        Args: { _code: string }
        Returns: undefined
      }
      is_group_member: {
        Args: { _group_id: string; _user_id: string }
        Returns: boolean
      }
      is_group_pastor: {
        Args: { _group_id: string; _user_id: string }
        Returns: boolean
      }
      is_in_family: { Args: { _family_id: string }; Returns: boolean }
      is_in_small_group: {
        Args: { _small_group_id: string; _user_id: string }
        Returns: boolean
      }
      is_pastor: { Args: never; Returns: boolean }
      is_paying_subscriber: { Args: { _user_id: string }; Returns: boolean }
      is_pro: { Args: { _user_id: string }; Returns: boolean }
      is_site_admin: { Args: { _user_id: string }; Returns: boolean }
      is_small_group_leader: {
        Args: { _small_group_id: string; _user_id: string }
        Returns: boolean
      }
      is_thread_subscriber: {
        Args: { _thread_id: string; _user_id?: string }
        Returns: boolean
      }
      join_group_via_qr_scan: { Args: { _group_id: string }; Returns: Json }
      level_for_xp: { Args: { _xp: number }; Returns: number }
      list_my_families: {
        Args: never
        Returns: {
          created_at: string
          family_id: string
          family_name: string
          members: Json
          my_role: string
        }[]
      }
      list_my_pending_family_invites: {
        Args: never
        Returns: {
          created_at: string
          expires_at: string
          family_id: string
          family_name: string
          invite_id: string
          inviter_avatar: string
          inviter_id: string
          inviter_name: string
          pairing_code: string
        }[]
      }
      list_my_threads: {
        Args: never
        Returns: {
          dm_other_avatar_url: string
          dm_other_display: string
          dm_other_role: string
          dm_other_user_id: string
          group_gradient_from: string
          group_gradient_to: string
          group_id: string
          group_name: string
          kind: Database["public"]["Enums"]["thread_kind"]
          last_message_at: string
          last_message_body: string
          last_message_sender: string
          small_group_id: string
          small_group_name: string
          thread_id: string
          unread_count: number
        }[]
      }
      longtransactionsenabled: { Args: never; Returns: boolean }
      mark_thread_read: { Args: { _thread_id: string }; Returns: undefined }
      my_event_carousels: { Args: never; Returns: Json }
      pastor_active_user_count: {
        Args: { _pastor_user_id: string }
        Returns: number
      }
      pastor_approve_alert: { Args: { _alert_id: string }; Returns: Json }
      pastor_approve_join_request: {
        Args: { _request_id: string }
        Returns: string
      }
      pastor_archive_feed_post: {
        Args: { _post_id: string }
        Returns: undefined
      }
      pastor_archive_plan: { Args: { _plan_id: string }; Returns: undefined }
      pastor_attach_slideshow_photos: {
        Args: { _photos: Json; _post_id: string }
        Returns: number
      }
      pastor_attach_video_to_post: {
        Args: { _post_id: string; _video_id: string }
        Returns: undefined
      }
      pastor_clear_instagram_source: {
        Args: { _source_id: string }
        Returns: undefined
      }
      pastor_create_feed_slideshow_post: {
        Args: { _caption?: string; _group_id: string; _title?: string }
        Returns: string
      }
      pastor_create_plan:
        | {
            Args: {
              _days: number
              _gradient_idx?: number
              _group_id: string
              _title: string
              _visibility?: string
            }
            Returns: string
          }
        | {
            Args: {
              _additional_group_ids?: string[]
              _days: number
              _gradient_idx?: number
              _group_id: string
              _title: string
              _visibility?: string
            }
            Returns: string
          }
      pastor_dashboard: {
        Args: { _group_id: string }
        Returns: {
          active_last_week: number
          active_last_week_pct: number
          active_this_week: number
          active_this_week_pct: number
          group_id: string
          group_name: string
          logo_url: string
          member_count: number
          pending_request_count: number
          small_group_count: number
          total_group_water: number
          total_group_xp: number
        }[]
      }
      pastor_delete_feed_post: {
        Args: { _post_id: string }
        Returns: undefined
      }
      pastor_delete_plan: { Args: { _plan_id: string }; Returns: undefined }
      pastor_deny_join_request: {
        Args: { _request_id: string }
        Returns: undefined
      }
      pastor_list_group_members: {
        Args: {
          _active_only?: boolean
          _group_id: string
          _role_filter?: string
        }
        Returns: {
          avatar_url: string
          display_name: string
          email: string
          grade_year: number
          is_active_week: boolean
          is_parent: boolean
          joined_at: string
          last_opened_at: string
          linked_child_names: string[]
          role: string
          streak: number
          user_id: string
          water: number
          xp: number
        }[]
      }
      pastor_list_join_requests: {
        Args: { _group_id: string }
        Returns: {
          avatar_url: string
          display_name: string
          email: string
          grade_year: number
          is_parent: boolean
          message: string
          request_id: string
          requested_at: string
          user_id: string
        }[]
      }
      pastor_list_my_plans: {
        Args: never
        Returns: {
          additional_group_ids: string[]
          completed_count: number
          created_at: string
          days_total: number
          gradient_index: number
          group_id: string
          group_name: string
          header_image_url: string
          header_kind: string
          plan_id: string
          published_at: string
          ready_day_count: number
          started_count: number
          status: Database["public"]["Enums"]["bible_plan_status"]
          title: string
          total_blocks: number
          updated_at: string
          visibility: Database["public"]["Enums"]["bible_plan_visibility"]
          water_reward: number
          xp_reward: number
        }[]
      }
      pastor_list_small_groups: {
        Args: { _group_id: string }
        Returns: {
          created_at: string
          description: string
          leader_count: number
          leader_names: string[]
          meeting_day: string
          meeting_time: string
          member_count: number
          name: string
          small_group_id: string
        }[]
      }
      pastor_member_profile: {
        Args: { _group_id: string; _user_id: string }
        Returns: Json
      }
      pastor_moderation_queue: {
        Args: { _group_id: string }
        Returns: {
          alert_id: string
          concern_category: string
          concern_confidence: number
          concern_reason: string
          created_at: string
          message_id: string
          moderation_categories: Json
          moderation_status: string
          preview: string
          recipient_avatar_url: string
          recipient_display_name: string
          recipient_email: string
          recipient_id: string
          recipient_role: string
          sender_avatar_url: string
          sender_display_name: string
          sender_email: string
          sender_id: string
          small_group_id: string
          small_group_name: string
          thread_id: string
          thread_kind: string
        }[]
      }
      pastor_my_groups: {
        Args: never
        Returns: {
          address: string
          group_id: string
          member_count: number
          name: string
        }[]
      }
      pastor_overview_metrics: { Args: { _group_id: string }; Returns: Json }
      pastor_publish_feed_post: {
        Args: { _post_id: string }
        Returns: undefined
      }
      pastor_publish_plan: { Args: { _plan_id: string }; Returns: undefined }
      pastor_recent_activity: {
        Args: { _group_id: string; _limit?: number }
        Returns: {
          avatar_url: string
          display_name: string
          event_id: string
          headline: string
          kind: string
          occurred_at: string
          user_id: string
          xp_delta: number
        }[]
      }
      pastor_reject_alert: { Args: { _alert_id: string }; Returns: Json }
      pastor_set_instagram_source: {
        Args: { _group_id: string; _handle: string }
        Returns: string
      }
      pastor_update_plan_basics:
        | {
            Args: {
              _days?: number
              _gradient_idx?: number
              _group_id?: string
              _header_image_url?: string
              _header_kind?: string
              _plan_id: string
              _title?: string
              _visibility?: string
            }
            Returns: undefined
          }
        | {
            Args: {
              _additional_group_ids?: string[]
              _days?: number
              _gradient_idx?: number
              _group_id?: string
              _header_image_url?: string
              _header_kind?: string
              _plan_id: string
              _title?: string
              _visibility?: string
            }
            Returns: undefined
          }
      pastor_upsert_day: {
        Args: {
          _blocks: Json
          _day_number: number
          _plan_id: string
          _scripture_reference: string
          _title: string
        }
        Returns: string
      }
      pastor_weekly_ranking_history: {
        Args: { _group_id: string; _weeks?: number }
        Returns: {
          active_count: number
          adjusted_xp: number
          class: string
          class_label: string
          multiplier: number
          rank_in_class: number
          total_groups_in_class: number
          week_start: string
          week_xp: number
        }[]
      }
      pastor_weekly_ranking_report: {
        Args: { _group_id: string; _week_start?: string }
        Returns: Json
      }
      populate_geometry_columns:
        | { Args: { tbl_oid: unknown; use_typmod?: boolean }; Returns: number }
        | { Args: { use_typmod?: boolean }; Returns: string }
      postgis_constraint_dims: {
        Args: { geomcolumn: string; geomschema: string; geomtable: string }
        Returns: number
      }
      postgis_constraint_srid: {
        Args: { geomcolumn: string; geomschema: string; geomtable: string }
        Returns: number
      }
      postgis_constraint_type: {
        Args: { geomcolumn: string; geomschema: string; geomtable: string }
        Returns: string
      }
      postgis_extensions_upgrade: { Args: never; Returns: string }
      postgis_full_version: { Args: never; Returns: string }
      postgis_geos_version: { Args: never; Returns: string }
      postgis_lib_build_date: { Args: never; Returns: string }
      postgis_lib_revision: { Args: never; Returns: string }
      postgis_lib_version: { Args: never; Returns: string }
      postgis_libjson_version: { Args: never; Returns: string }
      postgis_liblwgeom_version: { Args: never; Returns: string }
      postgis_libprotobuf_version: { Args: never; Returns: string }
      postgis_libxml_version: { Args: never; Returns: string }
      postgis_proj_version: { Args: never; Returns: string }
      postgis_scripts_build_date: { Args: never; Returns: string }
      postgis_scripts_installed: { Args: never; Returns: string }
      postgis_scripts_released: { Args: never; Returns: string }
      postgis_svn_version: { Args: never; Returns: string }
      postgis_type_name: {
        Args: {
          coord_dimension: number
          geomname: string
          use_new_name?: boolean
        }
        Returns: string
      }
      postgis_version: { Args: never; Returns: string }
      postgis_wagyu_version: { Args: never; Returns: string }
      profile_is_adult: { Args: { _dob: string }; Returns: boolean }
      profile_is_under_13: { Args: { _dob: string }; Returns: boolean }
      public_event_summary: { Args: { _event_id: string }; Returns: Json }
      public_events_nearby: {
        Args: {
          _lat: number
          _limit?: number
          _lng: number
          _radius_m?: number
          _window_days?: number
        }
        Returns: {
          cover_url: string
          description: string
          distance_m: number
          event_id: string
          going_count: number
          group_church_name: string
          group_gradient_from: string
          group_gradient_to: string
          group_id: string
          group_logo_url: string
          group_name: string
          is_my_group_event: boolean
          location: string
          starts_at: string
          title: string
        }[]
      }
      purge_soft_deleted_profiles: { Args: never; Returns: number }
      ranking_top_groups_in_my_class: {
        Args: { _group_id: string; _limit?: number }
        Returns: {
          active_count: number
          adjusted_xp: number
          church_name: string
          class: string
          class_label: string
          gradient_from: string
          gradient_to: string
          group_id: string
          is_my_group: boolean
          logo_url: string
          max_active_in_class: number
          multiplier: number
          name: string
          rank: number
          week_xp: number
        }[]
      }
      ranking_top_groups_overall: {
        Args: { _limit?: number }
        Returns: {
          active_count: number
          church_name: string
          gradient_from: string
          gradient_to: string
          group_id: string
          is_my_group: boolean
          logo_url: string
          name: string
          rank: number
          week_xp: number
        }[]
      }
      ranking_top_users_in_group: {
        Args: { _group_id: string; _limit?: number }
        Returns: {
          avatar_url: string
          display_name: string
          handle: string
          is_me: boolean
          rank: number
          role: string
          user_id: string
          week_xp: number
        }[]
      }
      ranking_top_users_overall: {
        Args: { _limit?: number }
        Returns: {
          avatar_url: string
          display_name: string
          group_id: string
          group_name: string
          handle: string
          is_me: boolean
          rank: number
          user_id: string
          week_xp: number
        }[]
      }
      remove_family: { Args: { _family_id: string }; Returns: undefined }
      request_account_deletion: { Args: never; Returns: undefined }
      request_to_join_group: {
        Args: { _group_id: string; _message?: string }
        Returns: {
          decided_at: string | null
          decided_by: string | null
          group_id: string
          id: string
          message: string | null
          requested_at: string
          status: Database["public"]["Enums"]["join_request_status"]
          user_id: string
        }
        SetofOptions: {
          from: "*"
          to: "youth_group_join_requests"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      respond_to_join_request: {
        Args: { _approve: boolean; _request_id: string }
        Returns: {
          decided_at: string | null
          decided_by: string | null
          group_id: string
          id: string
          message: string | null
          requested_at: string
          status: Database["public"]["Enums"]["join_request_status"]
          user_id: string
        }
        SetofOptions: {
          from: "*"
          to: "youth_group_join_requests"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      rsvp_public_event: {
        Args: { _event_id: string; _status?: string }
        Returns: Json
      }
      save_attendance: {
        Args: { _event_id: string; _records: Json }
        Returns: number
      }
      set_map_visibility: { Args: { _visible: boolean }; Returns: boolean }
      set_member_role: {
        Args: { _group_id: string; _new_role: string; _user_id: string }
        Returns: {
          group_id: string
          id: string
          joined_at: string
          role: string
          user_id: string
        }[]
      }
      share_chat_thread: { Args: { _other_user_id: string }; Returns: boolean }
      snapshot_last_week_rankings: { Args: never; Returns: undefined }
      st_3dclosestpoint: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: unknown
      }
      st_3ddistance: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: number
      }
      st_3dintersects: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      st_3dlongestline: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: unknown
      }
      st_3dmakebox: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: unknown
      }
      st_3dmaxdistance: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: number
      }
      st_3dshortestline: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: unknown
      }
      st_addpoint: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: unknown
      }
      st_angle:
        | { Args: { line1: unknown; line2: unknown }; Returns: number }
        | {
            Args: { pt1: unknown; pt2: unknown; pt3: unknown; pt4?: unknown }
            Returns: number
          }
      st_area:
        | { Args: { geog: unknown; use_spheroid?: boolean }; Returns: number }
        | { Args: { "": string }; Returns: number }
      st_asencodedpolyline: {
        Args: { geom: unknown; nprecision?: number }
        Returns: string
      }
      st_asewkt: { Args: { "": string }; Returns: string }
      st_asgeojson:
        | {
            Args: { geog: unknown; maxdecimaldigits?: number; options?: number }
            Returns: string
          }
        | {
            Args: { geom: unknown; maxdecimaldigits?: number; options?: number }
            Returns: string
          }
        | {
            Args: {
              geom_column?: string
              maxdecimaldigits?: number
              pretty_bool?: boolean
              r: Record<string, unknown>
            }
            Returns: string
          }
        | { Args: { "": string }; Returns: string }
      st_asgml:
        | {
            Args: {
              geog: unknown
              id?: string
              maxdecimaldigits?: number
              nprefix?: string
              options?: number
            }
            Returns: string
          }
        | {
            Args: { geom: unknown; maxdecimaldigits?: number; options?: number }
            Returns: string
          }
        | { Args: { "": string }; Returns: string }
        | {
            Args: {
              geog: unknown
              id?: string
              maxdecimaldigits?: number
              nprefix?: string
              options?: number
              version: number
            }
            Returns: string
          }
        | {
            Args: {
              geom: unknown
              id?: string
              maxdecimaldigits?: number
              nprefix?: string
              options?: number
              version: number
            }
            Returns: string
          }
      st_askml:
        | {
            Args: { geog: unknown; maxdecimaldigits?: number; nprefix?: string }
            Returns: string
          }
        | {
            Args: { geom: unknown; maxdecimaldigits?: number; nprefix?: string }
            Returns: string
          }
        | { Args: { "": string }; Returns: string }
      st_aslatlontext: {
        Args: { geom: unknown; tmpl?: string }
        Returns: string
      }
      st_asmarc21: { Args: { format?: string; geom: unknown }; Returns: string }
      st_asmvtgeom: {
        Args: {
          bounds: unknown
          buffer?: number
          clip_geom?: boolean
          extent?: number
          geom: unknown
        }
        Returns: unknown
      }
      st_assvg:
        | {
            Args: { geog: unknown; maxdecimaldigits?: number; rel?: number }
            Returns: string
          }
        | {
            Args: { geom: unknown; maxdecimaldigits?: number; rel?: number }
            Returns: string
          }
        | { Args: { "": string }; Returns: string }
      st_astext: { Args: { "": string }; Returns: string }
      st_astwkb:
        | {
            Args: {
              geom: unknown
              prec?: number
              prec_m?: number
              prec_z?: number
              with_boxes?: boolean
              with_sizes?: boolean
            }
            Returns: string
          }
        | {
            Args: {
              geom: unknown[]
              ids: number[]
              prec?: number
              prec_m?: number
              prec_z?: number
              with_boxes?: boolean
              with_sizes?: boolean
            }
            Returns: string
          }
      st_asx3d: {
        Args: { geom: unknown; maxdecimaldigits?: number; options?: number }
        Returns: string
      }
      st_azimuth:
        | { Args: { geog1: unknown; geog2: unknown }; Returns: number }
        | { Args: { geom1: unknown; geom2: unknown }; Returns: number }
      st_boundingdiagonal: {
        Args: { fits?: boolean; geom: unknown }
        Returns: unknown
      }
      st_buffer:
        | {
            Args: { geom: unknown; options?: string; radius: number }
            Returns: unknown
          }
        | {
            Args: { geom: unknown; quadsegs: number; radius: number }
            Returns: unknown
          }
      st_centroid: { Args: { "": string }; Returns: unknown }
      st_clipbybox2d: {
        Args: { box: unknown; geom: unknown }
        Returns: unknown
      }
      st_closestpoint: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: unknown
      }
      st_collect: { Args: { geom1: unknown; geom2: unknown }; Returns: unknown }
      st_concavehull: {
        Args: {
          param_allow_holes?: boolean
          param_geom: unknown
          param_pctconvex: number
        }
        Returns: unknown
      }
      st_contains: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      st_containsproperly: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      st_coorddim: { Args: { geometry: unknown }; Returns: number }
      st_coveredby:
        | { Args: { geog1: unknown; geog2: unknown }; Returns: boolean }
        | { Args: { geom1: unknown; geom2: unknown }; Returns: boolean }
      st_covers:
        | { Args: { geog1: unknown; geog2: unknown }; Returns: boolean }
        | { Args: { geom1: unknown; geom2: unknown }; Returns: boolean }
      st_crosses: { Args: { geom1: unknown; geom2: unknown }; Returns: boolean }
      st_curvetoline: {
        Args: { flags?: number; geom: unknown; tol?: number; toltype?: number }
        Returns: unknown
      }
      st_delaunaytriangles: {
        Args: { flags?: number; g1: unknown; tolerance?: number }
        Returns: unknown
      }
      st_difference: {
        Args: { geom1: unknown; geom2: unknown; gridsize?: number }
        Returns: unknown
      }
      st_disjoint: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      st_distance:
        | {
            Args: { geog1: unknown; geog2: unknown; use_spheroid?: boolean }
            Returns: number
          }
        | { Args: { geom1: unknown; geom2: unknown }; Returns: number }
      st_distancesphere:
        | { Args: { geom1: unknown; geom2: unknown }; Returns: number }
        | {
            Args: { geom1: unknown; geom2: unknown; radius: number }
            Returns: number
          }
      st_distancespheroid: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: number
      }
      st_dwithin: {
        Args: {
          geog1: unknown
          geog2: unknown
          tolerance: number
          use_spheroid?: boolean
        }
        Returns: boolean
      }
      st_equals: { Args: { geom1: unknown; geom2: unknown }; Returns: boolean }
      st_expand:
        | { Args: { box: unknown; dx: number; dy: number }; Returns: unknown }
        | {
            Args: { box: unknown; dx: number; dy: number; dz?: number }
            Returns: unknown
          }
        | {
            Args: {
              dm?: number
              dx: number
              dy: number
              dz?: number
              geom: unknown
            }
            Returns: unknown
          }
      st_force3d: { Args: { geom: unknown; zvalue?: number }; Returns: unknown }
      st_force3dm: {
        Args: { geom: unknown; mvalue?: number }
        Returns: unknown
      }
      st_force3dz: {
        Args: { geom: unknown; zvalue?: number }
        Returns: unknown
      }
      st_force4d: {
        Args: { geom: unknown; mvalue?: number; zvalue?: number }
        Returns: unknown
      }
      st_generatepoints:
        | { Args: { area: unknown; npoints: number }; Returns: unknown }
        | {
            Args: { area: unknown; npoints: number; seed: number }
            Returns: unknown
          }
      st_geogfromtext: { Args: { "": string }; Returns: unknown }
      st_geographyfromtext: { Args: { "": string }; Returns: unknown }
      st_geohash:
        | { Args: { geog: unknown; maxchars?: number }; Returns: string }
        | { Args: { geom: unknown; maxchars?: number }; Returns: string }
      st_geomcollfromtext: { Args: { "": string }; Returns: unknown }
      st_geometricmedian: {
        Args: {
          fail_if_not_converged?: boolean
          g: unknown
          max_iter?: number
          tolerance?: number
        }
        Returns: unknown
      }
      st_geometryfromtext: { Args: { "": string }; Returns: unknown }
      st_geomfromewkt: { Args: { "": string }; Returns: unknown }
      st_geomfromgeojson:
        | { Args: { "": Json }; Returns: unknown }
        | { Args: { "": Json }; Returns: unknown }
        | { Args: { "": string }; Returns: unknown }
      st_geomfromgml: { Args: { "": string }; Returns: unknown }
      st_geomfromkml: { Args: { "": string }; Returns: unknown }
      st_geomfrommarc21: { Args: { marc21xml: string }; Returns: unknown }
      st_geomfromtext: { Args: { "": string }; Returns: unknown }
      st_gmltosql: { Args: { "": string }; Returns: unknown }
      st_hasarc: { Args: { geometry: unknown }; Returns: boolean }
      st_hausdorffdistance: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: number
      }
      st_hexagon: {
        Args: { cell_i: number; cell_j: number; origin?: unknown; size: number }
        Returns: unknown
      }
      st_hexagongrid: {
        Args: { bounds: unknown; size: number }
        Returns: Record<string, unknown>[]
      }
      st_interpolatepoint: {
        Args: { line: unknown; point: unknown }
        Returns: number
      }
      st_intersection: {
        Args: { geom1: unknown; geom2: unknown; gridsize?: number }
        Returns: unknown
      }
      st_intersects:
        | { Args: { geog1: unknown; geog2: unknown }; Returns: boolean }
        | { Args: { geom1: unknown; geom2: unknown }; Returns: boolean }
      st_isvaliddetail: {
        Args: { flags?: number; geom: unknown }
        Returns: Database["public"]["CompositeTypes"]["valid_detail"]
        SetofOptions: {
          from: "*"
          to: "valid_detail"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      st_length:
        | { Args: { geog: unknown; use_spheroid?: boolean }; Returns: number }
        | { Args: { "": string }; Returns: number }
      st_letters: { Args: { font?: Json; letters: string }; Returns: unknown }
      st_linecrossingdirection: {
        Args: { line1: unknown; line2: unknown }
        Returns: number
      }
      st_linefromencodedpolyline: {
        Args: { nprecision?: number; txtin: string }
        Returns: unknown
      }
      st_linefromtext: { Args: { "": string }; Returns: unknown }
      st_linelocatepoint: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: number
      }
      st_linetocurve: { Args: { geometry: unknown }; Returns: unknown }
      st_locatealong: {
        Args: { geometry: unknown; leftrightoffset?: number; measure: number }
        Returns: unknown
      }
      st_locatebetween: {
        Args: {
          frommeasure: number
          geometry: unknown
          leftrightoffset?: number
          tomeasure: number
        }
        Returns: unknown
      }
      st_locatebetweenelevations: {
        Args: { fromelevation: number; geometry: unknown; toelevation: number }
        Returns: unknown
      }
      st_longestline: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: unknown
      }
      st_makebox2d: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: unknown
      }
      st_makeline: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: unknown
      }
      st_makevalid: {
        Args: { geom: unknown; params: string }
        Returns: unknown
      }
      st_maxdistance: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: number
      }
      st_minimumboundingcircle: {
        Args: { inputgeom: unknown; segs_per_quarter?: number }
        Returns: unknown
      }
      st_mlinefromtext: { Args: { "": string }; Returns: unknown }
      st_mpointfromtext: { Args: { "": string }; Returns: unknown }
      st_mpolyfromtext: { Args: { "": string }; Returns: unknown }
      st_multilinestringfromtext: { Args: { "": string }; Returns: unknown }
      st_multipointfromtext: { Args: { "": string }; Returns: unknown }
      st_multipolygonfromtext: { Args: { "": string }; Returns: unknown }
      st_node: { Args: { g: unknown }; Returns: unknown }
      st_normalize: { Args: { geom: unknown }; Returns: unknown }
      st_offsetcurve: {
        Args: { distance: number; line: unknown; params?: string }
        Returns: unknown
      }
      st_orderingequals: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      st_overlaps: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: boolean
      }
      st_perimeter: {
        Args: { geog: unknown; use_spheroid?: boolean }
        Returns: number
      }
      st_pointfromtext: { Args: { "": string }; Returns: unknown }
      st_pointm: {
        Args: {
          mcoordinate: number
          srid?: number
          xcoordinate: number
          ycoordinate: number
        }
        Returns: unknown
      }
      st_pointz: {
        Args: {
          srid?: number
          xcoordinate: number
          ycoordinate: number
          zcoordinate: number
        }
        Returns: unknown
      }
      st_pointzm: {
        Args: {
          mcoordinate: number
          srid?: number
          xcoordinate: number
          ycoordinate: number
          zcoordinate: number
        }
        Returns: unknown
      }
      st_polyfromtext: { Args: { "": string }; Returns: unknown }
      st_polygonfromtext: { Args: { "": string }; Returns: unknown }
      st_project: {
        Args: { azimuth: number; distance: number; geog: unknown }
        Returns: unknown
      }
      st_quantizecoordinates: {
        Args: {
          g: unknown
          prec_m?: number
          prec_x: number
          prec_y?: number
          prec_z?: number
        }
        Returns: unknown
      }
      st_reduceprecision: {
        Args: { geom: unknown; gridsize: number }
        Returns: unknown
      }
      st_relate: { Args: { geom1: unknown; geom2: unknown }; Returns: string }
      st_removerepeatedpoints: {
        Args: { geom: unknown; tolerance?: number }
        Returns: unknown
      }
      st_segmentize: {
        Args: { geog: unknown; max_segment_length: number }
        Returns: unknown
      }
      st_setsrid:
        | { Args: { geog: unknown; srid: number }; Returns: unknown }
        | { Args: { geom: unknown; srid: number }; Returns: unknown }
      st_sharedpaths: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: unknown
      }
      st_shortestline: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: unknown
      }
      st_simplifypolygonhull: {
        Args: { geom: unknown; is_outer?: boolean; vertex_fraction: number }
        Returns: unknown
      }
      st_split: { Args: { geom1: unknown; geom2: unknown }; Returns: unknown }
      st_square: {
        Args: { cell_i: number; cell_j: number; origin?: unknown; size: number }
        Returns: unknown
      }
      st_squaregrid: {
        Args: { bounds: unknown; size: number }
        Returns: Record<string, unknown>[]
      }
      st_srid:
        | { Args: { geog: unknown }; Returns: number }
        | { Args: { geom: unknown }; Returns: number }
      st_subdivide: {
        Args: { geom: unknown; gridsize?: number; maxvertices?: number }
        Returns: unknown[]
      }
      st_swapordinates: {
        Args: { geom: unknown; ords: unknown }
        Returns: unknown
      }
      st_symdifference: {
        Args: { geom1: unknown; geom2: unknown; gridsize?: number }
        Returns: unknown
      }
      st_symmetricdifference: {
        Args: { geom1: unknown; geom2: unknown }
        Returns: unknown
      }
      st_tileenvelope: {
        Args: {
          bounds?: unknown
          margin?: number
          x: number
          y: number
          zoom: number
        }
        Returns: unknown
      }
      st_touches: { Args: { geom1: unknown; geom2: unknown }; Returns: boolean }
      st_transform:
        | {
            Args: { from_proj: string; geom: unknown; to_proj: string }
            Returns: unknown
          }
        | {
            Args: { from_proj: string; geom: unknown; to_srid: number }
            Returns: unknown
          }
        | { Args: { geom: unknown; to_proj: string }; Returns: unknown }
      st_triangulatepolygon: { Args: { g1: unknown }; Returns: unknown }
      st_union:
        | { Args: { geom1: unknown; geom2: unknown }; Returns: unknown }
        | {
            Args: { geom1: unknown; geom2: unknown; gridsize: number }
            Returns: unknown
          }
      st_voronoilines: {
        Args: { extend_to?: unknown; g1: unknown; tolerance?: number }
        Returns: unknown
      }
      st_voronoipolygons: {
        Args: { extend_to?: unknown; g1: unknown; tolerance?: number }
        Returns: unknown
      }
      st_within: { Args: { geom1: unknown; geom2: unknown }; Returns: boolean }
      st_wkbtosql: { Args: { wkb: string }; Returns: unknown }
      st_wkttosql: { Args: { "": string }; Returns: unknown }
      st_wrapx: {
        Args: { geom: unknown; move: number; wrap: number }
        Returns: unknown
      }
      start_family: { Args: { _name?: string }; Returns: string }
      submit_youth_group_request: {
        Args: {
          _church_name: string
          _pastor_email: string
          _pastor_name: string
        }
        Returns: {
          church_name: string
          converted_at: string | null
          created_at: string
          decided_at: string | null
          decided_by: string | null
          email_provider_id: string | null
          emailed_at: string | null
          followup_count: number
          id: string
          last_followup_at: string | null
          lead_stage: string
          lost_at: string | null
          lost_reason: string | null
          notes: string | null
          pastor_email: string
          pastor_name: string
          pastor_phone: string | null
          referral_channel: string | null
          status: Database["public"]["Enums"]["group_submission_status"]
          submitter_email: string | null
          submitter_id: string | null
        }
        SetofOptions: {
          from: "*"
          to: "youth_group_submissions"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      target_tier_for_count: { Args: { _count: number }; Returns: string }
      thread_group_id: { Args: { _thread_id: string }; Returns: string }
      try_parse_uuid: { Args: { _s: string }; Returns: string }
      unlockrows: { Args: { "": string }; Returns: number }
      update_managed_profile: {
        Args: {
          _avatar_url?: string
          _bio?: string
          _display_name?: string
          _target_user_id: string
        }
        Returns: {
          age_band: string | null
          age_verified_at: string | null
          avatar_url: string | null
          bio: string | null
          created_at: string
          current_streak_run_id: string | null
          date_of_birth: string | null
          deleted_at: string | null
          display_name: string | null
          email: string | null
          grade_year: number | null
          handle: string
          id: string
          is_managed_child: boolean
          is_visible_on_map: boolean
          last_opened_at: string
          last_streak_date: string | null
          lifetime_xp: number
          parent_account_id: string | null
          streak: number
          updated_at: string
          water: number
          xp: number
        }
        SetofOptions: {
          from: "*"
          to: "profiles"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      updategeometrysrid: {
        Args: {
          catalogn_name: string
          column_name: string
          new_srid_in: number
          schema_name: string
          table_name: string
        }
        Returns: string
      }
      xp_class_for: { Args: { _active_count: number }; Returns: string }
      xp_for_level: { Args: { _level: number }; Returns: number }
      youth_group_public_profile: {
        Args: { _group_id: string }
        Returns: {
          address: string
          church_name: string
          description: string
          grades: number[]
          gradient_from: string
          gradient_to: string
          group_type: string
          id: string
          latitude: number
          leaders: Json
          logo_url: string
          longitude: number
          meeting_time: string
          member_count: number
          name: string
          small_group_count: number
          upcoming_events: Json
          viewer_is_member: boolean
          viewer_pending_request: boolean
        }[]
      }
      youth_groups_near: {
        Args: { _lat: number; _lng: number; _meters?: number }
        Returns: {
          address: string
          church_name: string
          description: string
          distance_m: number
          grades: number[]
          gradient_from: string
          gradient_to: string
          group_type: string
          id: string
          latitude: number
          logo_url: string
          longitude: number
          meeting_time: string
          member_count: number
          name: string
          small_group_count: number
        }[]
      }
    }
    Enums: {
      app_role: "site_admin" | "pastor" | "leader" | "member" | "parent"
      bible_plan_category:
        | "book_study"
        | "thematic"
        | "devotional"
        | "group_plan"
      bible_plan_scope: "global" | "group"
      bible_plan_status: "draft" | "published" | "archived"
      bible_plan_step:
        | "read"
        | "study"
        | "apply"
        | "give"
        | "memorize"
        | "pray"
        | "commentary"
        | "video"
        | "question"
      bible_plan_visibility: "private" | "public"
      event_media_kind: "photo" | "video"
      event_rsvp_audience: "members_only" | "public"
      event_visibility: "public" | "groupPrivate"
      flag_severity: "low" | "medium" | "high"
      flag_status: "open" | "dismissed" | "removed"
      group_role: "pastor" | "leader" | "member"
      group_submission_status: "pending" | "contacted" | "approved" | "rejected"
      item_rarity: "common" | "rare" | "epic" | "legendary"
      item_type: "plant" | "decor"
      join_request_status: "pending" | "approved" | "denied" | "cancelled"
      moderation_status: "clean" | "flagged_allowed" | "flagged_blocked"
      pastor_signup_stage:
        | "account"
        | "group"
        | "brand"
        | "tours"
        | "pricing"
        | "checkout"
        | "converted"
        | "abandoned"
      rsvp_status: "going" | "maybe" | "declined"
      small_group_role: "member" | "leader"
      stripe_subscription_status:
        | "trialing"
        | "active"
        | "past_due"
        | "canceled"
        | "incomplete"
        | "incomplete_expired"
        | "unpaid"
        | "paused"
      thread_kind:
        | "group_main"
        | "small_group"
        | "parent_chat"
        | "dm_pastor"
        | "dm_leader"
        | "dm_parent_pastor"
        | "dm_parent_leader"
      thread_moderation_policy: "block" | "allow_alert"
      video_policy: "public" | "signed"
      video_scope: "global" | "youthGroup" | "plan"
      video_status: "uploading" | "processing" | "ready" | "errored"
    }
    CompositeTypes: {
      geometry_dump: {
        path: number[] | null
        geom: unknown
      }
      valid_detail: {
        valid: boolean | null
        reason: string | null
        location: unknown
      }
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {
      app_role: ["site_admin", "pastor", "leader", "member", "parent"],
      bible_plan_category: [
        "book_study",
        "thematic",
        "devotional",
        "group_plan",
      ],
      bible_plan_scope: ["global", "group"],
      bible_plan_status: ["draft", "published", "archived"],
      bible_plan_step: [
        "read",
        "study",
        "apply",
        "give",
        "memorize",
        "pray",
        "commentary",
        "video",
        "question",
      ],
      bible_plan_visibility: ["private", "public"],
      event_media_kind: ["photo", "video"],
      event_rsvp_audience: ["members_only", "public"],
      event_visibility: ["public", "groupPrivate"],
      flag_severity: ["low", "medium", "high"],
      flag_status: ["open", "dismissed", "removed"],
      group_role: ["pastor", "leader", "member"],
      group_submission_status: ["pending", "contacted", "approved", "rejected"],
      item_rarity: ["common", "rare", "epic", "legendary"],
      item_type: ["plant", "decor"],
      join_request_status: ["pending", "approved", "denied", "cancelled"],
      moderation_status: ["clean", "flagged_allowed", "flagged_blocked"],
      pastor_signup_stage: [
        "account",
        "group",
        "brand",
        "tours",
        "pricing",
        "checkout",
        "converted",
        "abandoned",
      ],
      rsvp_status: ["going", "maybe", "declined"],
      small_group_role: ["member", "leader"],
      stripe_subscription_status: [
        "trialing",
        "active",
        "past_due",
        "canceled",
        "incomplete",
        "incomplete_expired",
        "unpaid",
        "paused",
      ],
      thread_kind: [
        "group_main",
        "small_group",
        "parent_chat",
        "dm_pastor",
        "dm_leader",
        "dm_parent_pastor",
        "dm_parent_leader",
      ],
      thread_moderation_policy: ["block", "allow_alert"],
      video_policy: ["public", "signed"],
      video_scope: ["global", "youthGroup", "plan"],
      video_status: ["uploading", "processing", "ready", "errored"],
    },
  },
} as const
