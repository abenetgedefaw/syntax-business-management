-- Syntax Technology Business Management System
-- Patch for the connected app.
-- Run this once in Supabase SQL Editor after the original schema.

-- Make the app able to access the tables as an authenticated client.
grant select, insert, update, delete on all tables in schema public to authenticated;
grant usage on schema public to authenticated;

-- Automatically create a profile whenever a Supabase Auth user signs up.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, phone, role, status)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', split_part(coalesce(new.email, 'User'), '@', 1)),
    new.raw_user_meta_data->>'phone',
    'employee',
    'active'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

-- Atomic inventory adjustment: incoming adds stock, used subtracts stock.
create or replace function public.adjust_inventory(
  p_inventory_id uuid,
  p_transaction_type text,
  p_quantity numeric,
  p_reason text default null
)
returns public.inventory
language plpgsql
security invoker
as $$
declare
  v_item public.inventory;
  v_new_stock numeric;
begin
  if p_quantity <= 0 then
    raise exception 'Quantity must be greater than zero';
  end if;

  select * into v_item from public.inventory where id = p_inventory_id for update;
  if not found then
    raise exception 'Inventory item not found';
  end if;

  if p_transaction_type = 'incoming' then
    v_new_stock := v_item.current_stock + p_quantity;
  elsif p_transaction_type = 'used' then
    v_new_stock := v_item.current_stock - p_quantity;
    if v_new_stock < 0 then
      raise exception 'Insufficient stock';
    end if;
  elsif p_transaction_type = 'adjustment' then
    v_new_stock := p_quantity;
  else
    raise exception 'Invalid transaction type';
  end if;

  update public.inventory
  set current_stock = v_new_stock
  where id = p_inventory_id
  returning * into v_item;

  insert into public.stock_transactions (inventory_id, transaction_type, quantity, reason)
  values (p_inventory_id, p_transaction_type, p_quantity, p_reason);

  if v_item.maximum_capacity > 0
     and v_new_stock <= v_item.maximum_capacity * (v_item.threshold_percent / 100.0) then
    insert into public.notifications (title, message, notification_type, reference_id)
    values (
      'Low Stock Alert',
      v_item.name || ' is at ' || v_new_stock || ' ' || v_item.unit || ' (threshold ' ||
      round(v_item.maximum_capacity * (v_item.threshold_percent / 100.0), 2) || ').',
      'low_stock',
      v_item.id
    );
  end if;

  return v_item;
end;
$$;

grant execute on function public.adjust_inventory(uuid, text, numeric, text) to authenticated;

-- Optional: create an admin after you create your first account.
-- Replace the UUID below with the Auth user's UUID, then run:
-- update public.profiles set role='admin' where id='YOUR-USER-UUID';
