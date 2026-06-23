using System.Text.Json.Serialization;

namespace ToDo_proj.DTO;

public record RawQuoteDTO(
    [property: JsonPropertyName("q")] string Text, 
    [property: JsonPropertyName("a")] string Author
);

public record QuoteDTO(
    string Text,
    string Author
);