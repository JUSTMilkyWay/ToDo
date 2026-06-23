namespace ToDo_proj.DTO;

public record SummaryToDoDTO(
    int Id,
    string Name,
    bool IsCompleted,
    string? Description,
    string Priority,
    string HexColor,

    int DayOrder,
    DateOnly Date,
    DateOnly DateCreated
);