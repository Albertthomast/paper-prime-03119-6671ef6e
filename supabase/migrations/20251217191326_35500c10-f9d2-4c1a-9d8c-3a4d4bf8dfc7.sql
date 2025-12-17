-- Add post-GST discount columns to invoices table
ALTER TABLE public.invoices 
ADD COLUMN IF NOT EXISTS post_gst_discount_enabled boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS post_gst_discount_name text DEFAULT 'Advance Received',
ADD COLUMN IF NOT EXISTS post_gst_discount_amount numeric DEFAULT 0;