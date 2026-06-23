using System.ComponentModel.DataAnnotations;

namespace ToDo_proj.DTO;

public record CreateToDoDTO(
    [Required][StringLength(100)] string Name,
    string Description,
    int PriorityId,

    [Required][Range(1, 700)] int DayOrder,
    [Required] DateOnly Date,

    DateOnly DateCreated
);