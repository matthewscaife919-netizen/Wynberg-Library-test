-- Run once in Supabase: SQL Editor > New query > paste > Run.
create table if not exists pickups (
  email text not null, book_id bigint not null, day text not null, slot text not null,
  primary key (email, book_id)
);
alter table pickups enable row level security; -- no policies: only the functions below can touch it

create or replace function set_pickup(p_book bigint, p_day text, p_slot text) returns void
language plpgsql security definer set search_path = public as $$
declare em text := lower(auth.jwt() ->> 'email');
begin
  if em is null then raise exception 'Sign in first'; end if;
  if p_day not in ('Monday','Tuesday','Wednesday','Thursday') or p_slot not in ('10:35 am','1:05 pm') then
    raise exception 'Invalid pick-up time';
  end if;
  insert into pickups(email, book_id, day, slot) values (em, p_book, p_day, p_slot)
  on conflict (email, book_id) do update set day = excluded.day, slot = excluded.slot;
end $$;

create or replace function my_pickups() returns json
language sql security definer set search_path = public as $$
  select coalesce(json_agg(p), '[]'::json) from pickups p where p.email = lower(auth.jwt() ->> 'email');
$$;

-- admin_all raises an error for a wrong password or a non-admin account, so it doubles as the check.
create or replace function admin_pickups(p_pw text) returns json
language plpgsql security definer set search_path = public as $$
begin
  perform admin_all(p_pw);
  return (select coalesce(json_agg(p), '[]'::json) from pickups p);
end $$;

grant execute on function set_pickup(bigint,text,text) to authenticated;
grant execute on function my_pickups() to authenticated;
grant execute on function admin_pickups(text) to anon, authenticated;
