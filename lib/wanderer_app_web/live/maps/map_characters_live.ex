defmodule WandererAppWeb.MapCharactersLive do
  use WandererAppWeb, :live_view

  require Logger

  alias WandererAppWeb.MapCharacters

  def mount(
        %{"slug" => map_slug} = _params,
        _session,
        %{assigns: %{current_user: current_user}} = socket
      ) do
    WandererApp.Maps.check_user_can_delete_map(map_slug, current_user)
    |> case do
      {:ok,
       %{
         id: map_id,
         name: map_name
       } = _map} ->
        {:ok,
         socket
         |> assign(
           map_id: map_id,
           map_name: map_name,
           map_slug: map_slug
         )
         |> assign(:groups, [])}

      _ ->
        {:ok,
         socket
         |> put_flash(:error, "You don't have an access.")
         |> push_navigate(to: ~p"/maps")}
    end
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(user_id: nil)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  @impl true
  def handle_info(
        _event,
        socket
      ) do
    {:noreply, socket}
  end

  def handle_event(
        "untrack",
        %{"event-data" => character_id},
        %{
          assigns: %{
            map_id: map_id,
            current_user: _current_user,
            character_settings: character_settings
          }
        } = socket
      ) do
    socket =
      character_settings
      |> Enum.find(&(&1.character_id == character_id))
      |> case do
        nil ->
          socket

        character_setting ->
          case character_setting.tracked do
            true ->
              {:ok, map_character_settings} =
                character_setting
                |> WandererApp.MapCharacterSettingsRepo.untrack()

              WandererApp.Map.Server.remove_character(map_id, map_character_settings.character_id)

              socket |> put_flash(:info, "Character untracked!") |> load_characters()

            _ ->
              socket
          end
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("noop", _, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event(event, body, socket) do
    Logger.warning(fn -> "unhandled event: #{event} #{inspect(body)}" end)
    {:noreply, socket}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:active_page, :map_characters)
    |> assign(:page_title, "Map - Characters")
    |> load_characters()
  end

  defp load_characters(%{assigns: %{map_id: map_id}} = socket) do
    map_characters =
      map_id
      |> WandererApp.Map.list_characters()
      |> Enum.map(&map_ui_character/1)

    groups =
      map_characters
      |> Enum.group_by(& &1.user_id)
      |> Enum.reduce([], fn {user_id, values}, acc ->
        acc ++ [%{id: user_id, characters: values}]
      end)

    {:ok, character_settings} =
      case WandererApp.MapCharacterSettingsRepo.get_all_by_map(map_id) do
        {:ok, settings} -> {:ok, settings}
        _ -> {:ok, []}
      end

    socket
    |> assign(:character_settings, character_settings)
    |> assign(:characters_count, map_characters |> length())
    |> assign(:groups, groups)
  end

  defp map_ui_character(character),
    do:
      character
      |> Map.take([
        :id,
        :user_id,
        :eve_id,
        :name,
        :online,
        :corporation_id,
        :corporation_name,
        :corporation_ticker,
        :alliance_id,
        :alliance_name,
        :alliance_ticker
      ])
end
