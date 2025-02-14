# local client to be used in tests and also
# dev env
defmodule SupabasePotion.Client do
  @moduledoc false
  use Supabase.Client, otp_app: :supabase_potion
end
