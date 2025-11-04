
-- Migration: 20251101115158
-- Create company_settings table for storing default business information
CREATE TABLE public.company_settings (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  company_name TEXT NOT NULL,
  company_email TEXT,
  company_phone TEXT,
  company_address TEXT,
  gst_enabled BOOLEAN NOT NULL DEFAULT true,
  gst_rate DECIMAL(5,2) NOT NULL DEFAULT 10.00,
  default_payment_terms TEXT DEFAULT 'Due within 30 days',
  next_invoice_number INTEGER NOT NULL DEFAULT 1,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Create invoices table
CREATE TABLE public.invoices (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  invoice_number TEXT NOT NULL UNIQUE,
  invoice_type TEXT NOT NULL CHECK (invoice_type IN ('invoice', 'quote')),
  invoice_date DATE NOT NULL,
  due_date DATE,
  status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'sent', 'paid', 'overdue')),
  client_name TEXT NOT NULL,
  client_email TEXT,
  client_address TEXT,
  subtotal DECIMAL(12,2) NOT NULL DEFAULT 0,
  gst_enabled BOOLEAN NOT NULL DEFAULT true,
  gst_amount DECIMAL(12,2) NOT NULL DEFAULT 0,
  total DECIMAL(12,2) NOT NULL DEFAULT 0,
  payment_terms TEXT,
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Create line_items table for invoice items
CREATE TABLE public.line_items (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  invoice_id UUID NOT NULL REFERENCES public.invoices(id) ON DELETE CASCADE,
  description TEXT NOT NULL,
  quantity DECIMAL(10,2) NOT NULL DEFAULT 1,
  rate DECIMAL(12,2) NOT NULL DEFAULT 0,
  amount DECIMAL(12,2) NOT NULL DEFAULT 0,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.company_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.line_items ENABLE ROW LEVEL SECURITY;

-- Create policies for public access (since this is a single-user invoice generator)
CREATE POLICY "Anyone can view company settings" ON public.company_settings FOR SELECT USING (true);
CREATE POLICY "Anyone can update company settings" ON public.company_settings FOR UPDATE USING (true);
CREATE POLICY "Anyone can insert company settings" ON public.company_settings FOR INSERT WITH CHECK (true);

CREATE POLICY "Anyone can view invoices" ON public.invoices FOR SELECT USING (true);
CREATE POLICY "Anyone can create invoices" ON public.invoices FOR INSERT WITH CHECK (true);
CREATE POLICY "Anyone can update invoices" ON public.invoices FOR UPDATE USING (true);
CREATE POLICY "Anyone can delete invoices" ON public.invoices FOR DELETE USING (true);

CREATE POLICY "Anyone can view line items" ON public.line_items FOR SELECT USING (true);
CREATE POLICY "Anyone can create line items" ON public.line_items FOR INSERT WITH CHECK (true);
CREATE POLICY "Anyone can update line items" ON public.line_items FOR UPDATE USING (true);
CREATE POLICY "Anyone can delete line items" ON public.line_items FOR DELETE USING (true);

-- Create function to update timestamps
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for automatic timestamp updates
CREATE TRIGGER update_company_settings_updated_at
BEFORE UPDATE ON public.company_settings
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_invoices_updated_at
BEFORE UPDATE ON public.invoices
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at_column();

-- Insert default company settings
INSERT INTO public.company_settings (company_name, gst_enabled, gst_rate, default_payment_terms)
VALUES ('Your Company Name', true, 10.00, 'Due within 30 days');

-- Migration: 20251101120150
-- Add currency and logo support to company_settings
ALTER TABLE public.company_settings
ADD COLUMN currency TEXT NOT NULL DEFAULT 'USD',
ADD COLUMN logo_url TEXT;

-- Add currency to invoices
ALTER TABLE public.invoices
ADD COLUMN currency TEXT NOT NULL DEFAULT 'USD';

-- Create clients table for reusable client details
CREATE TABLE public.clients (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT,
  phone TEXT,
  address TEXT,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Enable RLS on clients
ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;

-- Create policies for clients
CREATE POLICY "Anyone can view clients" 
ON public.clients 
FOR SELECT 
USING (true);

CREATE POLICY "Anyone can create clients" 
ON public.clients 
FOR INSERT 
WITH CHECK (true);

CREATE POLICY "Anyone can update clients" 
ON public.clients 
FOR UPDATE 
USING (true);

CREATE POLICY "Anyone can delete clients" 
ON public.clients 
FOR DELETE 
USING (true);

-- Add trigger for clients updated_at
CREATE TRIGGER update_clients_updated_at
BEFORE UPDATE ON public.clients
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at_column();

-- Create storage bucket for company logos
INSERT INTO storage.buckets (id, name, public) 
VALUES ('company-logos', 'company-logos', true)
ON CONFLICT (id) DO NOTHING;

-- Create storage policies for company logos
CREATE POLICY "Anyone can view company logos" 
ON storage.objects 
FOR SELECT 
USING (bucket_id = 'company-logos');

CREATE POLICY "Anyone can upload company logos" 
ON storage.objects 
FOR INSERT 
WITH CHECK (bucket_id = 'company-logos');

CREATE POLICY "Anyone can update company logos" 
ON storage.objects 
FOR UPDATE 
USING (bucket_id = 'company-logos');

CREATE POLICY "Anyone can delete company logos" 
ON storage.objects 
FOR DELETE 
USING (bucket_id = 'company-logos');

-- Migration: 20251102165901
-- Add GST and PAN number fields to clients table
ALTER TABLE public.clients 
ADD COLUMN gst_number TEXT,
ADD COLUMN pan_number TEXT;

-- Add GST, PAN, and bank account details to company_settings table
ALTER TABLE public.company_settings
ADD COLUMN gst_number TEXT,
ADD COLUMN pan_number TEXT,
ADD COLUMN account_number TEXT,
ADD COLUMN ifsc_code TEXT,
ADD COLUMN bank_name TEXT,
ADD COLUMN next_quotation_number INTEGER NOT NULL DEFAULT 1;

-- Add client GST and PAN to invoices table for historical record
ALTER TABLE public.invoices
ADD COLUMN client_gst_number TEXT,
ADD COLUMN client_pan_number TEXT;

-- Migration: 20251103052020
-- Add next_proforma_number to company_settings
ALTER TABLE public.company_settings 
ADD COLUMN IF NOT EXISTS next_proforma_number integer NOT NULL DEFAULT 1;

-- Migration: 20251104043514
-- Add unit column to line_items table
ALTER TABLE public.line_items
ADD COLUMN unit text NOT NULL DEFAULT 'item';

-- Add custom_units column to company_settings table
ALTER TABLE public.company_settings
ADD COLUMN custom_units text[] DEFAULT ARRAY[]::text[];

-- Migration: 20251104043546
-- Fix the search_path for the existing function to make it immutable
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql 
SET search_path = public;
