namespace ToDo_proj.Models;

public class TaskToDo
{
    public int Id { get; set; }
    public required string Name { get; set; }
    public bool IsCompleted { get; set; } = false;
    public string Description { get; set; } = string.Empty;


    public Priority? Priority { get; set; }
    public int PriorityId { get; set; }

    
    public required int DayOrder { get; set; }
    public required DateOnly Date { get; set; }
    public DateOnly DateCreated { get; set; } = DateOnly.FromDateTime(DateTime.UtcNow);

    public string UserId { get; set; } = string.Empty;
}
