-- BOSYN: MIGRATION 003 - Endurecimento de segurança para publicação (Google Play / LGPD)
-- ------------------------------------------------------------------------------------
-- Aplicar no SQL Editor do Supabase ANTES de publicar o app (o schema é gerido fora do repo —
-- AGENTS.md seção 2, item 5). Idempotente: rodar de novo não causa efeito colateral.
--
-- O que muda:
--   1. `profiles` existe com as colunas que o app usa (antes não estava em nenhuma migration).
--   2. O plano (`subscription_status`) só muda pelo servidor. Antes, qualquer usuário podia se
--      dar PRO com um UPDATE direto na API.
--   3. O perfil é criado pelo banco no cadastro (trigger), não pelo app.
--   4. Excluir o usuário apaga os dados clínicos junto (FKs para auth.users com ON DELETE
--      CASCADE) — usado pela Edge Function `delete-account`.
--   5. RLS no padrão recomendado (TO authenticated + (select auth.uid())). ATENÇÃO: as políticas
--      EXISTENTES das 6 tabelas abaixo são substituídas por este conjunto canônico.
--   6. O papel `anon` perde acesso às tabelas clínicas (o app não tem uso sem login).

begin;

-- 1. Tabela de perfil usada pelo app (lib/services/supabase_service.dart, gatekeeper_service.dart)
create table if not exists public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  subscription_status text not null default 'free',
  onboarding_completed boolean not null default false,
  gamification_data jsonb,
  created_at timestamptz not null default now()
);
alter table public.profiles add column if not exists subscription_status text not null default 'free';
alter table public.profiles add column if not exists onboarding_completed boolean not null default false;
alter table public.profiles add column if not exists gamification_data jsonb;

-- 2. Plano é decidido pelo servidor. Papéis do cliente (anon/authenticated) não escolhem o
--    próprio plano; service_role (confirmação de compra no servidor) e o painel/SQL Editor podem.
create or replace function public.profiles_protect_subscription()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if current_user in ('anon', 'authenticated') then
    if tg_op = 'INSERT' then
      new.subscription_status := 'free';
    else
      new.subscription_status := old.subscription_status;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_protect_subscription on public.profiles;
create trigger profiles_protect_subscription
  before insert or update on public.profiles
  for each row execute function public.profiles_protect_subscription();

-- 3. Perfil criado no cadastro. Nunca bloqueia o cadastro: se falhar, o app cria o perfil no
--    primeiro login (SupabaseService.loadOnboardingCompleted).
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  begin
    insert into public.profiles (user_id) values (new.id) on conflict do nothing;
  exception when others then
    raise warning 'handle_new_user: perfil não criado para %: %', new.id, sqlerrm;
  end;
  return new;
end;
$$;

revoke execute on function public.handle_new_user() from public, anon, authenticated;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- 4. Toda FK de public.* para auth.users passa a ser ON DELETE CASCADE.
do $$
declare
  fk record;
  definition text;
begin
  for fk in
    select con.conname, cl.relname as table_name, pg_get_constraintdef(con.oid) as def
    from pg_constraint con
    join pg_class cl on cl.oid = con.conrelid
    join pg_namespace ns on ns.oid = cl.relnamespace
    where con.contype = 'f'
      and ns.nspname = 'public'
      and con.confrelid = 'auth.users'::regclass
      and con.confdeltype <> 'c'
  loop
    definition := regexp_replace(
      fk.def,
      '\s+ON DELETE\s+(SET NULL|SET DEFAULT|RESTRICT|NO ACTION)(\s*\([^)]*\))?',
      '',
      'i'
    );
    execute format('alter table public.%I drop constraint %I', fk.table_name, fk.conname);
    execute format('alter table public.%I add constraint %I %s on delete cascade',
                   fk.table_name, fk.conname, definition);
  end loop;
end;
$$;

-- 5 e 6. RLS canônica + sem acesso anônimo. Tabelas ausentes neste projeto são puladas.
do $$
declare
  t text;
  p record;
  own text := '(select auth.uid()) = user_id';
begin
  foreach t in array array['profiles', 'audiograms', 'rehab_sessions', 'stimulus_results',
                           'user_profiles', 'rehab_progress']
  loop
    if to_regclass('public.' || t) is null then
      raise notice 'tabela public.% não existe — pulando', t;
      continue;
    end if;

    for p in select policyname from pg_policies where schemaname = 'public' and tablename = t loop
      execute format('drop policy %I on public.%I', p.policyname, t);
    end loop;

    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from anon', t);

    if t = 'profiles' then
      -- Sem DELETE pelo cliente: a conta inteira sai pela Edge Function delete-account.
      execute format('grant select, insert, update on public.%I to authenticated', t);
      execute format('create policy "profiles_select_own" on public.%I for select to authenticated using (%s)', t, own);
      execute format('create policy "profiles_insert_own" on public.%I for insert to authenticated with check (%s)', t, own);
      execute format('create policy "profiles_update_own" on public.%I for update to authenticated using (%s) with check (%s)', t, own, own);
    elsif t = 'audiograms' then
      -- Mantém o desenho original: audiograma não é editado, só criado, lido e apagado.
      execute format('grant select, insert, delete on public.%I to authenticated', t);
      execute format('create policy "audiograms_select_own" on public.%I for select to authenticated using (%s)', t, own);
      execute format('create policy "audiograms_insert_own" on public.%I for insert to authenticated with check (%s)', t, own);
      execute format('create policy "audiograms_delete_own" on public.%I for delete to authenticated using (%s)', t, own);
    else
      execute format('grant select, insert, update, delete on public.%I to authenticated', t);
      execute format('create policy "%s_own_rows" on public.%I for all to authenticated using (%s) with check (%s)', t, t, own, own);
    end if;

    -- Índice na coluna das políticas (recomendação do Supabase para RLS).
    execute format('create index if not exists %I on public.%I (user_id)', 'idx_' || t || '_user_id', t);
  end loop;
end;
$$;

commit;

-- Conferência rápida depois de aplicar:
--   select tablename, policyname, roles, cmd from pg_policies where schemaname = 'public' order by 1;
--   Database → Advisors → Security Advisor: deve ficar sem alertas para estas tabelas.
