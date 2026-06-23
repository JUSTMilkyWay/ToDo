using System.ComponentModel.DataAnnotations;

namespace ToDo_proj.DTO;

public record UpdateToDoDTO(
    [Required][StringLength(100)] string Name,
    bool IsCompleted,
    string? Description,
    int PriorityId,

    [Required][Range(1, 700)] int DayOrder,
    [Required] DateOnly Date
);