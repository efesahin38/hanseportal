-- This script adds the necessary columns to the gws_daily_plans table to support external manager comments and signatures.
-- Please run this script in your Supabase SQL Editor.

ALTER TABLE public.gws_daily_plans 
ADD COLUMN IF NOT EXISTS ext_manager_comment text,
ADD COLUMN IF NOT EXISTS ext_manager_signature text;
