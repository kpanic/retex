defmodule Retex.Node.BetaMemory do
  @moduledoc """
  A BetaMemory works like a two input node in Rete. It is simply a join node
  between two tests that have passed successfully. The activation of a BetaMemory
  happens if the two parents (left and right) have been activated and the bindings
  are matching for both of them.
  """
  defstruct id: nil
  @type t :: %Retex.Node.BetaMemory{}

  def new do
    %__MODULE__{id: Retex.hash(:uuid4)}
  end

  defimpl Retex.Protocol.Activation do
    alias Retex.Protocol.Activation

    def activate(neighbor, rete, wme, bindings, _tokens) do
      [left, right] = Graph.in_neighbors(rete.graph, neighbor)

      with true <- Activation.active?(left, rete),
           true <- Activation.active?(right, rete),
           left_tokens <- Map.get(rete.tokens, left.id),
           right_tokens <- Map.get(rete.tokens, right.id),
           new_tokens <- matching_tokens(neighbor, wme, right_tokens, left_tokens),
           true <- Enum.any?(new_tokens) do
        rete
        |> Retex.create_activation(neighbor, wme)
        |> Retex.add_token(neighbor, wme, bindings, new_tokens)
        |> Retex.continue_traversal(bindings, neighbor, wme)
      else
        _anything ->
          Retex.stop_traversal(rete, %{})
      end
    end

    defp matching_tokens(_, _, left, nil), do: left
    defp matching_tokens(_, _, nil, right), do: right

    defp matching_tokens(node, wme, left, right) do
      for %{bindings: left_bindings} <- left, %{bindings: right_bindings} <- right do
        if variables_match?(left_bindings, right_bindings) do
          [
            %{
              Retex.Token.new()
              | wmem: wme,
                node: node.id,
                bindings: Map.merge(left_bindings, right_bindings)
            }
          ]
        else
          []
        end
      end
      |> List.flatten()
    end

    defp variables_match?(left, right) do
      Enum.reduce_while(left, true, fn {key, value}, true ->
        if Map.get(right, key, value) == value, do: {:cont, true}, else: {:halt, false}
      end) &&
        Enum.reduce_while(right, true, fn {key, value}, true ->
          if Map.get(left, key, value) == value, do: {:cont, true}, else: {:halt, false}
        end)
    end

    @spec active?(%{id: any}, Retex.t()) :: boolean()
    def active?(%{id: id}, %Retex{activations: activations}) do
      Enum.any?(Map.get(activations, id, []))
    end
  end
end
