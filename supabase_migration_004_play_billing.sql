-- BOSYN: MIGRATION 004 - Assinatura PRO pelo Google Play Billing
-- ------------------------------------------------------------------------------------
-- Aplicar no SQL Editor do Supabase DEPOIS da 003 e ANTES de vender a assinatura (o schema é
-- gerido fora do repo — AGENTS.md seção 2, item 5). Idempotente.
--
-- O que muda:
--   1. `profiles.subscription_expires_at`: até quando vale o PRO comprado na Play. O app só
--      libera o PRO com `subscription_status <> 'free'` e esta data no futuro (ou nula).
--   2. O trigger da 003 passa a proteger também a validade: o cliente não estende o próprio PRO.
--   3. `play_subscriptions`: cada compra confirmada pelo servidor (token da Play → usuário).
--      Impede que o mesmo token libere o PRO em duas contas e permite que as notificações da
--      Play (renovação, cancelamento, reembolso) achem o dono da compra. Só as Edge Functions
--      `play-subscription` e `play-rtdn` (chave secreta) leem e escrevem nela.
--
-- Valores de `subscription_status`:
--   'free'  — sem PRO.
--   'pro'   — PRO pela Play; quem escreve é a Edge Function (supabase/functions/_shared/).
--   'elite' — PRO dado à mão (cortesia, parceiros), sem validade. A sincronização com a Play
--             nunca mexe em 'elite'.

begin;

-- 1. Validade do PRO comprado na loja.
alter table public.profiles add column if not exists subscription_expires_at timestamptz;

-- 2. Plano e validade são decididos pelo servidor (mesma regra da 003, agora com a validade).
create or replace function public.profiles_protect_subscription()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if current_user in ('anon', 'authenticated') then
    if tg_op = 'INSERT' then
      new.subscription_status := 'free';
      new.subscription_expires_at := null;
    else
      new.subscription_status := old.subscription_status;
      new.subscription_expires_at := old.subscription_expires_at;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_protect_subscription on public.profiles;
create trigger profiles_protect_subscription
  before insert or update on public.profiles
  for each row execute function public.profiles_protect_subscription();

-- 3. Compras confirmadas na Google Play Developer API.
create table if not exists public.play_subscriptions (
  purchase_token text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  product_id text not null,
  -- subscriptionState da API (SUBSCRIPTION_STATE_ACTIVE, ..._CANCELED, ..._EXPIRED etc.) ou
  -- 'SUPERSEDED' quando uma troca de plano gerou um token novo (linkedPurchaseToken).
  subscription_state text not null,
  expires_at timestamptz,
  auto_renewing boolean not null default false,
  linked_purchase_token text,
  latest_order_id text,
  -- Compra de testador de licença (Play Console → Teste de licença): não é cobrada.
  test_purchase boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_play_subscriptions_user_id on public.play_subscriptions (user_id);

-- RLS ligada e nenhum acesso para o app: o cliente vê o próprio plano em `profiles`.
alter table public.play_subscriptions enable row level security;
revoke all on public.play_subscriptions from anon, authenticated;

commit;

-- Conferência rápida depois de aplicar:
--   select column_name from information_schema.columns
--    where table_schema = 'public' and table_name = 'profiles' and column_name = 'subscription_expires_at';
--   select relrowsecurity from pg_class where oid = 'public.play_subscriptions'::regclass;  -- true
