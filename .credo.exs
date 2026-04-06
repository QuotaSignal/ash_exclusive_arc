%{
  configs: [
    %{
      name: "default",
      files: %{
        included: ["lib/", "test/"],
        excluded: [~r"/_build/", ~r"/deps/"]
      },
      plugins: [],
      requires: [],
      strict: true,
      parse_timeout: 5000,
      color: true,
      checks: %{
        enabled: [
          {Credo.Check.Design.AliasUsage, priority: :low, if_nested_deeper_than: 2},
          {Credo.Check.Readability.MaxLineLength, priority: :low, max_length: 120}
        ]
      }
    }
  ]
}
