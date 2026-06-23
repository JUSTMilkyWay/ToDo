using ToDo_proj.Models;
using Microsoft.EntityFrameworkCore;

namespace ToDo_proj.Data;

public class ToDoContext(DbContextOptions<ToDoContext> options) : DbContext(options)
{
    public DbSet<TaskToDo> Tasks => Set<TaskToDo>();

    public DbSet<Priority> Priorities => Set<Priority>();

    public DbSet<Quote> Quotes => Set<Quote>();
}