namespace ToDo_proj.DTO;

public record InfoToDoDTO(
    int Id,
    string Name,
    bool IsCompleted,
    string? Description,
    int PriorityId,

    int DayOrder,
    DateOnly Date,
    DateOnly DateCreated
);
