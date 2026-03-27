-- Crixly licensing tables

create table if not exists public.licenses (
  id uuid primary key default gen_random_uuid(),
  key text not null unique,
  status text not null default 'active', -- active|revoked|expired
  plan text,
  expires_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.activations (
  id uuid primary key default gen_random_uuid(),
  license_id uuid not null references public.licenses(id) on delete cascade,
  fingerprint text not null,
  activated_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  -- One license key -> one machine
  constraint activations_one_per_license unique (license_id),
  constraint activations_fingerprint_nonempty check (length(fingerprint) > 8)
);

create index if not exists activations_fingerprint_idx on public.activations(fingerprint);

-- Enable RLS (tables are not intended to be queried directly by anon; Edge Function uses service role)
alter table public.licenses enable row level security;
alter table public.activations enable row level security;

-- No policies by default.
