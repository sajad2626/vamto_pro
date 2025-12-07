
-- sql/setup.sql

-- Run this in Supabase SQL editor.

-- Creates tables and enables RLS; write operations are intended via server API (service role).

create table if not exists users_vamto (

  id serial primary key,

  phone text unique not null,

  password text not null,

  fullname text,

  role text default 'user',

  created_at timestamptz default now()

);

create table if not exists bank_logos (

  id serial primary key,

  title text,

  image_url text,

  created_at timestamptz default now()

);

create table if not exists loans_vamto (

  id serial primary key,

  title text not null,

  amount bigint,

  installments int,

  price bigint,

  bank_logo text,

  is_credit boolean default false,

  created_at timestamptz default now()

);

create table if not exists reservations (

  id serial primary key,

  user_id int references users_vamto(id) on delete set null,

  loan_id int references loans_vamto(id) on delete set null,

  fullname text,

  phone text,

  status text default 'pending',

  created_at timestamptz default now()

);

-- Enable RLS

alter table users_vamto enable row level security;

alter table bank_logos enable row level security;

alter table loans_vamto enable row level security;

alter table reservations enable row level security;

-- Public read for loans & logos

create policy if not exists "public_select_loans" on loans_vamto for select using (true);

create policy if not exists "public_select_logos" on bank_logos for select using (true);

-- Disable direct writes from anon by not adding insert policies here.

-- We use server API (SERVICE ROLE) to perform inserts/updates/deletes.

